# Boot screen (DECISIONS.md D21): Kestrel Plymouth theme, built into the initramfs.
source /tmp/build/lib.sh

theme=/usr/share/plymouth/themes/kestrel
[[ -f $theme/watermark.png && -f $theme/throbber-0001.png ]] || die "boot screen images missing"
# The password prompt for encrypted disks reuses Fedora's spinner theme graphics.
for image in bullet entry lock capslock keyboard keymap-render; do
    cp -n /usr/share/plymouth/themes/spinner/$image.png "$theme/"
done
plymouth-set-default-theme kestrel

# The boot screen lives in the initramfs, so rebuild it for the image's kernel.
kver=$(ls /usr/lib/modules)
[[ $(wc -w <<<"$kver") -eq 1 ]] || die "expected exactly one kernel, found: $kver"
# /root links to /var/roothome, which only exists on an installed system; dracut follows it.
mkdir -p /var/roothome
dracut --no-hostonly --kver "$kver" --reproducible --zstd --add ostree -f "/usr/lib/modules/$kver/initramfs.img"
rmdir /var/roothome
lsinitrd "/usr/lib/modules/$kver/initramfs.img" | grep -q 'plymouth/themes/kestrel/watermark.png' ||
    die "Kestrel boot screen not in the initramfs"
