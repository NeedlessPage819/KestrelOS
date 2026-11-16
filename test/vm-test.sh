#!/usr/bin/env bash
# Automated VM test (run in the build sandbox after `sudo ./build.sh test-iso`):
#   1. installs out/test/autoinstall.iso into a fresh QEMU/KVM VM with Secure Boot on,
#   2. boots the installed system and checks Secure Boot, the Plasma desktop and Wine,
#   3. saves screenshots to out/test/vm/*.png. Exit code 0 means every check passed.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")/.."

readonly ISO=out/test/autoinstall.iso
readonly WORK=$PWD/out/test/vm
readonly SSH_PORT=2222
readonly TEST_USER=tester TEST_PASSWORD=kestrel-test   # fixture from test/autoinstall.toml
OVMF_CODE=${OVMF_CODE:-$(ls /usr/share/edk2/ovmf/OVMF_CODE*.secboot.fd | head -n1)}
OVMF_VARS=${OVMF_VARS:-$(ls /usr/share/edk2/ovmf/OVMF_VARS*.secboot.fd | head -n1)}

failures=0

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

# $1: phase name (used for the serial log), rest: extra QEMU arguments
run_vm() {
    local phase=$1; shift
    qemu-system-x86_64 \
        -machine q35,smm=on -accel kvm -cpu host -smp 4 -m 6144 \
        -global driver=cfi.pflash01,property=secure,value=on \
        -drive if=pflash,format=raw,unit=0,readonly=on,file="$OVMF_CODE" \
        -drive if=pflash,format=raw,unit=1,file="$WORK/OVMF_VARS.fd" \
        -drive if=virtio,format=qcow2,file="$WORK/disk.qcow2" \
        -device virtio-vga \
        -display none -vnc 127.0.0.1:1 \
        -monitor unix:"$WORK/monitor.sock",server,nowait \
        -nic user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:${SSH_PORT}-:22 \
        -serial file:"$WORK/serial-$phase.log" \
        "$@"
}

screenshot() {
    echo "screendump $WORK/$1.png -f png" | socat - UNIX-CONNECT:"$WORK/monitor.sock" >/dev/null
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
            case $var in DISPLAY=*|WAYLAND_DISPLAY=*|XDG_RUNTIME_DIR=*|DBUS_SESSION_BUS_ADDRESS=*) export "$var";; esac
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
[[ -e /dev/kvm ]] || { echo "/dev/kvm missing: nested virtualization is not available" >&2; exit 1; }

rm -rf "$WORK" && mkdir -p "$WORK"
cp "$OVMF_VARS" "$WORK/OVMF_VARS.fd"
qemu-img create -q -f qcow2 "$WORK/disk.qcow2" 64G
x86_64-w64-mingw32-gcc -O2 -o "$WORK/winhello.exe" test/winhello.c

log "Installing (unattended, VM powers off when done)"
timeout 60m run_vm install -cdrom "$ISO" -boot once=d

log "Booting installed system"
run_vm boot &
vm_pid=$!
trap 'kill $vm_pid 2>/dev/null || true' EXIT

check "VM reachable over SSH" wait_for 600 remote true
check "Plasma desktop session started" wait_for 300 remote 'pgrep -u "$USER" -x plasmashell >/dev/null'
sleep 20
screenshot desktop

check "Secure Boot enabled" remote 'mokutil --sb-state | grep -q "SecureBoot enabled"'
check "Session is Wayland" remote \
    'loginctl show-session "$(loginctl list-sessions --no-legend | awk -v u="$USER" "\$3==u {print \$1; exit}")" -p Type --value | grep -qx wayland'
check "Kestrel look-and-feel active" remote 'test -f /usr/share/plasma/look-and-feel/org.kestrel.desktop/contents/layouts/org.kde.plasma.desktop-layout.js'
check "GPU setup ran" remote 'test -f /var/lib/kestrel/gpu-setup.done'
check "No failed system units" remote '! systemctl --failed --no-legend | grep -v kestrel-flatpak-setup | grep .'
remote 'systemctl --failed --no-legend' || true

sshpass -p "$TEST_PASSWORD" scp -q -P "$SSH_PORT" \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    "$WORK/winhello.exe" "$TEST_USER@127.0.0.1:winhello.exe"
check "Windows program runs via Wine" \
    in_session 'WINEDEBUG=-all timeout 300 wine ~/winhello.exe | tee /dev/stderr | grep -q KESTREL-WINE-OK'
in_session 'WINEDEBUG=-all nohup wine ~/winhello.exe --gui >/dev/null 2>&1 &'
sleep 15
screenshot wine-gui

log "Result"
if (( failures )); then
    echo "$failures check(s) failed"
    exit 1
fi
echo "all checks passed"
