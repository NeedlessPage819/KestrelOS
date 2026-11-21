#!/usr/bin/env bash
# Checks the live stick's log partition (DECISIONS.md D30). Run in the build sandbox after
# `sudo ./build.sh iso`:   test/live-usb-log.sh [ISO]
# Boots the ISO as a USB stick (a copy-on-write layer, the ISO stays untouched), waits until the
# live session has written its logs, shuts the VM down and lists what is on KESTRELLOG.
set -euo pipefail
cd "$(dirname "$0")/.."

ISO=${1:-$(ls -t out/kestrel-*.iso 2>/dev/null | grep -v installer | head -1)}
[[ -f $ISO ]] || { echo "no live ISO found"; exit 1; }
OUT=out/test/live-usb
FW=/usr/share/edk2/ovmf
MONITOR_PORT=4446
mkdir -p "$OUT"
if pgrep -f qemu-system-x86_64 >/dev/null; then echo "a VM is already running; stop it first"; exit 1; fi

rm -f "$OUT/stick.qcow2" "$OUT/stick.raw"
qemu-img create -q -f qcow2 -b "$(realpath "$ISO")" -F raw "$OUT/stick.qcow2"
cp "$FW/OVMF_VARS.fd" "$OUT/vars.fd"
qemu-system-x86_64 -machine q35 -enable-kvm -cpu host -smp 4 -m 4096 \
    -drive if=pflash,format=raw,unit=0,readonly=on,file="$FW/OVMF_CODE.fd" \
    -drive if=pflash,format=raw,unit=1,file="$OUT/vars.fd" \
    -device qemu-xhci -drive if=none,id=stick,format=qcow2,file="$OUT/stick.qcow2" \
    -device usb-storage,drive=stick,bootindex=0 \
    -device virtio-vga -display none -device usb-tablet \
    -monitor tcp:127.0.0.1:${MONITOR_PORT},server,nowait \
    -serial file:"$OUT/serial.log" </dev/null >/dev/null 2>&1 &
vm_pid=$!
trap 'kill $vm_pid 2>/dev/null || true' EXIT
echo "booting the ISO as a USB stick; waiting 4 minutes for the live session to write its logs"
sleep 240
echo "system_powerdown" | timeout 10 socat - TCP:127.0.0.1:${MONITOR_PORT} >/dev/null || true
for (( i = 0; i < 90; i++ )); do kill -0 $vm_pid 2>/dev/null || break; sleep 1; done
kill $vm_pid 2>/dev/null || true
wait $vm_pid 2>/dev/null || true
trap - EXIT

qemu-img convert -O raw "$OUT/stick.qcow2" "$OUT/stick.raw"
# Third GPT partition = KESTRELLOG (iso/live/build-iso.sh).
start=$(sfdisk -d "$OUT/stick.raw" | awk -F'[=,]' '/start=/{n++; if (n == 3) {gsub(/ /, "", $2); print $2}}')
[[ -n $start ]] || { echo "FAIL: no third partition on the stick"; exit 1; }
img="$OUT/stick.raw@@$((start * 512))"
echo "KESTRELLOG contents:"
mdir -/ -i "$img" ::
folder=$(mdir -b -i "$img" :: | grep -v README | head -1)
[[ -n $folder ]] || { echo "FAIL: no log folder written"; exit 1; }
for f in journal errors kernel units session graphics hardware; do
    mtype -i "$img" "$folder/$f.txt" >/dev/null 2>&1 || { echo "FAIL: $f.txt missing"; exit 1; }
done
mtype -i "$img" "$folder/units.txt" | head -20
mcopy -o -i "$img" -s "$folder" "$OUT/"
rm -f "$OUT/stick.raw"
echo "PASS: live logs written to the stick"
