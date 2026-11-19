// Initial Plasma layout for new users: macOS-style top bar and floating dock (DECISIONS.md D4).

var topBar = new Panel;
topBar.location = "top";
topBar.height = Math.round(gridUnit * 1.5);
topBar.floating = false;

// The bird opens the full-screen app grid (Launchpad). The dock's Launchpad icon opens the
// same grid: it asks Plasma for "the launcher", which is this widget (DECISIONS.md D19).
var launcher = topBar.addWidget("org.kde.plasma.kickerdash");
launcher.currentConfigGroup = ["General"];
launcher.writeConfig("icon", "kestrel-logo-symbolic");

topBar.addWidget("org.kde.plasma.appmenu");
topBar.addWidget("org.kde.plasma.panelspacer");
topBar.addWidget("org.kde.plasma.systemtray");

// Date and time like the macOS menu bar clock, in the menus' font size (DECISIONS.md D27).
topBar.addWidget("org.kestrel.clock");

// The Kestrel Dock widget holds Launchpad, apps and trash. The panel is taller than the
// visible glass: icons magnify into the empty band above it. The height is filled in at
// build time from image/artwork/plasma_theme.py, which also draws that band.
var dock = new Panel;
dock.location = "bottom";
dock.height = @DOCK_HEIGHT@;
dock.alignment = "center";
dock.lengthMode = "fit";
dock.floating = true;
// Like the Mac: always visible, only full-screen apps cover it. System Settings > Dock (D27).
dock.hiding = "none";

var apps = dock.addWidget("org.kestrel.dock");
// Only apps that are part of the image: Flatpaks arrive later and would show as blank icons.
apps.currentConfigGroup = ["General"];
apps.writeConfig("launchers", [
    "applications:org.kde.dolphin.desktop",
    "applications:org.mozilla.firefox.desktop",
    "applications:steam.desktop",
    "applications:org.kde.discover.desktop",
    "applications:org.kde.konsole.desktop",
    "applications:systemsettings.desktop"
]);

var desktops = desktopsForActivity(currentActivity());
for (var i = 0; i < desktops.length; i++) {
    desktops[i].wallpaperPlugin = "org.kde.image";
    desktops[i].currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    desktops[i].writeConfig("Image", "file:///usr/share/wallpapers/Kestrel/");
}
