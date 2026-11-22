// Kestrel Launchpad (DECISIONS.md D32): all apps in a full-screen grid over the blurred
// desktop, with a search field and pages, like Launchpad on the Mac.
//
// Pure QML. The app list is Plasma's own (AppsModel from the kicker components, the same that
// KDE's Application Dashboard uses), so new apps and Flatpaks appear by themselves. The window
// is Plasma's DashboardWindow: full screen on the screen of the button, blurred behind.
// It provides "org.kde.plasma.launchermenu", so the dock's Launchpad icon and the Meta key
// open it too (PlasmaShell.activateLauncherMenu).
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.kicker as Kicker

PlasmoidItem {
    id: root

    preferredRepresentation: compactRepresentation
    readonly property string buttonIcon: Plasmoid.configuration.icon || "kestrel-logo-symbolic"
    Plasmoid.icon: buttonIcon
    toolTipMainText: "Launchpad"
    toolTipSubText: ""

    readonly property bool german: Qt.locale().name.startsWith("de")
    function tr(de, en) { return german ? de : en }

    // ---- State --------------------------------------------------------------------------
    property bool open: false
    function show() {
        if (open) return
        open = true
        view.reset()
        dash.showFullScreen()      // covers the whole screen, top bar and dock included
        view.searchField.forceActiveFocus()
        openAnimation.restart()
    }
    function close() {
        if (!open) return
        open = false
        closeAnimation.restart()      // hides the window when done
    }
    function toggle() { open ? close() : show() }
    Connections {
        target: Plasmoid
        function onActivated() { root.toggle() }
    }

    // ---- Button in the top bar (the bird) -----------------------------------------------
    compactRepresentation: MouseArea {
        id: button
        hoverEnabled: true
        Layout.minimumWidth: Kirigami.Units.iconSizes.small
        Layout.preferredWidth: height      // square, as tall as the top bar
        onClicked: root.toggle()
        Kirigami.Icon {
            anchors.fill: parent
            source: root.buttonIcon
            active: button.containsMouse || root.open
        }
    }

    // ---- Apps ---------------------------------------------------------------------------
    // Plasma's launcher model; its first row is "All Applications", flat and sorted, exactly
    // the list KDE's own dashboard shows. It keeps itself up to date as apps come and go.
    Kicker.RootModel {
        id: rootModel
        appletInterface: root
        autoPopulate: false
        flat: true
        sorted: true
        showSeparators: false
        showTopLevelItems: false
        showAllApps: true
        showAllAppsCategorized: false
        showRecentApps: false
        showRecentDocs: false
        showRecentFolders: false
        showPowerSession: false
        showFavoritesPlaceholder: false
        appNameFormat: 0           // just the name, "Firefox", not "Firefox (Web Browser)"
        onRefreshed: root.apps = modelForRow(0)
        Component.onCompleted: refresh()
    }
    property var apps: null
    onAppsChanged: refresh()
    Connections {
        target: root.apps
        function onCountChanged() { root.refresh() }
    }

    // Plain list of {name, icon, row}; the grid pages and the search work on this.
    property var allApps: []
    function refresh() {
        if (!apps) return
        const list = [], seen = {}
        for (let i = 0; i < apps.count; ++i) {
            const idx = apps.index(i, 0)
            const name = String(apps.data(idx, Qt.DisplayRole) || "")
            if (!name || seen[name]) continue      // an app listed in two categories shows once
            seen[name] = true
            list.push({ name: name, icon: apps.data(idx, Qt.DecorationRole), row: i })
        }
        list.sort((a, b) => a.name.localeCompare(b.name))
        allApps = list
    }
    property string query: ""
    // While searching: names that start with the text first, then names that contain it.
    readonly property var shownApps: {
        const q = query.trim().toLowerCase()
        if (!q) return allApps
        const starts = [], contains = []
        for (const a of allApps) {
            const n = a.name.toLowerCase()
            if (n.startsWith(q) || n.split(" ").some(w => w.startsWith(q))) starts.push(a)
            else if (n.includes(q)) contains.push(a)
        }
        return starts.concat(contains)
    }
    function launch(app) {
        apps.trigger(app.row, "", null)
        close()
    }

    // ---- The full-screen window ---------------------------------------------------------
    Kicker.DashboardWindow {
        id: dash
        visible: false
        visualParent: root.compactRepresentationItem
        backgroundColor: "transparent"      // the blur shows through; the tint is drawn below
        keyEventProxy: view.searchField
        onActiveChanged: if (!active && visible) root.close()
        // The window catches Esc itself: first it clears the search, then it closes.
        onKeyEscapePressed: view.searchField.text ? (view.searchField.text = "") : root.close()

        mainItem: MouseArea {
            id: view
            property alias searchField: search
            readonly property real s: Math.max(0.6, Math.min(width / 1920, height / 1080))
            anchors.fill: parent
            onClicked: root.close()      // a click on empty space closes, like on the Mac
            onWheel: wheel => pages.wheelStep(wheel.angleDelta.y || -wheel.angleDelta.x)

            function reset() {
                search.text = ""
                pages.positionViewAtIndex(0, ListView.Beginning)
                pages.currentIndex = 0
            }

            // Tint over the blurred desktop.
            Rectangle {
                id: tint
                anchors.fill: parent
                color: Qt.rgba(0.05, 0.05, 0.08, 0.32)
            }

            Item {
                id: content
                anchors.fill: parent
                transformOrigin: Item.Center

                // Search field, top centre.
                QQC2.TextField {
                    id: search
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round(parent.height * 0.055)
                    width: Math.round(240 * view.s)
                    height: Math.round(32 * view.s)
                    leftPadding: Math.round(30 * view.s)
                    color: "white"
                    placeholderText: root.tr("Suchen", "Search")
                    placeholderTextColor: Qt.rgba(1, 1, 1, 0.65)
                    font.pixelSize: Math.round(15 * view.s)
                    horizontalAlignment: activeFocus || text ? TextInput.AlignLeft : TextInput.AlignHCenter
                    focus: true
                    background: Rectangle {
                        radius: height / 2
                        color: Qt.rgba(1, 1, 1, search.activeFocus ? 0.22 : 0.16)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.22)
                    }
                    Kirigami.Icon {
                        source: "search"
                        color: Qt.rgba(1, 1, 1, 0.75)
                        isMask: true
                        width: Math.round(15 * view.s); height: width
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.round(10 * view.s)
                    }
                    onTextChanged: {
                        root.query = text
                        pages.currentIndex = 0
                        pages.positionViewAtIndex(0, ListView.Beginning)
                    }
                    Keys.onEscapePressed: text ? (text = "") : root.close()
                    Keys.onReturnPressed: if (root.shownApps.length) root.launch(root.shownApps[0])
                    Keys.onEnterPressed: if (root.shownApps.length) root.launch(root.shownApps[0])
                    Keys.onLeftPressed: event => { if (!text) pages.decrementCurrentIndex(); else event.accepted = false }
                    Keys.onRightPressed: event => { if (!text) pages.incrementCurrentIndex(); else event.accepted = false }
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_PageDown) pages.incrementCurrentIndex()
                        else if (event.key === Qt.Key_PageUp) pages.decrementCurrentIndex()
                    }
                }

                // Grid geometry: 7 x 5 like the Mac on a wide screen, fewer columns when narrow.
                readonly property real gridTop: parent.height * 0.14
                readonly property real gridHeight: parent.height * 0.73
                readonly property real gridWidth: Math.min(parent.width * 0.82, gridHeight * 1.9)
                readonly property int columns: Math.max(4, Math.min(7, Math.floor(gridWidth / (150 * view.s))))
                readonly property int rows: Math.max(3, Math.min(5, Math.floor(gridHeight / (140 * view.s))))
                readonly property int perPage: columns * rows
                readonly property real cellW: gridWidth / columns
                readonly property real cellH: gridHeight / rows
                readonly property int iconSize: Math.round(Math.min(cellW * 0.62, cellH * 0.62, 112 * view.s))

                ListView {
                    id: pages
                    x: (parent.width - width) / 2
                    y: content.gridTop
                    width: content.gridWidth
                    height: content.gridHeight
                    orientation: ListView.Horizontal
                    snapMode: ListView.SnapOneItem
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    highlightMoveDuration: 280
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true          // the next page stays hidden until you switch
                    model: Math.max(1, Math.ceil(root.shownApps.length / content.perPage))

                    property real wheelAcc: 0
                    function wheelStep(delta) {
                        wheelAcc += delta
                        if (wheelAcc <= -120) { incrementCurrentIndex(); wheelAcc = 0 }
                        else if (wheelAcc >= 120) { decrementCurrentIndex(); wheelAcc = 0 }
                    }

                    delegate: Item {
                        id: page
                        required property int index
                        width: pages.width
                        height: pages.height
                        Grid {
                            columns: content.columns
                            Repeater {
                                model: root.shownApps.slice(page.index * content.perPage,
                                                            (page.index + 1) * content.perPage)
                                delegate: MouseArea {
                                    id: tile
                                    required property var modelData
                                    required property int index
                                    width: content.cellW
                                    height: content.cellH
                                    hoverEnabled: true
                                    // While searching, the first result is what Enter opens.
                                    readonly property bool first: root.query && page.index === 0 && index === 0
                                    onClicked: root.launch(modelData)

                                    Rectangle {      // soft highlight for the Enter target
                                        anchors.centerIn: icon
                                        width: icon.width * 1.25; height: width
                                        radius: width * 0.22
                                        color: Qt.rgba(1, 1, 1, 0.16)
                                        visible: tile.first
                                    }
                                    Kirigami.Icon {
                                        id: icon
                                        source: tile.modelData.icon
                                        width: content.iconSize; height: width
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: (parent.height - height - label.implicitHeight - 8 * view.s) / 2
                                        scale: tile.pressed ? 0.9 : 1
                                        Behavior on scale { NumberAnimation { duration: 90 } }
                                    }
                                    Text {
                                        id: label
                                        text: tile.modelData.name
                                        color: "white"
                                        style: Text.Raised
                                        styleColor: Qt.rgba(0, 0, 0, 0.35)
                                        font.pixelSize: Math.round(13 * view.s)
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                        width: parent.width - 12 * view.s
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.top: icon.bottom
                                        anchors.topMargin: Math.round(8 * view.s)
                                    }
                                }
                            }
                        }
                    }
                }

                // Nothing found.
                Text {
                    anchors.centerIn: pages
                    visible: root.query && root.shownApps.length === 0
                    text: root.tr("Keine Treffer", "No results")
                    color: Qt.rgba(1, 1, 1, 0.7)
                    font.pixelSize: Math.round(20 * view.s)
                }

                // Page dots.
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: pages.y + pages.height + Math.round(18 * view.s)
                    spacing: Math.round(11 * view.s)
                    visible: pages.count > 1
                    Repeater {
                        model: pages.count
                        delegate: MouseArea {
                            required property int index
                            width: Math.round(8 * view.s); height: width
                            onClicked: pages.currentIndex = index
                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: "white"
                                opacity: index === pages.currentIndex ? 0.95 : 0.35
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }
                        }
                    }
                }
            }

            // Opening: the grid settles in from slightly larger while everything fades in.
            ParallelAnimation {
                id: openAnimation
                NumberAnimation { target: content; property: "scale"; from: 1.08; to: 1; duration: 220; easing.type: Easing.OutCubic }
                NumberAnimation { target: content; property: "opacity"; from: 0; to: 1; duration: 180 }
                NumberAnimation { target: tint; property: "opacity"; from: 0; to: 1; duration: 180 }
            }
            SequentialAnimation {
                id: closeAnimation
                ParallelAnimation {
                    NumberAnimation { target: content; property: "scale"; to: 1.08; duration: 150; easing.type: Easing.InCubic }
                    NumberAnimation { target: content; property: "opacity"; to: 0; duration: 150 }
                    NumberAnimation { target: tint; property: "opacity"; to: 0; duration: 150 }
                }
                ScriptAction { script: dash.visible = false }
            }
        }
    }
}
