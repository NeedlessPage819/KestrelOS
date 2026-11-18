# Desktop look and feel (DECISIONS.md D4).
source /tmp/build/lib.sh

# Our look-and-feel package ships only metadata, defaults and the panel layout;
# everything else (splash, lock screen, previews) is inherited from Breeze.
breeze=/usr/share/plasma/look-and-feel/org.kde.breeze.desktop/contents
ours=/usr/share/plasma/look-and-feel/org.kestrel.desktop/contents
[[ -d $breeze ]] || die "Breeze look-and-feel package not found"
cp -rn "$breeze"/. "$ours"/
# The dark package (DECISIONS.md D20) differs only in metadata and defaults.
dark=/usr/share/plasma/look-and-feel/org.kestrel.desktop.dark/contents
cp -rn "$ours"/. "$dark"/
grep -q '^ColorScheme=BreezeDark$' "$dark/defaults" || die "dark look-and-feel lost its defaults"

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

# No KDE Welcome Center: Plasma Setup already onboards new users (DECISIONS.md D15).
# Its KDED module ignores config switches on first login, so remove the package.
dnf5 -y remove plasma-welcome

# Icon theme overrides (see /usr/share/icons/Kestrel/index.theme).
icons=/usr/share/icons
mkdir -p "$icons/Kestrel/places/scalable"
for name in user-trash user-trash-full; do
    [[ -f $icons/WhiteSur/places/scalable/$name.svg ]] || die "WhiteSur icon $name missing"
    ln -sf "../../../WhiteSur/places/scalable/$name.svg" "$icons/Kestrel/places/scalable/$name-symbolic.svg"
done
mkdir -p "$icons/Kestrel/symbolic"
for icon in "$icons"/breeze/*/22/*-symbolic.svg; do
    [[ ${icon##*/} == user-trash* ]] && continue    # the dock trash stays colourful (above)
    link=$icons/Kestrel/symbolic/${icon##*/}
    [[ -e $link ]] || ln -s "../../${icon#"$icons"/}" "$link"
done
[[ -e $icons/Kestrel/symbolic/audio-volume-high-symbolic.svg ]] || die "Breeze symbolic icons not linked"
# WhiteSur's one-colour icons carry Plasma's colour-scheme markup but the theme does not
# declare it, so Plasma never recolours them: dark icons on dark backgrounds in dark mode.
grep -q '^FollowsColorScheme=' "$icons/WhiteSur/index.theme" ||
    sed -i '/^\[Icon Theme\]$/a FollowsColorScheme=true' "$icons/WhiteSur/index.theme"
grep -q '^FollowsColorScheme=true' "$icons/WhiteSur/index.theme" || die "could not mark WhiteSur as colour-scheme aware"
gtk-update-icon-cache -qf "$icons/Kestrel" 2>/dev/null || true

# Kestrel wallpaper wherever Plasma or Plasma Setup asks for the distribution default
# (DECISIONS.md D23). Fedora's "Default" (and "Fedora") point to its own wallpaper.
wallpapers=/usr/share/wallpapers
[[ -f $wallpapers/Kestrel/contents/images/5120x2880.jxl ]] || die "Kestrel wallpaper for Plasma Setup missing"
rm -f "$wallpapers/Default"
ln -s Kestrel "$wallpapers/Default"
[[ -f $wallpapers/Default/contents/images_dark/5120x2880.jxl ]] || die "Default wallpaper link broken"

# Lock screen (DECISIONS.md D23): our files replace the look of Plasma's lock screen in the
# desktop shell package; the unlocking logic is Plasma's. Check that the package still has
# the shape our files expect, else a Plasma update could leave a broken lock screen.
lock=/usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen
for f in LockScreen.qml LockScreenUi.qml MainBlock.qml KestrelClock.qml KestrelBackground.qml \
         KestrelMedia.qml KestrelActionButton.qml NoPasswordUnlock.qml LockOsd.qml PasswordSync.qml qmldir \
         config.qml config.xml; do
    [[ -f $lock/$f ]] || die "lock screen file $f missing"
done
grep -q 'LockScreenUi {' "$lock/LockScreen.qml" || die "Plasma's LockScreen.qml no longer loads LockScreenUi"
grep -q 'Kestrel OS lock screen' "$lock/LockScreenUi.qml" || die "Kestrel lock screen not installed"
grep -q '"X-Plasma-APIVersion": "2"' /usr/share/plasma/shells/org.kde.plasma.desktop/metadata.json ||
    die "desktop shell package has a new lock screen API version; check the Kestrel lock screen"
