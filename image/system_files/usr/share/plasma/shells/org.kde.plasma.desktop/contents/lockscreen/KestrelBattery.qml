/*
    Battery for the Kestrel lock screen (DECISIONS.md D23): percentage and a small battery
    drawing in the top right corner, like the Mac. Hidden on computers without a battery.

    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasma5support as P5Support

RowLayout {
    id: battery

    readonly property var batteryData: source.data["Battery"] || {}
    readonly property bool present: batteryData["Has Battery"] === true
    readonly property int percent: batteryData["Percent"] || 0
    readonly property bool charging: (source.data["AC Adapter"] || {})["Plugged in"] === true

    visible: present
    spacing: 6

    P5Support.DataSource {
        id: source
        engine: "powermanagement"
        connectedSources: ["Battery", "AC Adapter"]
    }

    Text {
        text: battery.percent + " %"
        color: "white"
        font.family: "Inter"
        font.weight: Font.Medium
        font.pixelSize: 13
    }

    // Battery outline with its fill; green while charging, red when low.
    Item {
        implicitWidth: 25
        implicitHeight: 12
        Rectangle {
            id: body
            width: 22; height: 12
            radius: 3.5
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.55)
            Rectangle {
                x: 2; y: 2
                height: parent.height - 4
                width: Math.max(2, (parent.width - 4) * battery.percent / 100)
                radius: 1.5
                color: battery.charging ? "#34c759" : (battery.percent <= 10 ? "#ff453a" : "white")
            }
        }
        Rectangle {
            anchors.left: body.right
            anchors.leftMargin: 1
            anchors.verticalCenter: body.verticalCenter
            width: 2; height: 4
            radius: 1
            color: Qt.rgba(1, 1, 1, 0.55)
        }
    }
}
