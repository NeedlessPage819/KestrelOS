// Kestrel Clock (DECISIONS.md D27): date and time in the top bar, like the Mac's menu bar
// clock ("Do. 19. Nov. 19:36"). It uses the system font at exactly the size of the menus.
//
// Plasma's own clock either fills the whole bar height (too big) or converts a fixed point
// size with the screen's physical pixel density, which makes it tiny on large TVs that report
// a low density. A click opens Plasma's calendar, as with Plasma's clock.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.workspace.calendar as PlasmaCalendar
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    property date now: new Date()

    // Like the Mac: short weekday, day, short month, then the time in the system's format.
    readonly property string dateText: {
        const de = Qt.locale().name.startsWith("de")
        return Qt.locale().toString(now, de ? "ddd d. MMM" : "ddd MMM d")
    }
    readonly property string timeText: Qt.locale().toString(now, Qt.locale().timeFormat(Locale.ShortFormat))

    toolTipMainText: Qt.locale().toString(now, Qt.locale().dateFormat(Locale.LongFormat))
    toolTipSubText: timeText

    Timer {
        // Ticks on the full minute, so the clock never lags behind.
        interval: 60000 - (new Date().getSeconds() * 1000 + new Date().getMilliseconds())
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.now = new Date()
            interval = 60000 - (root.now.getSeconds() * 1000 + root.now.getMilliseconds()) + 50
        }
    }

    compactRepresentation: MouseArea {
        id: compact
        Layout.minimumWidth: label.implicitWidth + Kirigami.Units.smallSpacing * 2
        Layout.maximumWidth: Layout.minimumWidth
        Layout.fillHeight: true
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded

        PlasmaComponents.Label {
            id: label
            anchors.centerIn: parent
            text: root.dateText + "  " + root.timeText
            font: Kirigami.Theme.defaultFont   // same font and size as the menus
            textFormat: Text.PlainText
            wrapMode: Text.NoWrap
        }
    }

    fullRepresentation: PlasmaCalendar.MonthView {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        Layout.preferredHeight: Kirigami.Units.gridUnit * 20
        Layout.minimumWidth: Kirigami.Units.gridUnit * 16
        Layout.minimumHeight: Kirigami.Units.gridUnit * 16
        borderOpacity: 0.25
        today: root.now
        showWeekNumbers: false
    }
}
