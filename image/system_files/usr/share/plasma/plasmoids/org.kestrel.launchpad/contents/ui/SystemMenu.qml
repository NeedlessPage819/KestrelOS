// The Kestrel menu behind the bird in the top bar, like the Apple menu (DECISIONS.md D32):
// about, settings, app store, sleep, restart, shut down, lock, log out. Restart, Shut Down
// and Log Out show Plasma's own confirmation screen, like the "…" items on the Mac.
import QtQuick
import org.kde.plasma.extras as PlasmaExtras
import org.kde.coreaddons as KCoreAddons

PlasmaExtras.Menu {
    id: menu
    placement: PlasmaExtras.Menu.BottomPosedLeftAlignedPopup

    readonly property string prompt: "dbus-send --session --type=method_call --dest=org.kde.LogoutPrompt /LogoutPrompt org.kde.LogoutPrompt."
    readonly property QtObject user: KCoreAddons.KUser {}      // for "Log Out <name>…"

    PlasmaExtras.MenuItem {
        text: root.tr("Über Kestrel OS", "About Kestrel OS")
        icon: "kestrel-logo-symbolic"
        onClicked: shell.run("kinfocenter")
    }
    PlasmaExtras.MenuItem { separator: true }
    PlasmaExtras.MenuItem {
        text: root.tr("Systemeinstellungen …", "System Settings…")
        icon: "preferences-system"
        onClicked: shell.run("systemsettings")
    }
    PlasmaExtras.MenuItem {
        text: root.tr("App Store …", "App Store…")
        icon: "plasmadiscover"
        onClicked: shell.run("plasma-discover")
    }
    PlasmaExtras.MenuItem { separator: true }
    PlasmaExtras.MenuItem {
        text: root.tr("Ruhezustand", "Sleep")
        icon: "system-suspend"
        onClicked: shell.run("systemctl suspend")
    }
    PlasmaExtras.MenuItem {
        text: root.tr("Neu starten …", "Restart…")
        icon: "system-reboot"
        onClicked: shell.run(menu.prompt + "promptReboot")
    }
    PlasmaExtras.MenuItem {
        text: root.tr("Ausschalten …", "Shut Down…")
        icon: "system-shutdown"
        onClicked: shell.run(menu.prompt + "promptShutDown")
    }
    PlasmaExtras.MenuItem { separator: true }
    PlasmaExtras.MenuItem {
        text: root.tr("Bildschirm sperren", "Lock Screen")
        icon: "system-lock-screen"
        onClicked: shell.run("dbus-send --session --type=method_call --dest=org.freedesktop.ScreenSaver /ScreenSaver org.freedesktop.ScreenSaver.Lock")
    }
    PlasmaExtras.MenuItem {
        text: root.tr("%1 abmelden …", "Log Out %1…").arg(menu.user.fullName || menu.user.loginName)
        icon: "system-log-out"
        onClicked: shell.run(menu.prompt + "promptLogout")
    }
}
