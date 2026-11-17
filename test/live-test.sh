#!/usr/bin/env bash
# Live ISO test (DECISIONS.md D22). Run in the build sandbox after `sudo ./build.sh iso`:
#   test/live-test.sh [ISO]          default: newest out/kestrel-*.iso
# Boots the ISO in a VM and saves screenshots to out/test/live/:
#   menu.png       the boot menu (Kestrel theme)
#   splash.png     the boot screen
#   desktop.png    the live desktop, logged in automatically
#   installer.png  the installer, started from the dock
#   secure-menu.png, secure-boot.png   the same ISO with Secure Boot enforced (software
#                  emulation, slow), proving the signed boot chain still works
# The live session has no SSH, so this test only looks; judging the pictures is up to you.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")/.."

ISO=${1:-$(ls -t out/kestrel-*.iso 2>/dev/null | grep -v installer | head -1)}
[[ -f $ISO ]] || { echo "no live ISO found, build one with: sudo ./build.sh iso"; exit 1; }
OUT=out/test/live
FW=/usr/share/edk2/ovmf
MONITOR_PORT=4444 QMP_PORT=4445
SCREEN_W=1280 SCREEN_H=800
mkdir -p "$OUT"

monitor() { echo "$1" | timeout 10 socat - TCP:127.0.0.1:${MONITOR_PORT},connect-timeout=3 >/dev/null; }
shot() { monitor "screendump $OUT/$1.png -f png"; sleep 1; echo "  screenshot: $OUT/$1.png"; }
qmp_input() {
    printf '{"execute":"qmp_capabilities"}\n{"execute":"input-send-event","arguments":{"events":[%s]}}\n' "$1" |
        timeout 10 socat - TCP:127.0.0.1:${QMP_PORT},connect-timeout=3 >/dev/null
}
click() {
    local x=$(( $1 * 32767 / SCREEN_W )) y=$(( $2 * 32767 / SCREEN_H ))
    qmp_input "{\"type\":\"abs\",\"data\":{\"axis\":\"x\",\"value\":$x}},{\"type\":\"abs\",\"data\":{\"axis\":\"y\",\"value\":$y}}"
    sleep 0.3
    qmp_input '{"type":"btn","data":{"down":true,"button":"left"}}'; sleep 0.1
    qmp_input '{"type":"btn","data":{"down":false,"button":"left"}}'
}

# $1: accel args, $2: firmware variant (plain|secure)
start_vm() {
    local accel=$1 fw=$2 machine=q35 extra=()
    if [[ $fw == secure ]]; then
        cp "$FW/OVMF_VARS.secboot.fd" "$OUT/vars.fd"; code=$FW/OVMF_CODE.secboot.fd
        machine=q35,smm=on; extra=(-global driver=cfi.pflash01,property=secure,value=on)
    else
        cp "$FW/OVMF_VARS.fd" "$OUT/vars.fd"; code=$FW/OVMF_CODE.fd
    fi
    # shellcheck disable=SC2086
    qemu-system-x86_64 -machine "$machine" $accel "${extra[@]}" -smp 4 -m 4096 \
        -drive if=pflash,format=raw,unit=0,readonly=on,file="$code" \
        -drive if=pflash,format=raw,unit=1,file="$OUT/vars.fd" \
        -cdrom "$ISO" -boot d \
        -device virtio-vga -display none -device qemu-xhci -device usb-tablet \
        -monitor tcp:127.0.0.1:${MONITOR_PORT},server,nowait \
        -qmp tcp:127.0.0.1:${QMP_PORT},server,nowait \
        -nic user,model=virtio-net-pci \
        -serial file:"$OUT/serial-$fw.log" </dev/null >/dev/null 2>&1 &
    vm_pid=$!
    trap 'kill $vm_pid 2>/dev/null || true' EXIT
}
stop_vm() { monitor quit || kill "$vm_pid" 2>/dev/null || true; wait "$vm_pid" 2>/dev/null || true; trap - EXIT; }

if pgrep -f qemu-system-x86_64 >/dev/null; then echo "a VM is already running; stop it first"; exit 1; fi
echo "=== Live ISO: $ISO"

echo "=== Booting (KVM)"
start_vm "-accel kvm -cpu host" plain
sleep 7;  shot menu
sleep 12; shot splash
# Live boot unpacks the system into memory; give the desktop time without 3D acceleration.
for _ in $(seq 24); do sleep 10; shot desktop >/dev/null; done; shot desktop
# The installer is the second icon in the dock (after Launchpad). The dock is centred and
# holds 9 icons of 48 px with 6 px gaps plus a 7 px separator before the trash
# (image/artwork/plasma_theme.py): row 487 px wide, installer centre at 640 - 243 + 54 + 24.
click 475 765
sleep 60; shot installer
stop_vm

echo "=== Booting with Secure Boot enforced (software emulation, slow)"
start_vm "-accel tcg,thread=multi -cpu max" secure
sleep 60;  shot secure-menu
sleep 240; shot secure-boot
stop_vm
echo "=== done; look at the screenshots in $OUT"
