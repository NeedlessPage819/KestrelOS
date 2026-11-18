#!/usr/bin/env bash
# Install from the live ISO by hand in a VM (DECISIONS.md D22), step by step with screenshots.
#   test/live-vm.sh start [ISO]   boot the live ISO with an empty 64 GB disk (plain UEFI, KVM)
#   test/live-vm.sh shot NAME     screenshot to out/test/live-install/NAME.png
#   test/live-vm.sh click X Y     left click at screen position X, Y
#   test/live-vm.sh key KEYS      press keys (QEMU names, e.g. ret, tab, ctrl-a)
#   test/live-vm.sh stop
# The ISO is attached for the first boot only, so after the installer's reboot the VM starts
# the installed system from the disk.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")/.."

OUT=out/test/live-install
FW=/usr/share/edk2/ovmf
MONITOR_PORT=4444 QMP_PORT=4445
SCREEN_W=1280 SCREEN_H=800
mkdir -p "$OUT"

monitor() { echo "$1" | timeout 10 socat - TCP:127.0.0.1:${MONITOR_PORT},connect-timeout=3 >/dev/null; }
qmp_input() {
    printf '{"execute":"qmp_capabilities"}\n{"execute":"input-send-event","arguments":{"events":[%s]}}\n' "$1" |
        timeout 10 socat - TCP:127.0.0.1:${QMP_PORT},connect-timeout=3 >/dev/null
}

case ${1:-} in
start)
    iso=${2:-$(ls -t out/kestrel-*.iso | grep -v installer | head -1)}
    pgrep -f qemu-system-x86_64 >/dev/null && { echo "a VM is already running"; exit 1; }
    cp "$FW/OVMF_VARS.fd" "$OUT/vars.fd"
    qemu-img create -q -f qcow2 "$OUT/disk.qcow2" 64G
    # 2 cores: with 4, the live desktop (drawn by the CPU) starved WSL until it stopped answering.
    setsid qemu-system-x86_64 -machine q35 -accel kvm -cpu host -smp 2 -m 4096 \
        -drive if=pflash,format=raw,unit=0,readonly=on,file="$FW/OVMF_CODE.fd" \
        -drive if=pflash,format=raw,unit=1,file="$OUT/vars.fd" \
        -drive if=virtio,format=qcow2,file="$OUT/disk.qcow2" \
        -cdrom "$iso" -boot once=d \
        -device virtio-vga -display none -device qemu-xhci -device usb-tablet \
        -monitor tcp:127.0.0.1:${MONITOR_PORT},server,nowait \
        -qmp tcp:127.0.0.1:${QMP_PORT},server,nowait \
        -nic user,model=virtio-net-pci \
        -serial file:"$OUT/serial.log" </dev/null >/dev/null 2>&1 &
    echo "started with $iso" ;;
shot)
    monitor "screendump $OUT/${2:?name}.png -f png"; sleep 1; echo "$OUT/$2.png" ;;
click)
    x=$(( ${2:?x} * 32767 / SCREEN_W )) y=$(( ${3:?y} * 32767 / SCREEN_H ))
    qmp_input "{\"type\":\"abs\",\"data\":{\"axis\":\"x\",\"value\":$x}},{\"type\":\"abs\",\"data\":{\"axis\":\"y\",\"value\":$y}}"
    sleep 0.3
    qmp_input '{"type":"btn","data":{"down":true,"button":"left"}}'; sleep 0.1
    qmp_input '{"type":"btn","data":{"down":false,"button":"left"}}' ;;
key)
    shift; for k in "$@"; do monitor "sendkey $k"; sleep 0.2; done ;;
stop)
    monitor quit || true ;;
*)
    sed -n '2,10p' "$0"; exit 1 ;;
esac
