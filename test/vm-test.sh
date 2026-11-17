#!/usr/bin/env bash
# Automated VM test (run in the build sandbox after `sudo ./build.sh test-iso`):
#   1. installs out/test/autoinstall.iso into a fresh VM,
#   2. boots the installed system and checks the Plasma desktop, Wine and system health,
#   3. makes sure the installed system boots with Secure Boot enforced,
#   4. saves screenshots to out/test/vm/*.png. Exit code 0 means every check passed.
#
# Backend (auto-detected, override with VM_BACKEND=kvm|whpx|tcg):
#   kvm   Linux with /dev/kvm: one fast VM with Secure Boot for everything.
#         Under WSL (nested KVM on Hyper-V) SMM is unreliable, so it behaves like whpx below.
#   whpx  WSL without nested virtualization: Windows QEMU on the Windows hypervisor for the main
#         test. WHPX has no SMM, so the Secure Boot boot runs in software emulation (slow).
#   tcg   software emulation only: same checks, takes hours.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")/.."

readonly ISO=$PWD/out/test/autoinstall.iso
readonly RESULTS=$PWD/out/test/vm
readonly SSH_PORT=2222 MONITOR_PORT=4444
readonly TEST_USER=tester TEST_PASSWORD=kestrel-test   # fixture from test/autoinstall.toml
readonly WIN_QEMU="/mnt/c/Program Files/qemu/qemu-system-x86_64.exe"
readonly LINUX_FW=/usr/share/edk2/ovmf

if [[ -n ${VM_BACKEND:-} ]]; then
    BACKEND=$VM_BACKEND
elif [[ -e /dev/kvm ]]; then
    BACKEND=kvm
elif [[ -x $WIN_QEMU ]]; then
    BACKEND=whpx
else
    BACKEND=tcg
fi

# The Windows QEMU can only open files on the Windows side, so the VM files live there.
if [[ $BACKEND == whpx ]]; then
    WORK=$(wslpath "$(cmd.exe /c 'echo %LOCALAPPDATA%' 2>/dev/null | tr -d '\r')")/kestrel-vm
else
    WORK=$RESULTS
fi

failures=0
vm_pid=
vm_accel=

log() { printf '\n=== %s\n' "$*"; }

check() {
    local name=$1; shift
    if "$@"; then
        echo "PASS  $name"
    else
        echo "FAIL  $name"
        failures=$((failures + 1))
    fi
}

# Path of a VM file as the QEMU for accelerator $1 sees it.
vm_path() {
    if [[ $1 == whpx ]]; then wslpath -w "$2"; else echo "$2"; fi
}

# Starts a VM in the background.
# $1: kvm|whpx|tcg, $2: secure|plain firmware, $3: phase name (serial log), $4: ISO to boot (optional)
start_vm() {
    local accel=$1 firmware=$2 phase=$3 iso=${4:-}
    local qemu=qemu-system-x86_64 machine=q35
    local -a args
    case $accel in
        kvm)  args=(-accel kvm -cpu host) ;;
        whpx) args=(-accel whpx -cpu host); qemu=$WIN_QEMU ;;
        tcg)  args=(-accel tcg,thread=multi,tb-size=1024 -cpu max) ;;
    esac
    if [[ $firmware == secure ]]; then
        machine=q35,smm=on
        args+=(-global driver=cfi.pflash01,property=secure,value=on)
    fi
    [[ -n $iso ]] && args+=(-cdrom "$(vm_path "$accel" "$iso")" -boot once=d)
    "$qemu" \
        -machine "$machine" "${args[@]}" -smp 4 -m 6144 \
        -drive if=pflash,format=raw,unit=0,readonly=on,file="$(vm_path "$accel" "$WORK/code-$firmware.fd")" \
        -drive if=pflash,format=raw,unit=1,file="$(vm_path "$accel" "$WORK/vars-$firmware.fd")" \
        -drive if=virtio,format=qcow2,file="$(vm_path "$accel" "$WORK/disk-$firmware.qcow2")" \
        -device virtio-vga \
        -display none \
        -monitor tcp:127.0.0.1:${MONITOR_PORT},server,nowait \
        -nic user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:${SSH_PORT}-:22 \
        -serial file:"$(vm_path "$accel" "$WORK/serial-$phase.log")" &
    vm_pid=$!
    vm_accel=$accel
    trap stop_vm EXIT
}

vm_running() { kill -0 "$vm_pid" 2>/dev/null; }

monitor() {
    echo "$1" | socat - TCP:127.0.0.1:${MONITOR_PORT} >/dev/null
}

stop_vm() {
    vm_running && { monitor quit 2>/dev/null || kill "$vm_pid" 2>/dev/null || true; }
    wait "$vm_pid" 2>/dev/null || true
    trap - EXIT
}

screenshot() {
    monitor "sendkey shift"   # wake the display in case it went idle
    sleep 3
    monitor "screendump $(vm_path "$vm_accel" "$WORK/$1.png") -f png"
    sleep 2
    [[ $WORK == "$RESULTS" ]] || cp "$WORK/$1.png" "$RESULTS/"
    echo "      screenshot: out/test/vm/$1.png"
}

remote() {
    sshpass -p "$TEST_PASSWORD" ssh -q -p "$SSH_PORT" \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 \
        "$TEST_USER@127.0.0.1" "$@"
}

# Runs a command on the VM inside the user's graphical session environment.
in_session() {
    remote 'pid=$(pgrep -u "$USER" -x plasmashell) &&
        while IFS= read -r -d "" var; do
            case $var in DISPLAY=*|WAYLAND_DISPLAY=*|XAUTHORITY=*|XDG_RUNTIME_DIR=*|DBUS_SESSION_BUS_ADDRESS=*) export "$var";; esac
        done </proc/$pid/environ && '"$1"
}

wait_for() { # $1: timeout in seconds, rest: command
    local deadline=$((SECONDS + $1)); shift
    until "$@"; do
        (( SECONDS < deadline )) || return 1
        sleep 10
    done
}

[[ -f $ISO ]] || { echo "missing $ISO, run: sudo ./build.sh test-iso" >&2; exit 1; }
echo "backend: $BACKEND, VM files: $WORK"

rm -rf "$WORK" "$RESULTS" && mkdir -p "$WORK" "$RESULTS"
cp "$LINUX_FW/OVMF_CODE.secboot.fd" "$WORK/code-secure.fd"
cp "$LINUX_FW/OVMF_VARS.secboot.fd" "$WORK/vars-secure.fd"   # Microsoft keys enrolled
if [[ $BACKEND == whpx ]]; then
    cp "/mnt/c/Program Files/qemu/share/edk2-x86_64-code.fd" "$WORK/code-plain.fd"
    cp "/mnt/c/Program Files/qemu/share/edk2-i386-vars.fd" "$WORK/vars-plain.fd"
    cp "$ISO" "$WORK/autoinstall.iso"
    iso=$WORK/autoinstall.iso main_fw=plain slow=1
elif [[ $BACKEND == kvm ]] && grep -qi microsoft /proc/version; then
    cp "$LINUX_FW/OVMF_CODE.fd" "$WORK/code-plain.fd"
    cp "$LINUX_FW/OVMF_VARS.fd" "$WORK/vars-plain.fd"
    iso=$ISO main_fw=plain slow=1
else
    iso=$ISO main_fw=secure slow=$([[ $BACKEND == tcg ]] && echo 10 || echo 1)
fi
qemu-img create -q -f qcow2 "$WORK/disk-$main_fw.qcow2" 64G
x86_64-w64-mingw32-gcc -O2 -o "$WORK/winhello.exe" test/winhello.c

log "Installing (unattended, VM powers off when done)"
start_vm "$BACKEND" "$main_fw" install "$iso"
wait_for $((3600 * slow)) bash -c "! kill -0 $vm_pid 2>/dev/null" || { echo "installation timed out"; exit 1; }
stop_vm

log "Booting installed system"
start_vm "$BACKEND" "$main_fw" boot

check "VM reachable over SSH" wait_for $((600 * slow)) remote true
check "Plasma desktop session started" wait_for $((300 * slow)) remote 'pgrep -u "$USER" -x plasmashell >/dev/null'
sleep $((30 * slow))
screenshot desktop

check "Session is Wayland" remote \
    'loginctl show-session "$(loginctl list-sessions --no-legend | awk -v u="$USER" "\$3==u {print \$1; exit}")" -p Type --value | grep -qx wayland'
check "Kestrel layout applied" remote 'grep -q org.kde.plasma.kickerdash ~/.config/plasma-org.kde.plasma.desktop-appletsrc'
check "GPU setup ran" remote 'test -f /var/lib/kestrel/gpu-setup.done'
check "kestrel command works" remote 'kestrel help | grep -q rollback'
check "ntsync device available" remote 'test -c /dev/ntsync'
check "No failed system units" remote '! systemctl --failed --no-legend --plain | grep -v kestrel-flatpak-setup | grep .'
remote 'systemctl --failed --no-legend --plain' || true

sshpass -p "$TEST_PASSWORD" scp -q -P "$SSH_PORT" \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    "$WORK/winhello.exe" "$TEST_USER@127.0.0.1:winhello.exe"
check "Windows program runs via Wine" \
    in_session "WINEDEBUG=-all timeout $((600 * slow)) wine ~/winhello.exe | tee /dev/stderr | grep -q KESTREL-WINE-OK"
in_session 'WINEDEBUG=-all nohup wine ~/winhello.exe --gui >/dev/null 2>&1 &'
sleep $((20 * slow))
screenshot wine-gui

if [[ $main_fw == secure ]]; then
    check "Secure Boot enabled" remote 'mokutil --sb-state | grep -q "SecureBoot enabled"'
    stop_vm
else
    stop_vm
    log "Booting once more with Secure Boot enforced (software emulation, slow)"
    qemu-img create -q -f qcow2 -b "$WORK/disk-$main_fw.qcow2" -F qcow2 "$WORK/disk-secure.qcow2"
    start_vm tcg secure secureboot
    check "Boots with Secure Boot enforced" wait_for 7200 remote 'mokutil --sb-state | grep -q "SecureBoot enabled"'
    stop_vm
fi

log "Result ($BACKEND)"
if (( failures )); then
    echo "$failures check(s) failed"
    exit 1
fi
echo "all checks passed"
