// One icon in the Kestrel Dock: size and position come from the dock's layout (main.qml),
// the rest is presentation and input. Must be a direct child of the dock item.
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.extras as PlasmaExtras
import "geometry.js" as G

Item {
    id: item

    property int itemIndex: 0
    property var iconSource
    property string label
    property bool running: false     // shows the dot under the icon
    property bool active: false
    property bool starting: false    // app is launching: bounce
    property bool acceptsDrops: false
    property var menuEntries: []     // [{ text, icon, enabled, action }]

    signal activated()
    signal newInstance()
    signal urlsDropped(var urls)

    readonly property var lay: parent && parent.layout ? parent.layout : null
    readonly property real zoom: lay && lay.scale[itemIndex] !== undefined ? lay.scale[itemIndex] : 1

    x: lay && lay.x[itemIndex] !== undefined ? lay.x[itemIndex] : 0
    width: G.icon * zoom
    height: parent ? parent.height : 0

    // Rendered once at full magnified size and scaled down: sharp at every size and cheap
    // to animate, since the icon is not re-rendered on every frame.
    Kirigami.Icon {
        width: G.icon * G.zoom
        height: width
        source: item.iconSource
        smooth: true
        scale: item.zoom / G.zoom
        transformOrigin: Item.Bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: G.bottom + bounce.offset
        opacity: tap.pressed ? 0.7 : 1
    }

    // Launching apps bounce, like on macOS.
    QtObject { id: bounce; property real offset: 0 }
    SequentialAnimation {
        running: item.starting
        loops: Animation.Infinite
        NumberAnimation { target: bounce; property: "offset"; to: G.icon * 0.3; duration: 280; easing.type: Easing.OutQuad }
        NumberAnimation { target: bounce; property: "offset"; to: 0; duration: 280; easing.type: Easing.InQuad }
        onRunningChanged: if (!running) bounce.offset = 0
    }

    Rectangle {
        visible: item.running
        width: 4
        height: 4
        radius: 2
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: (G.bottom - height) / 2
        color: Kirigami.Theme.textColor
        opacity: item.active ? 0.9 : 0.55
    }

    // The interactive area: the visible icon plus the dot below it, not the empty band
    // above. It spans half the gap to each neighbour, so moving between icons never loses
    // the hover. (No Plasma tooltip: it would cover the magnified icon. See the label below.)
    Item {
        id: hit
        x: -G.spacing / 2
        width: parent.width + G.spacing
        height: G.icon * item.zoom + G.bottom
        anchors.bottom: parent.bottom

        // Tells the dock where the pointer is, in dock coordinates, for the magnification.
        HoverHandler {
            id: pointer
            onHoveredChanged: if (item.parent) item.parent.hoveredItems += hovered ? 1 : -1
            onPointChanged: if (hovered && item.parent) item.parent.mx = item.x + hit.x + point.position.x
        }

        TapHandler {
            id: tap
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            onTapped: (eventPoint, button) => {
                if (button === Qt.RightButton) {
                    item.openMenu()
                } else if (button === Qt.MiddleButton) {
                    item.newInstance()
                } else {
                    item.activated()
                }
            }
        }

        DropArea {
            anchors.fill: parent
            enabled: item.acceptsDrops
            onDropped: drop => {
                if (drop.hasUrls) {
                    item.urlsDropped(Array.from(drop.urls, String))
                    drop.accept(Qt.MoveAction)
                }
            }
        }
    }

    // The app name above the hovered icon, like the macOS dock label.
    z: pointer.hovered ? 1 : 0
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - G.bottom - G.icon * item.zoom - height - 6
        width: name.implicitWidth + 18
        height: name.implicitHeight + 8
        radius: height / 2
        color: Qt.rgba(Kirigami.Theme.backgroundColor.r, Kirigami.Theme.backgroundColor.g,
                       Kirigami.Theme.backgroundColor.b, 0.85)
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.08)
        opacity: pointer.hovered && item.label !== "" ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 120 } }

        Text {
            id: name
            anchors.centerIn: parent
            text: item.label
            color: Kirigami.Theme.textColor
            font: Kirigami.Theme.defaultFont
        }
    }
    Component.onDestruction: if (pointer.hovered && item.parent) item.parent.hoveredItems -= 1

    PlasmaExtras.Menu {
        id: menu
        visualParent: hit
    }
    Component {
        id: menuItemComponent
        PlasmaExtras.MenuItem {}
    }
    function openMenu() {
        if (menuEntries.length === 0) return
        menu.clearMenuItems()
        for (const entry of menuEntries) {
            const menuItem = menuItemComponent.createObject(menu, {
                text: entry.text, icon: entry.icon, enabled: entry.enabled !== false })
            menuItem.clicked.connect(entry.action)
            menu.addMenuItem(menuItem)
        }
        menu.openRelative()
    }
}
