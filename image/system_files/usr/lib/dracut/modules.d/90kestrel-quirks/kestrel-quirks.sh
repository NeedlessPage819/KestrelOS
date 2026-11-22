#!/usr/bin/sh
# Kestrel OS per-model driver settings (DECISIONS.md D31). Runs in the initramfs before any
# driver is loaded; settings go to /run/modprobe.d, which modprobe reads both in the initramfs
# and in the booted system, so they apply from the very first driver load.

product=$(cat /sys/class/dmi/id/product_name 2>/dev/null)
quirks=/run/modprobe.d/kestrel-quirks.conf

case "$product" in
    "Aspire AL15-45P")
        # Acer Aspire Lite 15, Ryzen 7 5825U ("Barcelo", display DCN 2.1). With default
        # settings every Linux stays on a black screen here: the AMD driver waits 30-60 s while
        # setting up the backlight, its display firmware (DMCUB) then fails, and firmware calls
        # of the USB-C, tablet-mode and airplane-key drivers hang. Logs: Kestrel live stick.
        mkdir -p /run/modprobe.d
        cat >"$quirks" <<'EOF'
# Written by kestrel-quirks (initramfs) for the Acer Aspire Lite 15 AL15-45P.
# amdgpu: no firmware brightness curve (0x40000), no panel self refresh (0x10), no adaptive
# backlight dimming; all three go through the display firmware that fails on this model.
options amdgpu dcdebugmask=0x40010 abmlevel=0
# Firmware drivers whose calls hang on this model.
blacklist ucsi_acpi
blacklist soc_button_array
blacklist wireless_hotkey
EOF
        # The main fix. Every charger event makes the AMD driver take its power-management lock
        # and then ask the firmware whether the charger is in (_PSR). On this model _PSR also
        # sets new processor power limits (AMD's ALIB), which stalls, and each answer triggers
        # the next charger event. The lock is never released and the display server waits on
        # it forever: black screen. Without the charger driver nobody asks _PSR; charging state
        # still shows, it comes from the battery. The driver is built into the kernel and is
        # already attached at this point, so detach it before the AMD driver loads.
        for dev in /sys/bus/*/drivers/ac/ACPI0003:*; do
            [ -e "$dev" ] || continue
            echo "${dev##*/}" >"${dev%/*}/unbind" &&
                echo "kestrel-quirks: charger driver detached from ${dev##*/}" >/dev/kmsg
        done
        # Diagnostics while this model is being fixed, live stick only (it records them on its
        # KESTRELLOG partition): full display-driver messages.
        grep -qw rd.live.image /proc/cmdline && echo "options drm debug=0x106" >>"$quirks"
        echo "kestrel-quirks: settings for $product applied" >/dev/kmsg
        ;;
esac
