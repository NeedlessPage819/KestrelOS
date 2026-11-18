/*
    Kestrel OS login splash (DECISIONS.md D24), shown while Plasma starts after logging in.
    Like the Mac: the softly blurred Kestrel wallpaper (the login screen shows it too, so
    nothing jumps), the white Kestrel mark and a thin progress bar, then a fade into the
    desktop. Replaces Breeze's black KDE splash.

    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

Rectangle {
    id: root

    // Set by ksplashqml: 1 to 6 while Plasma starts; the splash closes after 6.
    property int stage

    // Light or dark wallpaper, matching the colour scheme (Kestrel or Kestrel Dunkel).
    readonly property bool dark: Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.backgroundColor)
                                 === Kirigami.ColorUtils.Dark

    color: dark ? "#14131a" : "#b8b4e6"

    Image {
        id: wallpaper
        anchors.fill: parent
        visible: false
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(1920, 1080)
        source: "file:///usr/share/wallpapers/Kestrel/contents/" + (root.dark ? "images_dark" : "images")
                + "/3840x2160.png"
    }
    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        visible: wallpaper.status === Image.Ready
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 64
        blur: 0.6
        scale: 1.04          // keeps the soft edges of the blur off screen
        brightness: -0.04
    }

    Item {
        id: content
        anchors.centerIn: parent
        width: 220
        height: 150
        opacity: 0

        // The Kestrel mark (same path as the boot screen logo, 16x16 units).
        Shape {
            id: mark
            anchors.horizontalCenter: parent.horizontalCenter
            width: 96
            height: 96
            preferredRendererType: Shape.CurveRenderer
            layer.enabled: true
            layer.samples: 4
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.25)
                shadowBlur: 0.6
                shadowVerticalOffset: 2
            }
            ShapePath {
                scale: Qt.size(6, 6)
                strokeWidth: -1
                fillColor: "white"
                PathSvg {
                    path: "M1 6.2 C3.4 4.2 5.9 4.4 8 7.6 C10.1 4.4 12.6 4.2 15 6.2 C12.4 5.9 10.2 7.2 8 11.2 C5.8 7.2 3.6 5.9 1 6.2 Z"
                }
            }
        }

        // Thin progress bar like the Mac's start screen.
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: 180
            height: 5
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.28)

            Rectangle {
                height: parent.height
                radius: height / 2
                color: "white"
                width: parent.width * Math.min(1, Math.max(0.08, root.stage / 6))
                Behavior on width {
                    NumberAnimation { duration: Kirigami.Units.veryLongDuration; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    onStageChanged: {
        if (stage === 2) {
            fadeIn.running = true;
        }
    }

    OpacityAnimator {
        id: fadeIn
        target: content
        from: 0
        to: 1
        duration: Kirigami.Units.longDuration * 2
        easing.type: Easing.OutCubic
    }
}
