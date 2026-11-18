/*
    Kestrel OS lock screen (DECISIONS.md D23), in the style of the Mac's lock screen:
    the wallpaper, a large clock and the date at the top, widgets under the clock, and the
    user's picture, name and a rounded password field at the bottom.

    Based on Plasma's LockScreenUi.qml (SPDX-FileCopyrightText: 2014 Aleix Pol Gonzalez,
    2026 Kristen McWilliam). The unlocking logic (authenticator, PAM timeouts, sleep, the
    keyboard layout) is kept from there unchanged; only the look is new.

    SPDX-License-Identifier: GPL-2.0-or-later

    Settings (System Settings > Screen Locking > Appearance) are in config.xml and
    config.qml. If this file fails to load, kscreenlocker uses its built-in lock screen,
    so the screen can always be unlocked.
*/

pragma ComponentBehavior: Bound

import QtQml
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts

import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.private.accessibility
import org.kde.plasma.workspace.components as PW
import org.kde.plasma.workspace.keyboardlayout as Keyboards
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator
import org.kde.kirigami as Kirigami
import org.kde.kscreenlocker as ScreenLocker
import org.kde.ki18n

import org.kde.plasma.private.sessions
import org.kde.breeze.components

Item {
    id: lockScreenUi

    property bool expectingPrompt: false // set for real when an authenticator is selected
    property bool showPrompt: false      // set for real when an authenticator is selected
    property string pendingPassword

    // German or English texts: the lock screen has no translation catalogue of its own.
    readonly property bool german: Qt.locale().name.startsWith("de")
    function tr(de, en) { return german ? de : en }

    function handleMessage(msg) {
        if (!msg) {
            return;
        }
        if (!root.notification) {
            root.notification += msg;
        } else if (root.notification.includes(msg)) {
            root.notificationRepeated();
        } else {
            root.notification += "\n" + msg
        }
        lockScreenRoot.uiVisible = true
    }

    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.Complementary

    Connections {
        target: authenticator
        function onFailed(kind) {
            if (kind != 0) { // coming from the noninteractive authenticators
                return;
            }
            lockScreenUi.handleMessage(lockScreenUi.tr("Falsches Passwort", "Incorrect password"));
            root.clearPassword();
            authenticator.startAuthenticating();
            notificationRemoveTimer.restart();
            mainBlock.shake();
        }

        function onSucceeded() {
            // Stops all pending authentication processes, preventing timeouts etc.
            authenticator.stopAuthenticating()

            if (!lockScreenUi.expectingPrompt) {
                Qt.quit()
            }
            if (authenticator.hadPrompt) {
                Qt.quit();
            } else {
                mainStack.replace(null, Qt.resolvedUrl("NoPasswordUnlock.qml"),
                    { userListModel: users }, StackView.Immediate);
                mainStack.forceActiveFocus();
            }
        }

        function onInfoMessageChanged() { lockScreenUi.handleMessage(authenticator.infoMessage); }
        function onErrorMessageChanged() { lockScreenUi.handleMessage(authenticator.errorMessage); }
        function onPromptChanged() { lockScreenUi.handleMessage(authenticator.prompt); }
        function onPromptForSecretChanged() {
            mainBlock.showPassword = false;
            mainBlock.mainPasswordBox.forceActiveFocus();
            if (lockScreenUi.showPrompt) {
                lockScreenUi.handleMessage(authenticator.promptForSecret);
            }
        }
    }

    SessionManagement { id: sessionManagement }
    AccessibilityStatus { id: accessibilityStatus }
    KeyboardIndicator.KeyState { id: capsLockState; key: Qt.Key_CapsLock }

    Connections {
        target: sessionManagement
        function onAboutToSuspend() { root.clearPassword(); }
    }

    ListModel {
        id: users
        Component.onCompleted: {
            users.append({
                name: kscreenlocker_userName,
                realName: kscreenlocker_userName,
                icon: kscreenlocker_userImage !== ""
                      ? "file://" + kscreenlocker_userImage.split("/").map(encodeURIComponent).join("/")
                      : "",
            })
        }
    }

    MouseArea {
        id: lockScreenRoot

        // uiVisible: the password prompt is shown (after a key press, click or mouse move).
        property bool uiVisible: false
        property bool seenPositionChange: false
        property bool blockUI: containsMouse && (mainStack.depth > 1 || mainBlock.mainPasswordBox.text.length > 0 || Keyboards.KWinVirtualKeyboard.visible)

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: uiVisible ? Qt.ArrowCursor : Qt.BlankCursor
        drag.filterChildren: true
        onPressed: uiVisible = true;
        onPositionChanged: {
            uiVisible = seenPositionChange;
            seenPositionChange = true;
        }
        onUiVisibleChanged: {
            if (uiVisible) {
                Window.window.requestActivate();
            }
            if (blockUI) {
                fadeoutTimer.running = false;
            } else if (uiVisible) {
                fadeoutTimer.restart();
            }
            authenticator.startAuthenticating();
        }

        Timer { // heart beat keeping the backend active for as long as we are in visible state
            interval: 1000
            running: !authenticator.unlocked && parent.uiVisible
            repeat: true
            onTriggered: authenticator.startAuthenticating()
        }

        onBlockUIChanged: {
            if (blockUI) {
                fadeoutTimer.running = false;
                uiVisible = true;
            } else {
                fadeoutTimer.restart();
            }
        }
        ScreenLocker.ActiveScreenMonitor {
            lockscreenState: ScreenLocker.LockscreenState
            window: lockScreenRoot.Window.window
            onActiveChanged: {
                if (!active) {
                    lockScreenRoot.uiVisible = false;
                }
            }
        }
        Keys.onEscapePressed: {
            // Escape makes kscreenlocker turn off the screen; hide the prompt then.
            if (uiVisible) {
                uiVisible = false;
                if (Keyboards.KWinVirtualKeyboard.visible) {
                    Keyboards.KWinVirtualKeyboard.active = false;
                }
                root.clearPassword();
            }
        }
        Keys.onPressed: event => {
            uiVisible = true;
            event.accepted = false;
        }
        Timer {
            id: fadeoutTimer
            interval: 10000
            onTriggered: {
                if (!lockScreenRoot.blockUI) {
                    mainBlock.showPassword = false;
                    lockScreenRoot.uiVisible = false;
                }
            }
        }
        Timer {
            id: notificationRemoveTimer
            interval: 3000
            onTriggered: root.notification = ""
        }

        // Fade in when the screen locks.
        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.veryLongDuration * 2; easing.type: Easing.OutCubic } }

        KestrelBackground {
            anchors.fill: parent
            source: wallpaper
            promptVisible: lockScreenRoot.uiVisible
        }

        // Clock and date at the top, widgets under them.
        ColumnLayout {
            id: top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Math.round(parent.height * (config.clockStyle === 1 ? 0.05 : 0.07))
            width: Math.min(parent.width - Kirigami.Units.gridUnit * 4, Kirigami.Units.gridUnit * 40)
            spacing: Kirigami.Units.gridUnit
            opacity: lockScreenRoot.uiVisible || !config.hideWhenIdle ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }

            KestrelClock {
                Layout.alignment: Qt.AlignHCenter
                screenHeight: lockScreenRoot.height
                visible: config.clockStyle !== 2 || config.showDate
            }

            KestrelMedia {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Kirigami.Units.gridUnit
                active: config.showMediaControls
                onInteracted: fadeoutTimer.restart()
            }
        }

        // Status in the top right corner, like the Mac's lock screen: keyboard layout, battery.
        RowLayout {
            anchors { top: parent.top; right: parent.right; margins: Kirigami.Units.largeSpacing }
            spacing: Kirigami.Units.largeSpacing

            PlasmaComponents3.ToolButton {
                id: keyboardButton
                focusPolicy: Qt.TabFocus
                Accessible.description: lockScreenUi.tr("Tastaturbelegung wechseln", "Switch layout")
                icon.name: "input-keyboard"
                text: keyboardLayoutSwitcher.layoutNames.shortName
                visible: config.showKeyboardLayout && keyboardLayoutSwitcher.hasMultipleKeyboardLayouts
                onClicked: keyboardLayoutSwitcher.keyboardLayout.switchToNextLayout()
                PW.KeyboardLayoutSwitcher {
                    id: keyboardLayoutSwitcher
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                }
            }

            PlasmaComponents3.ToolButton {
                focusPolicy: Qt.TabFocus
                text: lockScreenUi.tr("Bildschirmtastatur", "Virtual Keyboard")
                display: AbstractButton.IconOnly
                icon.name: Keyboards.KWinVirtualKeyboard.visible ? "input-keyboard-virtual-on" : "input-keyboard-virtual-off"
                visible: Keyboards.KWinVirtualKeyboard.available
                onClicked: {
                    if (Keyboards.KWinVirtualKeyboard.visible) {
                        Keyboards.KWinVirtualKeyboard.active = false;
                    } else {
                        // Otherwise the password field loses focus and keystrokes get eaten.
                        mainBlock.mainPasswordBox.forceActiveFocus();
                        Keyboards.KWinVirtualKeyboard.forceActivate();
                    }
                }
            }

            Battery { visible: config.showBattery }
        }

        StackView {
            id: mainStack
            anchors.fill: parent
            focus: true // StackView is an implicit focus scope
            visible: opacity > 0

            initialItem: MainBlock {
                id: mainBlock
                lockScreenUiVisible: lockScreenRoot.uiVisible
                userName: kscreenlocker_userName
                userImage: users.count > 0 ? users.get(0).icon : ""

                StackView.onStatusChanged: {
                    // prepare for presenting again to the user
                    if (StackView.status === StackView.Activating) {
                        mainPasswordBox.clear();
                        mainPasswordBox.focus = true;
                        root.notification = "";
                    }
                }

                notificationMessage: {
                    const parts = [];
                    if (capsLockState.locked) {
                        parts.push(lockScreenUi.tr("Feststelltaste ist aktiv", "Caps Lock is on"));
                    }
                    if (accessibilityStatus.slowKeysEnabled) {
                        parts.push(lockScreenUi.tr("Tastenverzögerung ist aktiv", "Slow Keys are enabled"));
                    }
                    if (root.notification) {
                        parts.push(root.notification);
                    }
                    return parts.join(" • ");
                }

                onPasswordResult: password => {
                    if (authenticator.pamTimeout) {
                        lockScreenUi.pendingPassword = password
                        mainBlock.enabled = false
                    } else {
                        authenticator.respond(password)
                    }
                }

                authenticationTypeItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    visible: authenticationTypeRepeater.count > 1

                    Repeater {
                        id: authenticationTypeRepeater
                        model: ScreenLocker.AuthenticatorModel

                        delegate: PlasmaComponents3.ToolButton {
                            required property int type
                            required property string iconName
                            required property bool passwordField
                            required property bool expectingPrompt
                            required property string tooltip
                            required property bool showPrompt
                            required property bool functional

                            onFunctionalChanged: {
                                if (functional) {
                                    return
                                }
                                root.notification = ""
                                mainBlock.passwordInputVisible = false
                                lockScreenUi.handleMessage(lockScreenUi.tr(
                                    "Diese Anmeldeart funktioniert gerade nicht. Bitte eine andere wählen.",
                                    "This authentication method is not functioning correctly. Please try another method."))
                            }

                            // Be careful if you remove this to ensure defunct handling is present in all scenarios
                            enabled: functional
                            icon.name: iconName
                            icon.color: functional ? undefined : Kirigami.Theme.negativeTextColor
                            checkable: true
                            checked: authenticator.authenticator === type
                            onClicked: {
                                authenticator.authenticator = type
                                root.notification = ""
                                mainBlock.passwordInputVisible = passwordField
                                lockScreenUi.expectingPrompt = expectingPrompt
                                lockScreenUi.showPrompt = showPrompt
                            }

                            PlasmaComponents3.ToolTip.text: tooltip
                            PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
                            PlasmaComponents3.ToolTip.visible: hovered

                            Component.onCompleted: {
                                if (checked) {
                                    clicked()
                                }
                            }
                        }
                    }
                }

                actionItems: [
                    KestrelActionButton {
                        text: lockScreenUi.tr("Ruhezustand", "Sleep")
                        iconName: "system-suspend"
                        onClicked: sessionManagement.suspend()
                        visible: sessionManagement.canSuspend
                    },
                    KestrelActionButton {
                        text: lockScreenUi.tr("Tiefschlaf", "Hibernate")
                        iconName: "system-suspend-hibernate"
                        onClicked: sessionManagement.hibernate()
                        visible: sessionManagement.canHibernate
                    },
                    KestrelActionButton {
                        text: lockScreenUi.tr("Benutzer wechseln", "Switch User")
                        iconName: "system-switch-user"
                        onClicked: sessionManagement.switchUser()
                        visible: sessionManagement.canSwitchUser
                    }
                ]
            }
        }

        Connections {
            target: authenticator
            function onPamTimeoutChanged(): void {
                if (!authenticator.pamTimeout && lockScreenUi.pendingPassword.length > 0) {
                    authenticator.respond(lockScreenUi.pendingPassword);
                    lockScreenUi.pendingPassword = "";
                    mainBlock.enabled = true;
                }
            }
        }

        Loader {
            z: 2
            active: root.viewVisible
            source: "LockOsd.qml"
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: Kirigami.Units.gridUnit
            }
        }
    }
}
