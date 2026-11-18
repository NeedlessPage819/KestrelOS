/*
    Kestrel lock screen user block (DECISIONS.md D23): at the bottom of the screen, like the
    Mac: the user's round picture, the name, and a rounded, frosted password field with an
    arrow button. Before a key is pressed only the picture, the name and a hint show.

    Replaces Plasma's MainBlock.qml (SPDX-FileCopyrightText: 2016 David Edmundson); the
    password handling (PasswordSync, clearPassword, passwordResult) works the same.

    SPDX-License-Identifier: LGPL-2.0-or-later
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes

import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.kscreenlocker as ScreenLocker

Item {
    id: block

    property bool lockScreenUiVisible: false
    property bool passwordInputVisible: true
    property alias showPassword: passwordBox.showPassword
    readonly property alias mainPasswordBox: passwordBox
    property string userName
    property string userImage
    property string notificationMessage
    property Item authenticationTypeItem
    property list<Item> actionItems

    readonly property bool german: Qt.locale().name.startsWith("de")
    function tr(de, en) { return german ? de : en }

    signal passwordResult(string password)

    function startLogin() {
        const password = passwordBox.text
        // Looks nicer, and works round a Qt bug when the app closes with a focused TextField
        // (QTBUG-55460).
        arrow.forceActiveFocus();
        passwordResult(password);
    }

    // Wrong password: shake the field sideways, like the Mac.
    function shake() { shakeAnimation.restart() }

    function playHighlightAnimation() { shakeAnimation.restart() }

    onAuthenticationTypeItemChanged: if (authenticationTypeItem) authenticationTypeItem.parent = authTypes
    onActionItemsChanged: for (const item of actionItems) item.parent = actions

    ColumnLayout {
        id: column
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(parent.height * 0.09)
        spacing: Kirigami.Units.largeSpacing

        // Custom message from the settings ("Wenn gefunden, bitte melden: ...").
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: Kirigami.Units.gridUnit * 30
            Layout.bottomMargin: Kirigami.Units.largeSpacing
            visible: text.length > 0
            text: config.message
            color: "white"
            opacity: 0.85
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            font.family: "Inter"
            font.pixelSize: 14
        }

        Kirigami.Avatar {
            id: avatar
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: config.avatarSize === 1 ? 96 : 64
            Layout.preferredHeight: Layout.preferredWidth
            visible: config.showAvatar
            source: block.userImage
            name: block.userName
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.3)
                shadowBlur: 0.5
                shadowVerticalOffset: 2
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            visible: config.showUserName
            text: block.userName
            color: "white"
            font.family: "Inter"
            font.weight: Font.DemiBold
            font.pixelSize: 15
        }

        // The password field, or a hint while the prompt is hidden. Both stay in place, so
        // nothing jumps; the field keeps the keyboard focus even while it is faded out.
        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 220
            Layout.preferredHeight: 32
            visible: block.passwordInputVisible

            transform: Translate { id: shakeOffset }
            SequentialAnimation {
                id: shakeAnimation
                loops: 1
                NumberAnimation { target: shakeOffset; property: "x"; to: -14; duration: 50; easing.type: Easing.OutQuad }
                NumberAnimation { target: shakeOffset; property: "x"; to: 12; duration: 70 }
                NumberAnimation { target: shakeOffset; property: "x"; to: -8; duration: 70 }
                NumberAnimation { target: shakeOffset; property: "x"; to: 5; duration: 60 }
                NumberAnimation { target: shakeOffset; property: "x"; to: 0; duration: 60; easing.type: Easing.OutQuad }
            }

            Text {
                anchors.centerIn: parent
                opacity: block.lockScreenUiVisible ? 0 : 0.7
                Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
                text: block.tr("Zum Entsperren eine Taste drücken", "Press any key to unlock")
                color: "white"
                font.family: "Inter"
                font.pixelSize: 13
            }

            QQC2.TextField {
                id: passwordBox

                property bool showPassword: false

                anchors.fill: parent
                opacity: block.lockScreenUiVisible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
                focus: true
                // Only draw the blinking cursor while the field is visible (saves redraws).
                cursorVisible: block.lockScreenUiVisible
                echoMode: showPassword ? TextInput.Normal : TextInput.Password
                passwordCharacter: "●"
                inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                text: PasswordSync.password
                placeholderText: block.tr("Passwort eingeben", "Enter Password")
                placeholderTextColor: Qt.rgba(1, 1, 1, 0.6)
                color: "white"
                selectionColor: Qt.rgba(1, 1, 1, 0.35)
                selectedTextColor: "white"
                font.family: "Inter"
                font.pixelSize: 13
                font.letterSpacing: echoMode === TextInput.Password ? 2 : 0
                horizontalAlignment: TextInput.AlignHCenter
                leftPadding: 30
                rightPadding: 30
                topPadding: 0
                bottomPadding: 0
                verticalAlignment: TextInput.AlignVCenter

                background: Rectangle {
                    radius: height / 2
                    color: Qt.rgba(1, 1, 1, passwordBox.activeFocus ? 0.24 : 0.18)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.22)
                }

                onAccepted: {
                    if (block.lockScreenUiVisible) {
                        block.startLogin();
                    }
                }

                Connections {
                    target: root
                    function onClearPassword() {
                        passwordBox.forceActiveFocus()
                        passwordBox.text = "";
                        passwordBox.text = Qt.binding(() => PasswordSync.password);
                    }
                    function onNotificationRepeated() {
                        block.playHighlightAnimation();
                    }
                }

                // Round arrow button inside the field, shown once something is typed.
                QQC2.AbstractButton {
                    id: arrow
                    anchors.right: parent.right
                    anchors.rightMargin: 5
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 22
                    opacity: passwordBox.text.length > 0 ? 1 : 0
                    enabled: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
                    Accessible.name: block.tr("Entsperren", "Unlock")
                    focusPolicy: Qt.TabFocus
                    onClicked: block.startLogin()
                    Keys.onEnterPressed: clicked()
                    Keys.onReturnPressed: clicked()

                    contentItem: Shape {
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeWidth: 0
                            strokeColor: "transparent"
                            fillColor: Qt.rgba(1, 1, 1, arrow.pressed ? 0.6 : (arrow.hovered ? 0.95 : 0.85))
                            PathAngleArc { centerX: 11; centerY: 11; radiusX: 11; radiusY: 11; startAngle: 0; sweepAngle: 360 }
                        }
                        ShapePath {
                            strokeWidth: 1.8
                            strokeColor: "#3a3a3c"
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            joinStyle: ShapePath.RoundJoin
                            startX: 6.5; startY: 11
                            PathLine { x: 15.5; y: 11 }
                            PathMove { x: 11.5; y: 7 }
                            PathLine { x: 15.5; y: 11 }
                            PathLine { x: 11.5; y: 15 }
                        }
                    }
                    background: null
                }
            }
            Binding {
                target: PasswordSync
                property: "password"
                value: passwordBox.text
            }
        }

        // Caps Lock, wrong password and other messages.
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            Layout.preferredHeight: Math.max(implicitHeight, 18)
            text: block.notificationMessage
            color: "white"
            opacity: text.length > 0 ? 0.9 : 0
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            font.family: "Inter"
            font.pixelSize: 12
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            opacity: block.lockScreenUiVisible ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }

            Item { id: authTypes; implicitWidth: childrenRect.width; implicitHeight: childrenRect.height }
        }

        FailableLabel {
            kind: ScreenLocker.Authenticator.Fingerprint
            label: block.tr("(oder Finger auf den Sensor legen)", "(or scan your fingerprint on the reader)")
        }
        FailableLabel {
            kind: ScreenLocker.Authenticator.Smartcard
            label: block.tr("(oder Smartcard einstecken)", "(or scan your smartcard)")
        }

        // Sleep, switch user: small round frosted buttons, only while the prompt shows.
        RowLayout {
            id: actions
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.gridUnit * 2
            visible: config.showPowerButtons && opacity > 0
            opacity: block.lockScreenUiVisible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
        }
    }

    component FailableLabel : Text {
        id: _failableLabel
        required property int kind
        required property string label

        Layout.alignment: Qt.AlignHCenter
        visible: authenticator.authenticatorTypes & kind
        text: label
        color: "white"
        opacity: 0.75
        font.family: "Inter"
        font.pixelSize: 12
        textFormat: Text.PlainText

        Connections {
            target: authenticator
            function onNoninteractiveError(kind, authenticator) {
                if (kind & _failableLabel.kind) {
                    _failableLabel.text = Qt.binding(() => authenticator.errorMessage)
                    _timer.restart()
                }
            }
        }
        Timer {
            id: _timer
            interval: Kirigami.Units.humanMoment
            onTriggered: _failableLabel.text = Qt.binding(() => _failableLabel.label)
        }
    }
}
