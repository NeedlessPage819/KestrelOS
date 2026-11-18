/*
    Small round frosted button with a label under it (sleep, switch user) for the Kestrel
    lock screen (DECISIONS.md D23).

    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

QQC2.AbstractButton {
    id: button

    property string iconName

    Layout.alignment: Qt.AlignTop
    focusPolicy: Qt.TabFocus
    Accessible.name: text
    hoverEnabled: true

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            radius: 20
            color: Qt.rgba(1, 1, 1, button.pressed ? 0.32 : (button.hovered || button.activeFocus ? 0.26 : 0.18))
            Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }

            Kirigami.Icon {
                anchors.centerIn: parent
                width: 20
                height: 20
                source: button.iconName
                color: "white"
                isMask: true
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: button.text.replace("&", "")
            color: "white"
            opacity: 0.85
            font.family: "Inter"
            font.pixelSize: 11
        }
    }
    background: null
}
