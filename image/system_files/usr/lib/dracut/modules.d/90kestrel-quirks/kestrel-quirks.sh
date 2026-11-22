#!/usr/bin/sh
# Kestrel OS per-model fixes (DECISIONS.md D31). Runs in the initramfs before any driver is
# loaded (dracut pre-udev hook), so a fix is in place before the driver it protects starts.

product=$(cat /sys/class/dmi/id/product_name 2>/dev/null)

case "$product" in
    "Aspire AL15-45P")
        # Acer Aspire Lite 15, Ryzen 7 5825U. Without this every Linux stays on a black screen:
        # every charger event makes the AMD driver take its power-management lock and then ask
        # the firmware whether the charger is in (_PSR). On this model _PSR also sets processor
        # power limits through AMD's ALIB, which stalls, and each answer triggers the next
        # charger event. The lock is never released; the display server waits on it forever.
        # Without the charger driver nobody asks _PSR; charging state still shows, it comes
        # from the battery. The driver is built into the kernel and already attached here, so
        # detach it before the AMD driver loads.
        for dev in /sys/bus/*/drivers/ac/ACPI0003:*; do
            [ -e "$dev" ] || continue
            echo "${dev##*/}" >"${dev%/*}/unbind" &&
                echo "kestrel-quirks: $product: charger driver detached from ${dev##*/}" >/dev/kmsg
        done
        ;;
esac
