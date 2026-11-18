# Decisions

Every important decision is listed here: **what**, **why**, and **what we accept in return**.
New entries go at the end.

---

## D1 – Working name "Kestrel OS"

**What:** For now the system is called *Kestrel OS* (a kestrel is a small, fast falcon).
**Why:** We need a name for files and menus. It is set in only one place
(`config.env`) and can be changed at any time.

---

## D2 – Base: Fedora Kinoite (Atomic Desktop) via Universal Blue

**What:** We build on **Fedora Kinoite**. This is the official Fedora with KDE Plasma,
as an "atomic" system. As a starting point we use the `kinoite-main` image from
**Universal Blue**. It is the same Fedora, but it already has multimedia codecs and
ready-signed Nvidia drivers. Bazzite and Aurora are built on it too.

**Why, in simple terms:**

| Requirement | Why Fedora Atomic fits |
|---|---|
| Updates must not break anything | An update is prepared fully in the background and only becomes active at the next restart. If something goes wrong, you just pick the previous version in the boot menu (**rollback built in**, no extra tool). |
| Secure Boot / anti-cheat | Fedora starts with a boot loader signed by Microsoft. So Secure Boot can stay **on**. The kernel and the boot process stay standard. |
| Current drivers | Fedora ships new kernels and Mesa versions (AMD/Intel graphics) within a few weeks. Debian/Ubuntu LTS are often a year behind here. |
| Reproducible build | The whole system is built like a container from one file (`image/Containerfile`). The same inputs give the same system. |
| Widely used and maintained | Fedora is maintained by Red Hat and a large community. Gaming distros like Bazzite prove that exactly this stack works for games. |

**Rejected alternatives:**
- *Arch Linux + archiso:* Newest packages, but Secure Boot does not work directly, and you would
  have to build rollback yourself (Btrfs + Snapper). With a rolling release the risk is higher
  that an update disrupts daily use.
- *Ubuntu/Debian + live-build:* Stable, but graphics drivers and Mesa are often too old for gaming.
  There is no built-in rollback here either.
- *openSUSE Tumbleweed:* Has snapshots and Secure Boot, but is less common for gaming software and
  Nvidia packages.

**What we accept in return:** In daily use you install programs as **Flatpak**
(through "Discover"), not with `dnf`. For normal users this is actually easier.

---

## D3 – Fedora version: 44 (not the brand-new 45)

**What:** The default is Fedora 44 (setting `FEDORA_VERSION` in `config.env`).
**Why:** Fedora 45 has only just come out. Under our rule "daily use comes first"
we take the version that has proven itself for months. Fedora 44 still gets updates until about
mid-2027. As soon as 45 has run for a few weeks without big bugs, we switch. To do that you
only change one number.

---

## D4 – Desktop: KDE Plasma 6 in macOS style

**What:** KDE Plasma 6 (Wayland) with its own layout:
- **Top bar:** start menu button on the left, app menu (global menu), icons and clock on the right.
- **Dock:** floating and centered at the bottom. It gets out of the way of windows and holds the
  Launchpad button, favorite apps and the trash.
- **Blur** (frosted glass effect) and smooth animations. Windows minimize with the
  "Magic Lamp" effect (like the Genie effect).
- **Window buttons on the left** (close, minimize, maximize), like on a Mac.
- **Font:** *Inter* (very easy to read, similar to SF Pro) and *JetBrains Mono* for code.
- **Spotlight:** KRunner opens with **Meta+Space** (Meta = the Windows key, same as
  Cmd on a Mac). KRunner finds apps and files, does math and converts units.
- **Gestures:** Plasma has touchpad gestures built in (swipe with 4 fingers: overview and
  switching workspaces). Tap to click is on.

**Why KDE and not GNOME:** GNOME needs *extensions* for a dock and blur. These often break with
GNOME updates, and that goes against "updates must not break anything".
In Plasma, dock, blur, global menu and Spotlight are **built in**.

**Deliberately not done:** We do not copy Apple graphics, logos or icons.
We take the *feel*, not the trademark.

---

## D5 – Graphics drivers: automatic, based on hardware

**What:**
- **AMD and Intel:** The drivers are in the kernel and in Mesa and work right away. There is
  nothing to set up. This is also true for your Acer (AMD Radeon).
- **Nvidia (GTX 16xx / RTX 20xx and newer):** The official Nvidia driver ("nvidia-open") is
  included in the system, but *switched off* at first. On the first start the service
  `kestrel-gpu-setup` checks whether a matching Nvidia card is present. Only then does it switch
  the driver on and restart once.
- **Older Nvidia cards (GTX 10xx and older):** They keep the free "nouveau" driver.
  The new Nvidia driver no longer supports them.

**Why:** One single ISO for all computers, without anyone having to choose anything. On computers
without Nvidia the Nvidia driver stays fully off and cannot cause problems.

**Secure Boot with Nvidia:** The Nvidia driver is signed with the Universal Blue key.
If Secure Boot is on, you have to confirm this key once. After the restart a
blue screen ("MOK") appears, password: `universalblue`. This only affects Nvidia computers.

---

## D6 – Gaming software

**Built into the system (RPM):** Steam, Wine, Winetricks, Lutris, GameMode, MangoHud, Gamescope.
**On the first start with internet (Flatpak):** Heroic (Epic/GOG, for example for Rocket League),
Bottles, ProtonUp-Qt.

**Why this split:** Steam and Wine belong in the system because they are closely tied to drivers
and 32-bit libraries. This way Wine also works without internet (we need that
for the test). Heroic, Bottles and ProtonUp-Qt are published as Flatpak by their makers.
That is where they are most up to date.

**Performance settings that do not disturb daily use:**
- `ntsync`: A kernel module that lets Wine and Proton sync Windows programs faster.
  It is only used while a game is running.
- `split_lock_mitigate = 0`: Stops some games from being slowed down artificially.
- **GameMode** switches the CPU to full power only *while a game runs*. After that it
  goes back to power-saving mode, which is good for the battery.

**Deliberately NOT done:** No custom gaming kernel, no changed boot parameters, no
disabled security features. This costs a few percent FPS at most. In return,
Secure Boot, anti-cheat compatibility and battery life stay untouched (see D7).

---

## D7 – Anti-cheat and Secure Boot

**What:** Standard Fedora kernel (signed), standard boot loader (shim + GRUB), no
kernel patches, no special boot parameters for gaming.
**Why:** Rocket League (Easy Anti-Cheat) already runs under Proton. If Epic one day
allows Fortnite on Linux, it will very likely require an unchanged system that supports
Secure Boot. We will already have that.

---

## D8 – Everyday programs as Flatpak

LibreOffice and VLC come from Flathub on the first start with internet.
Firefox, the file manager (Dolphin), printing (CUPS), Wi-Fi, Bluetooth and power management are
built into the system. Flathub is the only app source, so Discover does not show apps twice.
**Why:** Flatpaks get updates directly from their makers. They run separately from the system, so
they cannot damage the base system.

---

## D9 – Installer ISO instead of a live system (for now)

**What:** The ISO is an **installer** (Anaconda, the program Fedora also uses).
There is no "try without installing" for now.
**Why:** For atomic systems this is the official, stable way (the tool
`bootc-image-builder` from Fedora/Red Hat). We will look at a live ISO later as an improvement.

---

## D10 – Build and test only in the sandbox

**What:** Building and testing happen only in a **WSL2 Fedora environment** on your
Windows PC. Inside it runs a **QEMU/KVM VM** with Secure Boot. Your Windows stays untouched.
**Why:** WSL2 is made by Microsoft, cleanly separated, and can be removed again with one command.
Fedora in WSL has exactly the tools the target system also uses (podman, bootc).

---

## D11 – One simple command for updates: `kestrel`

**What:** In the terminal there is the command `kestrel`:
- `kestrel update`: downloads the new system and updates all apps. The new system takes effect
  from the next restart. The old one is kept as an emergency version.
- `kestrel rollback`: use the previous version again at the next start.
- `kestrel status`: shows which versions are installed.

Updates also work with a mouse click in **Discover** (the KDE app store).

**Why:** The real tools (`bootc`, `flatpak`) are confusing for beginners.
One command with German messages is easier.

**Open:** For installed computers to *find* updates, the finished system image has to be on the
internet (for example for free on GitHub). That is publishing something to the outside, so I will
ask first. Until then you update by reinstalling with a new ISO.

---

## D12 – Our own design instead of third-party themes

**What:**
- **Wallpaper:** our own vector graphic (color gradient with soft waves), light and dark.
  Plasma automatically picks the variant that matches the light or dark color scheme. The same
  picture appears on the lock screen.
- **Accent color:** a calm blue-violet (`#5B6CF0`) that matches the background.
- **Base:** KDE's standard design "Breeze", only adjusted.

**Why:** Ready-made "macOS themes" from the internet often copy Apple graphics (legally risky)
and tend to break with Plasma updates. Breeze is maintained by KDE itself and stays stable
through updates. We only adjust colors, font and layout.

---

## D13 – Setup on first start with the "Plasma Setup" assistant

**What:** The installer now only asks which disk to install to.
On the first start a KDE assistant then greets you. There you choose language, keyboard
and Wi-Fi and create your user account.
**Why:** This feels like the setup assistant on a Mac: install first, then
set things up in peace. Fedora KDE 44 does it the same way. So we use the official,
maintained way.

---

## D14 – Small fixes so system services run without errors

- `systemd-remount-fs` no longer starts on atomic systems. There it tries to remount the
  read-only system area, and that always fails. This error only affects a message,
  not a function.
- `mcelog` (reports CPU hardware errors) now only runs on real hardware. In VMs there is
  nothing to report, and there the service only stops with an error.
- The computer name is `kestrel` by default instead of `fedora`.

**Why:** A clean system shows no red error messages. The automatic test checks
that no system service fails.

---

## D15 – A tidier macOS feel (design round 2)

At first look the desktop still felt like "KDE with a dock". Changed:

- **Window buttons as colored "traffic lights"** (red, yellow, green; symbols appear on hover),
  a slim light title bar, rounded top corners, a soft shadow. This is **our own
  window design** ("Aurorae" theme, created by `image/artwork/aurorae.py`).
  *Why our own:* Ready-made solutions like "Klassy" are compiled programs that must match the exact
  Plasma version. There are no packages for Fedora 44, and a Plasma update could
  break the window frames. Aurorae designs are only graphics that KWin draws itself.
  Updates cannot damage them.
- **Dock:** bigger icons and only apps that are always installed (Files, Firefox, Steam,
  Discover, Terminal, Settings). No more empty placeholders. The Launchpad button shows an
  app grid.
- **Top bar:** slimmer, with our own simple logo (a bird gliding) and the date in the style
  „Di. 17. Nov.“ (Tue 17 Nov)
- **No KDE welcome window** on the first login. The assistant (D13) already handles the setup.
  Turning it off with a setting was not enough in the test, so the package
  `plasma-welcome` is removed completely. Nothing else depends on it.

## D16 – Design round 3: dock and top bar like glass

Next to macOS the dock still looked busy. Changed:

- **Our own Plasma design "Kestrel"** (created by `image/artwork/plasma_theme.py`). It only replaces
  the background of the dock and top bar and the marker for running apps. Everything else still
  comes from Breeze, so it stays stable through Plasma updates.
- **Dock:** see-through like frosted glass, strongly rounded corners, the icons fill the dock.
  On real hardware the background behind it is blurred. The test VM lacks the
  3D acceleration for that, so there it is only see-through.
- **Running apps** get a small line under the icon instead of a blue box.
- **Top bar:** flat and also see-through.
- The colors come from the color scheme, so in dark mode everything turns dark automatically.
- **Window shadow fixed:** Light gaps in the shadow were visible at the window corners.

## D17 – Icons in macOS style (WhiteSur)

The Breeze icons looked mixed up in the dock: flat folders, round logos, dark squares.
On a Mac all app icons have the same rounded square shape. So Kestrel uses the
free icon set **WhiteSur** (license GPL-3.0). Decided with you.

- It is not included in Fedora and is fetched from GitHub during the build.
- **Security:** The version is pinned to `2026-09-10`, and the build checks the
  exact state (commit `73d8040`). If anything differs, the build stops. The install
  script only runs in a separate build container, not in the finished system.
- **Updates:** A new version only comes when we deliberately enter it in `config.env`.
- The alternative would have been Papirus from Fedora: reviewed and consistent, but flat and not
  macOS-like.
- **Trash and Launchpad in the dock:** Plasma deliberately shows widgets in panels as plain
  outline icons. In the big dock the trash did not match the colorful app icons that way. A
  small icon set of our own, "Kestrel", takes everything from WhiteSur and only swaps the trash
  for the colored glass version. The Launchpad button uses the colored app grid.
- **Icons at the top right (volume, network and so on):** WhiteSur draws these small
  one-color icons in a fixed light gray that Plasma cannot recolor. On the light top bar
  they were hard to see. For these, Kestrel uses the very similar one-color icons from Breeze.
  They follow the color scheme: dark on light, light in dark mode. The colorful
  app icons stay WhiteSur.

## D18 – Animations and gestures

- **Windows** zoom in and out smoothly when they open and close, like on a Mac. **Minimize**
  pulls the window into the dock with the "Magic Lamp" effect. **Maximize** is animated.
- **Touchpad:** Plasma uses **four** fingers: up for the window overview, sideways to
  switch workspaces. The Mac uses three. Plasma has no setting for this, and
  rebuilding KWin for it would be exactly the kind of change that breaks with updates. So four.
- The test VM has no 3D acceleration, so all effects are off there. Whether everything
  feels smooth is therefore on the test list for the laptop.

## D19 – Our own dock with magnification ("Kestrel Dock")

On a Mac the icons in the dock get bigger when the mouse moves over them. Plasma's own dock
cannot do that. So Kestrel has its own dock widget. Decided with you.

- **How it is built:** pure QML (Plasma's interface language), no compiled code. It only uses
  Plasma's official building blocks for the list of apps. Compiled add-ons like Latte Dock
  break with Plasma updates because they must match the exact version. QML does not have
  this problem.
- **Why updates do not break it:** Plasma updates only come through the Kestrel image. Every
  image goes through the automatic VM test, and that test checks that the dock loads without errors.
  If an update breaks the dock, the test fails before the update reaches your laptop.
- **The dock holds everything:** Launchpad, pinned and running apps, divider, trash.
  So everything grows together, like on a Mac.
- **Room for the magnification:** The dock is invisibly taller and wider than the visible
  frosted glass. The icons and the app name grow into this empty margin. Clicks there go
  normally to the window or desktop behind it.
- **Frosted glass:** The dock draws its glass itself so it can grow with the icons.
  At rest it sits exactly where Plasma blurs the background. Only the edges that
  briefly appear during magnification are see-through, but not blurred.
- **Side effect:** The dock gets out of the way of windows. Because Plasma counts the invisible
  margin too, it already moves away when a window reaches to about 100 pixels above the bottom edge of the screen.
- **Launchpad:** The bird icon at the top left and the Launchpad icon in the dock both open the
  full-screen app grid.
- **Small extras:** app name above the magnified icon, bouncing when an app starts, a dot under
  running apps, a right-click menu (New Window, Keep in Dock, Quit), dragging files onto the
  trash.
- **Not in yet:** window preview on hover and reordering icons by dragging.
- All sizes (icon size, magnification, margins) are in one place in
  `image/artwork/plasma_theme.py` and apply to the design, widget and layout together.

## D20 – Dark mode

The automatic test now also switches to dark mode and takes a screenshot. This
revealed three bugs, which are now fixed:

- **Window frames stayed light.** Our own window design cannot switch its colors
  by itself. So there is a dark variant ("KestrelDark"): dark title bar, light
  text, a thin light border, like macOS in dark mode.
- **Icons were dark on dark** (in apps and at the top right). Plasma only recolors one-color icons
  if the icon set explicitly allows it. WhiteSur and our Kestrel set did not have
  this setting. Now they do.
- **Switching in one step:** There are two global designs, **"Kestrel"** (light) and
  **„Kestrel Dunkel“** (Kestrel Dark). They are in the system settings under „Globales Design“
  (Global Theme) and in the quick settings. One click switches colors, window frames and wallpaper
  together. The setting „Automatisch“ (Automatic: light during the day, dark in the evening) also uses these two.
- If you only pick a dark color scheme under „Farben“ (Colors), you get dark apps and icons, but
  light window frames. That is what the global design is for.

## D21 – Our own boot screen

When you turn it on, Kestrel shows a black screen with the white Kestrel bird in the middle and a
thin progress bar below it instead of the Fedora logo, like the Apple logo when a
Mac starts.

- Built with Plymouth, Fedora's boot screen program, and its "two-step" module, which is
  already in the system. No new package is added.
- The password prompt for encrypted disks still uses Fedora's graphics.
- Kernel messages during boot are hidden (`rhgb quiet`). If you want to see them, press Esc
  during boot.
- The boot menu (GRUB) stays hidden, as in Fedora. It only appears after a
  failed start or if you hold Shift while turning the computer on. The Mac does not
  have one either.
- Secure Boot stays untouched: only pictures and settings change, no signed
  boot programs.

## D22 – Live USB stick: try first, then install

The ISO now starts a complete Kestrel OS directly from the USB stick, without changing anything on the
disk. If you want to keep it, click **„Kestrel OS installieren“** (Install Kestrel OS) in the dock.
Decided with you.

- **Boot menu of the USB stick** in the Kestrel design: dark background, white bird and name,
  German entries („Kestrel OS starten“, „… (einfache Grafik)“ for difficult graphics cards,
  „USB-Stick prüfen …“, „Firmware-Einstellungen“). It starts by itself after 10 seconds.
  All text in the menu is drawn as a picture: with Secure Boot the boot program does not load
  font files for security reasons, and its built-in font does not know umlauts.
  This way the menu looks the same with and without Secure Boot.
- **Live system:** logs in automatically as "liveuser". Graphics card setup,
  Flatpak downloads and automatic updates are off in the live system, so nothing happens in the
  background. Changes in the live system are gone after a restart.
- **Installer:** Fedora's installer (Anaconda) with Kestrel colors and logo. It only asks for
  disk, language and keyboard. As before, the setup assistant creates the user account
  on the first start (D13). It installs the Kestrel image that is on the stick, so it
  does not need internet.
- **How it is built:** A separate live image based on the Kestrel image gets the parts
  for the live start and the installer. These parts do not end up in the installed system. The
  build recipe for the ISO comes from Titanoboa by Universal Blue (free license Apache-2.0),
  copied and adjusted, instead of running the outside tool.
- **Secure Boot:** The ISO uses the signed boot programs from the system itself. The test
  also starts it with Secure Boot enforced.
- **Limits:** The live ISO only starts in UEFI mode (all current laptops; in
  VirtualBox and VMware "EFI" must be switched on). For old BIOS computers there is still the
  plain installer ISO (`build.sh installer-iso`). The USB stick needs at least 16 GB.

## D23 – Lock screen, login screen and setup in Mac style

The lock screen now looks like on a Mac: the date and a big clock at the top, and at the bottom the
round user picture, the name and a rounded password field with an arrow button. A wrong
password makes the field shake briefly. While nobody is typing, it only shows „Zum Entsperren eine
Taste drücken“ (Press a key to unlock); when you type, the wallpaper is blurred.

- **Settings:** Systemeinstellungen → Bildschirmsperre → „Erscheinungsbild einrichten …“ (System Settings → Screen Locking → Configure Appearance).
  - Clock: big, small or off. Font weight from thin to bold. 12 or 24 hours, seconds.
  - Date: on or off, long („Mittwoch, 18. November“), short or as numbers.
  - Background: wallpaper, blurred picture or a color. Blur strength
    and darkening can be set.
  - Widgets: music and video controls („Wiedergabe“, Playback), battery, keyboard layout, a custom
    message (for example „Gefunden? Bitte melden unter …“, "Found this? Please report to …"). Optionally only after a key press.
  - User: picture (normal or big), name, buttons for sleep and switching users.
- **How it is built:** Only the look is new. The unlock logic (password, fingerprint,
  sleep) stays Plasma's. If a file is broken, Plasma shows its own
  simple fallback lock screen, so you can always get back in. The image build checks that
  Plasma updates have not changed anything basic, otherwise the build stops.
- **Login screen** and **setup assistant** now show the Kestrel wallpaper
  instead of the Fedora picture.
- **Dark mode in the setup assistant:** Fedora changed the switch so that it turns on
  Fedora's own design. Then the new user would have gotten neither the Kestrel dock nor the
  Kestrel design. Now the matching Kestrel design (light or dark) is set automatically at the
  first login. A later choice of your own stays untouched.
- **Installer:** The note „Senden Sie uns Feedback“ (Send us feedback) with a QR code to Fedora's forum is gone, because
  Kestrel OS is not Fedora.

## D24 – Kestrel from login to desktop

The last KDE and Fedora traces between logging in and the desktop are gone.

- **Start screen after login:** instead of KDE's black "Plasma 30th Anniversary Edition"
  screen, Kestrel shows the softly blurred wallpaper (light or dark, matching the colour
  scheme), the white Kestrel mark and a thin progress bar, then fades into the desktop. The
  login screen shows the same wallpaper, so nothing jumps.
- **Setup wizard:** the welcome page says "Willkommen bei Kestrel OS" (Welcome to Kestrel OS)
  instead of "Plasma Desktop", with the Kestrel mark instead of the Plasma logo. The last page
  shows a Kestrel app-icon tile instead of KDE's dragon mascots. The welcome text is built into
  the program, so the name is changed in its translation files. English keeps KDE's original
  wording, because English is the program's own language and has no translation file.
- **Login screen:** now uses dark colours: white text on a softly darkened wallpaper, like the
  Mac. With light colours Plasma brightened the wallpaper to a washed-out pastel. The layout
  itself is built into Plasma's login program and stays as it is. A choice made later in System
  Settings > Login Screen is kept.
- **Checks:** the image build stops if Plasma Setup's last page or translations change shape,
  so an update can't silently bring the old look back.

## D25 – Live USB stick on Nvidia graphics

**Problem:** On a PC with a GTX 1660 Ti the live session stayed black with only a mouse
cursor. In the live session the official Nvidia driver is off (it is only switched on when
installing, D5), so the card got the free "nouveau" driver, which often can't run Plasma on
GTX 16xx and newer cards.

**What:** The live stick no longer uses nouveau at all.
- On GTX 16xx / RTX 20xx and newer, the official driver (nvidia-open) is loaded before the
  desktop starts. With Secure Boot on, this can't work in the live session, because the
  driver's signing key is only enrolled during installation (D5). Then the next point applies.
- Otherwise the picture comes straight from the firmware ("simpledrm"). It is slower (the
  processor draws everything), but it works on every card.
- Intel and AMD graphics are not affected.
- The installed system is unchanged: it picks the driver itself at the first start (D5).

**What we accept:** On older Nvidia cards, and on new ones with Secure Boot on, the live
session is slower than the installed system will be. That's fine for trying it out.
