// Kestrel Dock (DECISIONS.md D19): a macOS-style dock with magnification.
//
// Pure QML on Plasma's public task model (org.kde.taskmanager), no compiled code, so it
// does not break with Plasma updates the way compiled add-ons do. Plasma updates reach
// users only through the Kestrel image, and the image test checks that this widget loads.
//
// Geometry comes from geometry.js, generated together with the panel theme: icons rest at
// G.icon px and grow into an empty band above and beside the visible glass.
import QtQuick
import QtQuick.Layouts
import QtCore
import Qt.labs.folderlistmodel
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support
import org.kde.taskmanager as TaskManager
import "geometry.js" as G

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation

    readonly property bool german: Qt.locale().name.startsWith("de")
    function tr(de, en) { return german ? de : en }

    // Runs a shell command (launchpad, trash). Commands are fixed strings plus quoted URLs.
    P5Support.DataSource {
        id: shell
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => disconnectSource(source)
        function run(cmd) { connectSource(cmd) }
    }
    function quote(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

    TaskManager.VirtualDesktopInfo { id: virtualDesktopInfo }
    TaskManager.ActivityInfo { id: activityInfo }

    TaskManager.TasksModel {
        id: tasksModel
        groupMode: TaskManager.TasksModel.GroupApplications
        groupInline: false
        sortMode: TaskManager.TasksModel.SortManual
        separateLaunchers: false
        launchInPlace: true
        hideActivatedLaunchers: true
        filterByVirtualDesktop: false
        filterByScreen: false
        filterByActivity: true
        activity: activityInfo.currentActivity
        virtualDesktop: virtualDesktopInfo.currentDesktop
        launcherList: Plasmoid.configuration.launchers
        onLauncherListChanged: {
            if (JSON.stringify(launcherList) !== JSON.stringify(Plasmoid.configuration.launchers)) {
                Plasmoid.configuration.launchers = launcherList
            }
        }
    }

    // Trash state without private Plasma modules: watch the trash folder directly.
    FolderListModel {
        id: trashFolder
        folder: StandardPaths.writableLocation(StandardPaths.GenericDataLocation) + "/Trash/files"
        showDirs: true
        showHidden: true
    }

    fullRepresentation: Item {
        id: dock

        // Items: launchpad, the tasks, a separator, the trash.
        readonly property int taskCount: tasksModel.count
        readonly property int itemCount: taskCount + 2
        readonly property real sepWidth: 1 + G.spacing
        readonly property real restRowWidth: itemCount * G.icon + (itemCount - 1) * G.spacing + sepWidth

        // Plasma adds some spacing of its own around the widget (measured below); taking it
        // off keeps the padding around the icons as tight as designed.
        Layout.preferredWidth: restRowWidth + 2 * (G.side + G.pad) - panelExtra
        Layout.minimumWidth: Layout.preferredWidth
        Layout.maximumWidth: Layout.preferredWidth
        Layout.fillHeight: true

        // Magnification: h fades the effect in and out, mx is the pointer position in dock
        // coordinates. Both feed one layout function, so sizes and positions always agree.
        // The icons report mx themselves (DockItem.qml): a hover handler here gets positions
        // relative to whichever icon is under the pointer, not to the dock.
        property real mx: width / 2
        property int hoveredItems: 0
        readonly property bool pointerInside: hoveredItems > 0
        property real h: pointerInside ? 1 : 0
        Behavior on h { NumberAnimation { duration: dock.pointerInside ? 110 : 240; easing.type: Easing.OutCubic } }

        // Where the panel theme's glass mask lies, in dock coordinates. Plasma blurs the
        // background and takes mouse input exactly there (plasma_theme.py), so the glass the
        // dock draws must match it at rest. The panel background sits inside the panel
        // window with a floating margin, and the widget inside the background with
        // Plasma's spacing; both are measured from the window rather than assumed.
        property rect mask: Qt.rect(G.side, G.overflow, width - 2 * G.side, height - G.overflow)
        property real panelExtra: 0
        function measure() {
            const win = dock.Window.window
            if (!win || width <= 0 || height <= 0) return
            const p = dock.mapToItem(null, 0, 0)
            const float = (win.height - (height + 2)) / 2   // panel = widget + 1 px margins
            const bgLeft = float - p.x, bgRight = win.width - float - p.x
            const bgTop = float - p.y, bgBottom = win.height - float - p.y
            mask = Qt.rect(bgLeft + G.side, bgTop + G.overflow,
                           bgRight - bgLeft - 2 * G.side, bgBottom - bgTop - G.overflow)
            panelExtra = Math.max(0, bgRight - bgLeft - width)
        }
        onWidthChanged: Qt.callLater(measure)
        onHeightChanged: Qt.callLater(measure)
        onXChanged: Qt.callLater(measure)
        Connections {
            target: dock.Window.window
            function onWidthChanged() { Qt.callLater(dock.measure) }
            function onHeightChanged() { Qt.callLater(dock.measure) }
        }
        Timer { interval: 1500; running: true; onTriggered: dock.measure() }

        function restLeft(k) {
            const start = mask.x + (mask.width - restRowWidth) / 2
            return start + k * (G.icon + G.spacing) + (k === itemCount - 1 ? sepWidth : 0)
        }

        // Scale of item k: a cosine bump around the pointer, 2.5 icons wide each side.
        function scaleOf(k) {
            const d = Math.abs(mx - (restLeft(k) + G.icon / 2))
            const reach = G.icon * 2.5
            const f = d < reach ? (1 + Math.cos(Math.PI * d / reach)) / 2 : 0
            return 1 + (G.zoom - 1) * f * h
        }

        // Grown items push their neighbours apart. The growth left of the pointer is
        // subtracted, so the icon under the pointer stays under it (no jitter).
        readonly property var layout: {
            const n = itemCount, s = [], x = []
            let anchor = 0
            for (let k = 0; k < n; k++) {
                s.push(scaleOf(k))
                const extra = G.icon * (s[k] - 1)
                anchor += extra * Math.max(0, Math.min(1, (mx - restLeft(k)) / G.icon))
            }
            let cum = 0
            for (let k = 0; k < n; k++) {
                x.push(restLeft(k) + cum - anchor)
                cum += G.icon * (s[k] - 1)
            }
            return { scale: s, x: x }
        }

        // The dock draws its own glass (the panel theme leaves it empty), so the glass can
        // widen with the magnified icons like the macOS dock. One surface: two translucent
        // pieces side by side would show seams where they meet.
        // At rest it covers exactly the theme's mask, where the background is blurred.
        Rectangle {
            readonly property real leftEdge: Math.min(dock.mask.x, dock.layout.x[0] - G.pad)
            readonly property real rightEdge: Math.max(dock.mask.x + dock.mask.width,
                dock.layout.x[dock.itemCount - 1] + G.icon * dock.layout.scale[dock.itemCount - 1] + G.pad)
            x: leftEdge
            width: rightEdge - leftEdge
            y: dock.mask.y
            height: dock.mask.height
            radius: G.radius
            color: Qt.rgba(Kirigami.Theme.backgroundColor.r, Kirigami.Theme.backgroundColor.g,
                           Kirigami.Theme.backgroundColor.b, G.glassOpacity)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.25)   // the light hairline edge of macOS glass
        }

        DockItem {
            itemIndex: 0
            iconSource: "view-app-grid"
            label: root.tr("Launchpad", "Launchpad")
            onActivated: shell.run("dbus-send --session --type=method_call --dest=org.kde.plasmashell "
                                   + "/PlasmaShell org.kde.PlasmaShell.activateLauncherMenu")
        }

        Repeater {
            model: tasksModel
            delegate: DockItem {
                id: task
                required property var model
                required property int index
                readonly property var modelIndex: tasksModel.makeModelIndex(index)
                readonly property string launcherUrl: model.LauncherUrlWithoutIcon ? String(model.LauncherUrlWithoutIcon) : ""
                readonly property bool pinned: launcherUrl !== "" && tasksModel.launcherPosition(launcherUrl) >= 0

                itemIndex: index + 1
                iconSource: model.decoration
                label: model.AppName ? model.AppName : model.display
                running: model.IsLauncher !== true
                active: model.IsActive === true
                starting: model.IsStartup === true

                onActivated: {
                    if (model.IsLauncher || model.IsGroupParent || !model.IsActive) {
                        tasksModel.requestActivate(modelIndex)
                    } else {
                        tasksModel.requestToggleMinimized(modelIndex)
                    }
                }
                onNewInstance: tasksModel.requestNewInstance(modelIndex)
                menuEntries: [
                    { text: root.tr("Neues Fenster", "New Window"), icon: "window-new",
                      action: () => tasksModel.requestNewInstance(modelIndex) },
                    { text: pinned ? root.tr("Aus dem Dock entfernen", "Remove from Dock")
                                   : root.tr("Im Dock behalten", "Keep in Dock"),
                      icon: pinned ? "window-unpin" : "window-pin",
                      enabled: launcherUrl !== "",
                      action: () => pinned ? tasksModel.requestRemoveLauncher(launcherUrl)
                                           : tasksModel.requestAddLauncher(launcherUrl) },
                    { text: root.tr("Beenden", "Quit"), icon: "application-exit",
                      enabled: running, action: () => tasksModel.requestClose(modelIndex) },
                ]
            }
        }

        // Thin separator before the trash, like macOS.
        Rectangle {
            readonly property real leftEdge: dock.layout.x[dock.itemCount - 2] + G.icon * dock.layout.scale[dock.itemCount - 2]
            x: leftEdge + (dock.layout.x[dock.itemCount - 1] - leftEdge - width) / 2
            width: 1
            height: G.icon * 0.7
            anchors.bottom: parent.bottom
            anchors.bottomMargin: G.bottom + (G.icon - height) / 2
            color: Kirigami.Theme.textColor
            opacity: 0.25
        }

        DockItem {
            readonly property bool full: trashFolder.count > 0
            itemIndex: dock.itemCount - 1
            iconSource: full ? "user-trash-full" : "user-trash"
            label: root.tr("Papierkorb", "Trash")
            acceptsDrops: true
            onActivated: Qt.openUrlExternally("trash:/")
            onUrlsDropped: urls => shell.run("kioclient move " + urls.map(u => root.quote(u)).join(" ") + " trash:/")
            menuEntries: [
                { text: root.tr("Öffnen", "Open"), icon: "document-open",
                  action: () => Qt.openUrlExternally("trash:/") },
                { text: root.tr("Papierkorb leeren", "Empty Trash"), icon: "trash-empty",
                  enabled: full, action: () => shell.run("ktrash6 --empty") },
            ]
        }
    }
}
