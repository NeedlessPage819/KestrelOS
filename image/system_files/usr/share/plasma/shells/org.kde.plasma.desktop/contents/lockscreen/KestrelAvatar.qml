/*
    Round user picture for the Kestrel lock screen (DECISIONS.md D23). Like the Mac: the
    user's photo cropped to a circle, or, without a photo, the first letter of the name in
    white on a soft grey gradient.

    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Effects

Item {
    id: avatar

    property string source
    property string name

    Rectangle {
        id: plate
        anchors.fill: parent
        radius: width / 2
        gradient: Gradient {
            GradientStop { position: 0; color: "#b8b8be" }
            GradientStop { position: 1; color: "#7c7c82" }
        }
        visible: photo.status !== Image.Ready

        Text {
            anchors.centerIn: parent
            text: avatar.name.length > 0 ? avatar.name.charAt(0).toUpperCase() : ""
            color: "white"
            font.family: "Inter"
            font.weight: Font.DemiBold
            font.pixelSize: Math.round(avatar.height * 0.42)
            renderType: Text.CurveRendering
        }
    }

    Image {
        id: photo
        anchors.fill: parent
        source: avatar.source
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(width * 2, height * 2)
        asynchronous: true
        visible: false
    }
    Item {
        id: circle
        anchors.fill: parent
        layer.enabled: true
        visible: false
        Rectangle { anchors.fill: parent; radius: width / 2 }
    }
    MultiEffect {
        anchors.fill: parent
        visible: photo.status === Image.Ready
        source: photo
        maskEnabled: true
        maskSource: circle
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }
}
