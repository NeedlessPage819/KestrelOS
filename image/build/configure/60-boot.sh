# Boot screen (DECISIONS.md D21): Kestrel Plymouth theme, built into the initramfs.
source /tmp/build/lib.sh

theme=/usr/share/plymouth/themes/kestrel
[[ -f $theme/watermark.png && -f $theme/progress-0049.png ]] || die "boot screen images missing"
# The password prompt for encrypted disks reuses Fedora's spinner theme graphics.
for image in bullet entry lock capslock keyboard keymap-render; do
    cp -n /usr/share/plymouth/themes/spinner/$image.png "$theme/"
done
plymouth-set-default-theme kestrel

# The boot screen lives in the initramfs, so rebuild it for the image's kernel.
# A module folder without a kernel (vmlinuz) is a leftover: the Universal Blue base image of
# 2026-11-27 had a 7.3.5 folder holding only module index files next to its 7.3.4 kernel.
# Remove such folders, so a second real kernel still stops the build below.
for dir in /usr/lib/modules/*/; do
    [[ -f $dir/vmlinuz ]] || { echo "removing leftover module folder without a kernel: $dir"; rm -rf "$dir"; }
done
kver=$(ls /usr/lib/modules)
[[ $(wc -w <<<"$kver") -eq 1 ]] || die "expected exactly one kernel, found: $kver"
# /root links to /var/roothome, which only exists on an installed system; dracut follows it.
mkdir -p /var/roothome
dracut --no-hostonly --kver "$kver" --reproducible --zstd --add "ostree kestrel-quirks" -f "/usr/lib/modules/$kver/initramfs.img"
# Per-model driver settings (DECISIONS.md D31) must run before the first driver loads.
grep -q 'pre-udev/10-kestrel-quirks.sh' < <(lsinitrd "/usr/lib/modules/$kver/initramfs.img") || die "kestrel-quirks missing in initramfs"
rmdir /var/roothome
lsinitrd "/usr/lib/modules/$kver/initramfs.img" | grep 'plymouth/themes/kestrel/watermark.png' >/dev/null ||
    die "Kestrel boot screen not in the initramfs"
