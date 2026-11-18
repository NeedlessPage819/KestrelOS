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
         KestrelMedia.qml KestrelActionButton.qml KestrelAvatar.qml KestrelBattery.qml NoPasswordUnlock.qml LockOsd.qml PasswordSync.qml qmldir \
         config.qml config.xml; do
    [[ -f $lock/$f ]] || die "lock screen file $f missing"
done
grep -q 'LockScreenUi {' "$lock/LockScreen.qml" || die "Plasma's LockScreen.qml no longer loads LockScreenUi"
grep -q 'Kestrel OS lock screen' "$lock/LockScreenUi.qml" || die "Kestrel lock screen not installed"
grep -q '"X-Plasma-APIVersion": "2"' /usr/share/plasma/shells/org.kde.plasma.desktop/metadata.json ||
    die "desktop shell package has a new lock screen API version; check the Kestrel lock screen"

# Plasma Setup branding (DECISIONS.md D24). Its welcome text ("Welcome to Plasma Desktop") is
# compiled into the program, but the text shown comes from the translation catalogues, so
# the product name is replaced there (German and every other language that has it). The
# icon next to it is "plasma-symbolic", which the Kestrel icon theme points at the Kestrel mark.
python3 - "$OS_NAME" <<'PY' || die "could not rebrand Plasma Setup's translations"
import glob, struct, sys
name = sys.argv[1].encode()
changed = 0
for path in glob.glob("/usr/share/locale/*/LC_MESSAGES/org.kde.plasmasetup.mo"):
    data = open(path, "rb").read()
    magic, _, n, orig_off, trans_off = struct.unpack("<5I", data[:20])
    assert magic == 0x950412de, path
    entries = []
    for i in range(n):
        ol, oo = struct.unpack("<2I", data[orig_off + 8 * i:orig_off + 8 * i + 8])
        tl, to = struct.unpack("<2I", data[trans_off + 8 * i:trans_off + 8 * i + 8])
        orig, trans = data[oo:oo + ol], data[to:to + tl]
        if b"Plasma Desktop" in orig:
            trans = trans.replace(b"Plasma Desktop", name).replace(b"Plasma-Desktop", name)
            changed += 1
        entries.append((orig, trans))
    # Rewrite without a hash table (gettext then searches the sorted list; keys are unchanged).
    head = 28
    otab, ttab = head, head + 8 * n
    pos = ttab + 8 * n
    blob, otable, ttable = b"", b"", b""
    for orig, _ in entries:
        otable += struct.pack("<2I", len(orig), pos + len(blob)); blob += orig + b"\0"
    for _, trans in entries:
        ttable += struct.pack("<2I", len(trans), pos + len(blob)); blob += trans + b"\0"
    open(path, "wb").write(struct.pack("<7I", 0x950412de, 0, n, otab, ttab, 0, 0) + otable + ttable + blob)
assert changed > 0, "no 'Plasma Desktop' text found in Plasma Setup's translations"
print(f"Plasma Setup: product name replaced in {changed} translations")
PY
ln -sf ../../hicolor/scalable/apps/kestrel-logo-symbolic.svg "$icons/Kestrel/symbolic/plasma-symbolic.svg"
[[ -e $icons/Kestrel/symbolic/plasma-symbolic.svg ]] || die "plasma-symbolic link broken"
grep -q '"konqi-calling.png"' /usr/share/plasma/packages/org.kde.plasmasetup.finished/contents/ui/main.qml ||
    die "Plasma Setup's last page no longer uses konqi-calling.png; update the Kestrel picture"

# Dark colours for the login screen (DECISIONS.md D24, see tmpfiles.d/kestrel-plasmalogin.conf).
# The colours themselves must be in kdeglobals; the scheme name alone is not enough.
scheme=/usr/share/color-schemes/BreezeDark.colors
[[ -f $scheme ]] || die "BreezeDark colour scheme missing"
mkdir -p /usr/share/kestrel/plasmalogin
{
    sed -e '/^\[General\]/,/^\[/{/^\[General\]/!{/^\[/!d}}' "$scheme"
    printf '\n[General]\nColorScheme=BreezeDark\n\n[KDE]\nLookAndFeelPackage=org.kestrel.desktop.dark\n'
} > /usr/share/kestrel/plasmalogin/kdeglobals
grep -q '^\[Colors:Window\]' /usr/share/kestrel/plasmalogin/kdeglobals || die "login screen colours not written"
