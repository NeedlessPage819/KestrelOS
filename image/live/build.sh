# Turns the Kestrel image into the live system for the ISO (DECISIONS.md D22).
die() { echo "ERROR: $*" >&2; exit 1; }

# Live session (Fedora's livesys-scripts: live user, auto-login, Plasma Setup skipped),
# the live boot code for the initramfs, the installer, and the signed CD boot loader.
dnf5 -y install livesys-scripts dracut-live anaconda-live \
    libblockdev-btrfs libblockdev-lvm libblockdev-dm grub2-efi-x64-cdboot
cp -a /tmp/live/files/. /
sed -i 's/^livesys_session=.*/livesys_session=kde/' /etc/sysconfig/livesys
systemctl enable livesys.service livesys-late.service

# Nothing in the live session may change hardware setup or download things in the
# background: no GPU setup (it would blacklist drivers and reboot), no Flatpak downloads,
# no automatic updates.
systemctl disable kestrel-gpu-setup.service kestrel-flatpak-setup.service \
    rpm-ostreed-automatic.timer flatpak-system-update.timer

# The installer installs the Kestrel image stored on the ISO next to the live system
# (iso/live/build-iso.sh puts it in /container). dmsquash-live mounts the ISO at
# /run/initramfs/live. Accounts are created by Plasma Setup on first boot, not here.
cat >> /usr/share/anaconda/interactive-defaults.ks <<'KS'

# Kestrel OS (DECISIONS.md D22): install the image stored on the live ISO.
ostreecontainer --url=/run/initramfs/live/container --transport=oci --no-signature-verification
KS

# "Install" launcher: Kestrel name and an icon that fits the dock, first in the live dock.
inst=/usr/share/applications/liveinst.desktop
[[ -f $inst ]] || die "liveinst.desktop missing"
sed -i -e 's/^Name=.*/Name=Install Kestrel OS/' -e '/^Name\[/d' -e 's/^Icon=.*/Icon=system-software-install/' "$inst"
sed -i '/^Name=/a Name[de]=Kestrel OS installieren' "$inst"
for layout in /usr/share/plasma/look-and-feel/org.kestrel.desktop*/contents/layouts/org.kde.plasma.desktop-layout.js; do
    sed -i 's|    "applications:org.kde.dolphin.desktop",|    "applications:liveinst.desktop",\n    "applications:org.kde.dolphin.desktop",|' "$layout"
    grep -q 'applications:liveinst.desktop' "$layout" || die "could not add the installer to the dock in $layout"
done

# Initramfs with the live boot modules; it keeps the Kestrel boot screen.
kver=$(ls /usr/lib/modules)
[[ $(wc -w <<<"$kver") -eq 1 ]] || die "expected exactly one kernel, found: $kver"
DRACUT_NO_XATTR=1 dracut --no-hostonly --kver "$kver" --reproducible --zstd \
    --add "dmsquash-live dmsquash-live-autooverlay" -f "/usr/lib/modules/$kver/initramfs.img"
lsinitrd "/usr/lib/modules/$kver/initramfs.img" | grep -q dmsquash-live || die "live modules missing in initramfs"

# EFI boot files for the ISO, from the image's own signed packages (Secure Boot):
# shim as EFI/BOOT/BOOTX64.EFI loads grubx64.efi from the same folder, which on a CD
# must be the cdboot build of GRUB.
mkdir -p /boot/efi
cp -a /usr/lib/efi/*/*/EFI /boot/efi/
cp /boot/efi/EFI/fedora/gcdx64.efi /boot/efi/EFI/BOOT/grubx64.efi
[[ -f /boot/efi/EFI/BOOT/BOOTX64.EFI ]] || die "shim missing in /boot/efi/EFI/BOOT"

dnf5 clean all
rm -rf /tmp/live /var/log/dnf5.log*
