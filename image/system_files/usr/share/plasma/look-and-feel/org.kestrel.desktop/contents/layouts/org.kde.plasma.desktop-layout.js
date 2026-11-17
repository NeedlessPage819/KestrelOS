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

var clock = topBar.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", true);
clock.writeConfig("dateDisplayFormat", "BesideTime");
clock.writeConfig("dateFormat", "custom");
clock.writeConfig("customDateFormat", "ddd d. MMM");
// Same size and weight as the rest of the top bar, like the macOS menu bar clock. By
// default Plasma scales the clock to the bar's height, which made it larger than the menus.
clock.writeConfig("autoFontAndSize", false);
clock.writeConfig("fontFamily", "Inter");
clock.writeConfig("fontSize", 10);
clock.writeConfig("fontWeight", 400);

// The Kestrel Dock widget holds Launchpad, apps and trash. The panel is taller than the
// visible glass: icons magnify into the empty band above it. The height is filled in at
// build time from image/artwork/plasma_theme.py, which also draws that band.
var dock = new Panel;
dock.location = "bottom";
dock.height = @DOCK_HEIGHT@;
dock.alignment = "center";
dock.lengthMode = "fit";
dock.floating = true;
dock.hiding = "dodgewindows";

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
