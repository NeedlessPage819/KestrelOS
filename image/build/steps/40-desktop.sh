# Desktop look and feel (DECISIONS.md D4).
source /tmp/build/lib.sh

# Our look-and-feel package ships only metadata, defaults and the panel layout;
# everything else (splash, lock screen, previews) is inherited from Breeze.
breeze=/usr/share/plasma/look-and-feel/org.kde.breeze.desktop/contents
ours=/usr/share/plasma/look-and-feel/org.kestrel.desktop/contents
[[ -d $breeze ]] || die "Breeze look-and-feel package not found"
cp -rn "$breeze"/. "$ours"/

# Spotlight: open KRunner with Meta+Space in addition to the Plasma defaults.
# Only the first entry is KRunner itself; later ones belong to its actions.
krunner=/usr/share/kglobalaccel/org.kde.krunner.desktop
grep -q '^X-KDE-Shortcuts=' "$krunner" || die "KRunner shortcut entry not found"
sed -i '0,/^X-KDE-Shortcuts=/{/^X-KDE-Shortcuts=/{/Meta+Space/!s/=/=Meta+Space,/}}' "$krunner"
grep -m1 '^X-KDE-Shortcuts=' "$krunner" | grep -q 'Meta+Space' || die "could not add Meta+Space to KRunner"

# Branding. ID stays "fedora" so that tools checking for Fedora keep working.
sed -i \
    -e "s/^NAME=.*/NAME=\"${OS_NAME}\"/" \
    -e "s/^PRETTY_NAME=.*/PRETTY_NAME=\"${OS_NAME} $(rpm -E %fedora)\"/" \
    -e "s/^VARIANT_ID=.*/VARIANT_ID=${IMAGE_NAME}/" \
    /usr/lib/os-release
