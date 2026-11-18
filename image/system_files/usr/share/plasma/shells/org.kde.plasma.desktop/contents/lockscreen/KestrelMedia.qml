/*
    "Now playing" widget for the Kestrel lock screen (DECISIONS.md D23): a frosted card
    under the clock with the cover, title, artist and play controls, like the Mac's.
    Only shows while something is playing or paused.

    Based on Plasma's MediaControls.qml (SPDX-FileCopyrightText: 2016 Kai Uwe Broulik).

    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mpris as Mpris

Item {
    id: media

    property bool active: true
    signal interacted()

    readonly property bool german: Qt.locale().name.startsWith("de")

    visible: active && player.count > 0 && player.itemAt(0) !== null
    implicitWidth: 340
    implicitHeight: 76

    Repeater {
        id: player
        model: media.active ? mpris : null

        Rectangle {
            id: card
            required property var model
            width: media.width
            height: media.height
            radius: 18
            color: Qt.rgba(1, 1, 1, 0.16)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.14)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 52
                    Layout.preferredHeight: 52
                    radius: 10
                    color: Qt.rgba(1, 1, 1, 0.12)
                    clip: true
                    Image {
                        anchors.fill: parent
                        visible: status === Image.Ready
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                        source: card.model.artUrl
                        sourceSize.height: 104
                    }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 24; height: 24
                        visible: !card.model.artUrl
                        source: "media-default-album"
                        color: "white"
                        isMask: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: card.model.track || (media.german ? "Kein Titel" : "No title")
                        color: "white"
                        font.family: "Inter"
                        font.weight: Font.DemiBold
                        font.pixelSize: 14
                        textFormat: Text.PlainText
                    }
                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: card.model.artist || card.model.identity
                        color: "white"
                        opacity: 0.7
                        font.family: "Inter"
                        font.pixelSize: 12
                        textFormat: Text.PlainText
                    }
                }

                MediaButton {
                    icon: LayoutMirroring.enabled ? "media-skip-forward" : "media-skip-backward"
                    enabled: card.model.canGoPrevious
                    onClicked: card.model.container.Previous()
                }
                MediaButton {
                    big: true
                    icon: card.model.playbackStatus === Mpris.PlaybackStatus.Playing ? "media-playback-pause" : "media-playback-start"
                    enabled: card.model.canControl
                    onClicked: card.model.container.PlayPause()
                }
                MediaButton {
                    icon: LayoutMirroring.enabled ? "media-skip-backward" : "media-skip-forward"
                    enabled: card.model.canGoNext
                    onClicked: card.model.container.Next()
                }
            }
        }
    }

    // Only the player Plasma itself shows (the "multiplexer"), not one card per app.
    Mpris.MultiplexerModel { id: mpris }

    component MediaButton : QQC2.AbstractButton {
        id: mediaButton
        property string icon
        property bool big: false
        implicitWidth: big ? 34 : 28
        implicitHeight: implicitWidth
        focusPolicy: Qt.TabFocus
        hoverEnabled: true
        opacity: enabled ? 1 : 0.35
        onClicked: media.interacted()
        contentItem: Kirigami.Icon {
            source: mediaButton.icon
            color: "white"
            isMask: true
        }
        background: Rectangle {
            radius: width / 2
            color: Qt.rgba(1, 1, 1, mediaButton.pressed ? 0.25 : (mediaButton.hovered ? 0.15 : 0))
        }
    }
}
