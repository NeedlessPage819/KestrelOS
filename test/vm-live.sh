#!/usr/bin/env bash
# Fast design loop on the VM installed by test/vm-test.sh (WSL/Linux with KVM only).
#   test/vm-live.sh start        boot the installed test disk in the background
#   test/vm-live.sh theme        install the current window decoration for the test user
#   test/vm-live.sh plasma       install the current Plasma theme (dock, top bar) for the test user
#   test/vm-live.sh run CMD...   run a command inside the desktop session
#   test/vm-live.sh shot NAME    screenshot to out/test/vm/NAME.png
#   test/vm-live.sh stop
# Changes made here are only for looking; the image is still the source of truth.
set -euo pipefail
cd "$(dirname "$0")/.."

WORK=out/test/vm
SSH_PORT=2222 MONITOR_PORT=4444
TEST_USER=tester TEST_PASSWORD=kestrel-test   # fixture from test/autoinstall.toml

remote() {
    sshpass -p "$TEST_PASSWORD" ssh -q -p "$SSH_PORT" -o ConnectTimeout=5 \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$TEST_USER@127.0.0.1" "$@"
}
in_session() {
    remote 'pid=$(pgrep -u "$USER" -x plasmashell) &&
        while IFS= read -r -d "" var; do
            case $var in WAYLAND_DISPLAY=*|XDG_RUNTIME_DIR=*|DBUS_SESSION_BUS_ADDRESS=*) export "$var";; esac
        done </proc/$pid/environ && '"$1"
}
monitor() { echo "$1" | socat - TCP:127.0.0.1:${MONITOR_PORT} >/dev/null; }

case ${1:-} in
start)
    pgrep -f qemu-system-x86_64 >/dev/null && { echo "a VM is already running"; exit 1; }
    setsid qemu-system-x86_64 -machine q35 -accel kvm -cpu host -smp 4 -m 4096 \
        -drive if=pflash,format=raw,unit=0,readonly=on,file="$WORK/code-plain.fd" \
        -drive if=pflash,format=raw,unit=1,file="$WORK/vars-plain.fd" \
        -drive if=virtio,format=qcow2,file="$WORK/disk-plain.qcow2" \
        -device virtio-vga -display none \
        -monitor tcp:127.0.0.1:${MONITOR_PORT},server,nowait \
        -nic user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:${SSH_PORT}-:22 \
        -serial file:"$WORK/serial-live.log" </dev/null >/dev/null 2>&1 &
    for _ in $(seq 60); do
        remote 'pgrep -u "$USER" -x plasmashell' >/dev/null 2>&1 && { sleep 15; echo "desktop is up"; exit 0; }
        sleep 5
    done
    echo "desktop did not come up"; exit 1 ;;
theme)
    # KWin caches decorations by name, so every push gets a fresh name.
    tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
    python3 image/artwork/aurorae.py "$tmp"
    name=KestrelDev$(date +%s)
    mv "$tmp/Kestrel" "$tmp/$name" && mv "$tmp/$name/Kestrelrc" "$tmp/$name/${name}rc"
    sed -i "s/=Kestrel\$/=$name/" "$tmp/$name/metadata.desktop"
    tar -C "$tmp" -c "$name" | remote 'rm -rf ~/.local/share/aurorae/themes/KestrelDev*; mkdir -p ~/.local/share/aurorae/themes;
        tar -C ~/.local/share/aurorae/themes -x'
    in_session "kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme __aurorae__svg__$name &&
        dbus-send --session --type=signal /KWin org.kde.KWin.reloadConfig" ;;
plasma)
    # Plasma also caches themes by name: install under a fresh name each time.
    tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
    python3 image/artwork/plasma_theme.py "$tmp"
    name=kestreldev$(date +%s)
    mv "$tmp/kestrel" "$tmp/$name" && sed -i "s/\"Id\": \"kestrel\"/\"Id\": \"$name\"/" "$tmp/$name/metadata.json"
    tar -C "$tmp" -c "$name" | remote 'rm -rf ~/.local/share/plasma/desktoptheme/kestreldev*;
        mkdir -p ~/.local/share/plasma/desktoptheme; tar -C ~/.local/share/plasma/desktoptheme -x'
    in_session "plasma-apply-desktoptheme $name" ;;
run)
    shift; in_session "$*" ;;
shot)
    monitor "sendkey shift"; sleep 2
    monitor "screendump $WORK/${2:?name}.png -f png"; sleep 2
    echo "$WORK/$2.png" ;;
stop)
    monitor quit || true ;;
*)
    sed -n '2,8p' "$0"; exit 1 ;;
esac
