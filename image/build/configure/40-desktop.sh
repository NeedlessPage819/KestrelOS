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

# Icon themes (DECISIONS.md D28): "Kestrel" (default, Kestrel's own drawings) and "WhiteSur"
# (Kestrel-WhiteSur). Both get the same overrides; see their index.theme files.
icons=/usr/share/icons
[[ -f $icons/Kestrel/places/kestrel/folder.svg ]] || die "Kestrel icon drawings missing"
for theme in Kestrel Kestrel-WhiteSur; do
    mkdir -p "$icons/$theme/places/scalable" "$icons/$theme/symbolic"
    for name in user-trash user-trash-full; do
        # The dock asks for the "-symbolic" trash; it should be the theme's full-colour trash.
        if [[ $theme == Kestrel ]]; then
            target="../kestrel/$name.svg"
        else
            [[ -f $icons/WhiteSur/places/scalable/$name.svg ]] || die "WhiteSur icon $name missing"
            target="../../../WhiteSur/places/scalable/$name.svg"
        fi
        ln -sf "$target" "$icons/$theme/places/scalable/$name-symbolic.svg"
        [[ -e $icons/$theme/places/scalable/$name-symbolic.svg ]] || die "$theme: $name link broken"
    done
    for icon in "$icons"/breeze/*/22/*-symbolic.svg; do
        [[ ${icon##*/} == user-trash* ]] && continue    # the dock trash stays colourful (above)
        link=$icons/$theme/symbolic/${icon##*/}
        [[ -e $link ]] || ln -s "../../${icon#"$icons"/}" "$link"
    done
    [[ -e $icons/$theme/symbolic/audio-volume-high-symbolic.svg ]] || die "$theme: Breeze symbolic icons not linked"
done
# The plain WhiteSur themes stay installed (both themes above build on them) but are hidden in
# the icon settings: choosing them directly would lose the fixes above.
for theme in "$icons"/WhiteSur "$icons"/WhiteSur-*; do
    [[ -f $theme/index.theme ]] || continue
    grep -q '^Hidden=' "$theme/index.theme" || sed -i '/^\[Icon Theme\]$/a Hidden=true' "$theme/index.theme"
done
# WhiteSur's one-colour icons carry Plasma's colour-scheme markup but the theme does not
# declare it, so Plasma never recolours them: dark icons on dark backgrounds in dark mode.
grep -q '^FollowsColorScheme=' "$icons/WhiteSur/index.theme" ||
    sed -i '/^\[Icon Theme\]$/a FollowsColorScheme=true' "$icons/WhiteSur/index.theme"
grep -q '^FollowsColorScheme=true' "$icons/WhiteSur/index.theme" || die "could not mark WhiteSur as colour-scheme aware"
# Small sizes (sidebars, menus: 16 and 22 px) of the icons Kestrel draws come from WhiteSur's
# simple line versions, as in macOS. Plasma takes any size a theme has before looking at the
# themes it inherits from, so these sizes must be in the Kestrel theme itself: link WhiteSur's
# files and copy its matching directory entries into Kestrel's index.theme.
python3 - "$icons" <<'PY' || die "could not add WhiteSur's small icons to the Kestrel theme"
import configparser, os, re, sys
icons = sys.argv[1]
ours, ws_dir = f"{icons}/Kestrel", f"{icons}/WhiteSur"
ws = configparser.ConfigParser(interpolation=None, strict=False)
ws.optionxform = str
ws.read(f"{ws_dir}/index.theme")
drawn = {ctx: [f[:-4] for f in os.listdir(f"{ours}/{ctx}/kestrel") if f.endswith(".svg")]
         for ctx in ("apps", "places", "mimetypes")}
head = ws["Icon Theme"]
added, sections, links = [], "", 0
for d in (head.get("Directories", "") + "," + head.get("ScaledDirectories", "")).split(","):
    d = d.strip()
    parts = ["mimetypes" if p == "mimes" else p for p in re.split(r"[/@]", d)]   # WhiteSur says "mimes"
    ctx = next((c for c in drawn if c in parts), None)
    if not d or d not in ws or ctx is None or int(ws[d].get("Size", "0")) > 22 or d in added:
        continue
    names = [n for n in drawn[ctx] if os.path.exists(f"{ws_dir}/{d}/{n}.svg")]
    if not names:
        continue
    os.makedirs(f"{ours}/{d}", exist_ok=True)
    for n in names:
        link = f"{ours}/{d}/{n}.svg"
        if os.path.lexists(link):
            os.remove(link)
        os.symlink(os.path.relpath(f"{ws_dir}/{d}/{n}.svg", os.path.dirname(link)), link)
        links += 1
    added.append(d)
    sections += f"\n[{d}]\n" + "".join(f"{k}={v}\n" for k, v in ws[d].items())
assert links > 0, "WhiteSur has no small versions of the Kestrel icons"
path = f"{ours}/index.theme"
text = open(path).read()
text, n = re.subn(r"^(Directories=.*)$", lambda m: m.group(1) + "," + ",".join(added), text, count=1, flags=re.M)
assert n == 1, "Kestrel index.theme has no Directories line"
open(path, "w").write(text + sections)
print(f"Kestrel icons: {links} small WhiteSur versions linked in {len(added)} directories")
PY
[[ -e $icons/Kestrel/places/16/folder-pictures.svg ]] || die "Kestrel theme: small folder icons missing"
for theme in Kestrel Kestrel-WhiteSur; do gtk-update-icon-cache -qf "$icons/$theme" 2>/dev/null || true; done

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
for theme in Kestrel Kestrel-WhiteSur; do
    ln -sf ../../hicolor/scalable/apps/kestrel-logo-symbolic.svg "$icons/$theme/symbolic/plasma-symbolic.svg"
    [[ -e $icons/$theme/symbolic/plasma-symbolic.svg ]] || die "$theme: plasma-symbolic link broken"
done
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

# Kestrel window decoration (DECISIONS.md D26): compiled in its own build stage; it must match
# the KDecoration library that ships, or KWin would refuse it and fall back to Breeze.
deco=/usr/lib64/qt6/plugins/org.kde.kdecoration3/org.kestrel.decoration.so
[[ -f $deco ]] || die "Kestrel window decoration missing"
built=$(cat /usr/share/kestrel/decoration-built-against)
shipped=$(rpm -q --qf '%{VERSION}-%{RELEASE}' kdecoration)
[[ $built == "$shipped" ]] || die "window decoration built against kdecoration $built, image has $shipped"
[[ -f /usr/lib64/qt6/plugins/plasma/kcms/systemsettings/kcm_kestreldock.so ]] || die "System Settings > Dock missing"
[[ -x /usr/libexec/kestrel/auto-scale ]] || die "auto-scale helper missing or not executable"
# Konsole's toolbars are hidden by our copies of its menu files (D27); check they still match
# the version Konsole ships, else ours would be ignored (harmless) or outdated.
for rc in konsoleui sessionui; do
    grep -q "hidden=\"true\"" /usr/share/kxmlgui5/konsole/$rc.rc || die "Konsole $rc.rc override broken"
done
