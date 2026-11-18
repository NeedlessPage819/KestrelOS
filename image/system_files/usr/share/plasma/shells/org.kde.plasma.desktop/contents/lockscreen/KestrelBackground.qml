/*
    Kestrel lock screen background (DECISIONS.md D23): the wallpaper, sharp or blurred, or
    a plain colour, with a light dimming so the white text stays readable. Like the Mac,
    the wallpaper blurs softly (and zooms in a little) while the password prompt shows.

    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Effects
import org.kde.kirigami as Kirigami

Item {
    id: background

    property Item source              // the wallpaper item kscreenlocker provides
    property bool promptVisible: false

    // backgroundMode: 0 wallpaper, 1 blurred wallpaper, 2 colour
    readonly property int mode: config.backgroundMode
    readonly property real blurAmount: Math.max(0, Math.min(100, config.blurStrength)) / 100
    readonly property real blur: mode === 1 ? blurAmount
                                : (promptVisible && config.blurOnPrompt ? blurAmount : 0)

    // Fallback (and the colour mode): a dark colour under everything.
    Rectangle {
        anchors.fill: parent
        color: background.mode === 2 ? config.backgroundColor : "#1c1c1e"
    }

    MultiEffect {
        id: effect
        anchors.fill: parent
        visible: background.mode !== 2 && background.source !== null
        source: background.source
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 64
        blur: background.blur
        // Zoom in a little while blurred, so the soft edges of the blur stay off screen.
        scale: 1 + 0.06 * background.blur
        Behavior on blur { NumberAnimation { duration: Kirigami.Units.veryLongDuration; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Kirigami.Units.veryLongDuration; easing.type: Easing.OutCubic } }
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: Math.max(0, Math.min(80, config.dimming)) / 100
                 + (background.promptVisible ? 0.08 : 0)
        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.veryLongDuration } }
    }
}
