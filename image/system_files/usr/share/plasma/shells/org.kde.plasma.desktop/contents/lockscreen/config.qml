/*
    Settings page of the Kestrel lock screen (DECISIONS.md D23), shown in System Settings >
    Screen Locking > Configure Appearance. Every cfg_ property is one entry of config.xml;
    the settings page reads them in and saves them when they change.

    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: form

    readonly property bool german: Qt.locale().name.startsWith("de")
    function tr(de, en) { return german ? de : en }

    property int cfg_clockStyle
    property int cfg_clockWeight
    property int cfg_timeFormat
    property bool cfg_showSeconds
    property bool cfg_showDate
    property int cfg_dateFormat
    property int cfg_backgroundMode
    property bool cfg_blurOnPrompt
    property int cfg_blurStrength
    property int cfg_dimming
    property string cfg_backgroundColor
    property bool cfg_showMediaControls
    property bool cfg_showBattery
    property bool cfg_showKeyboardLayout
    property string cfg_message
    property bool cfg_hideWhenIdle
    property bool cfg_showAvatar
    property int cfg_avatarSize
    property bool cfg_showUserName
    property bool cfg_showPowerButtons

    twinFormLayouts: parentLayout

    // ---- Clock ----
    Kirigami.Separator {
        Kirigami.FormData.isSection: true
        Kirigami.FormData.label: form.tr("Uhr", "Clock")
    }
    QQC2.ComboBox {
        Kirigami.FormData.label: form.tr("Uhr:", "Clock:")
        model: [form.tr("Groß", "Large"), form.tr("Klein", "Small"), form.tr("Aus", "Hidden")]
        currentIndex: form.cfg_clockStyle
        onActivated: index => form.cfg_clockStyle = index
    }
    QQC2.ComboBox {
        Kirigami.FormData.label: form.tr("Schriftstärke:", "Font weight:")
        enabled: form.cfg_clockStyle !== 2
        model: [form.tr("Dünn", "Light"), form.tr("Normal", "Regular"), form.tr("Halbfett", "Semibold"), form.tr("Fett", "Bold")]
        currentIndex: form.cfg_clockWeight
        onActivated: index => form.cfg_clockWeight = index
    }
    QQC2.ComboBox {
        Kirigami.FormData.label: form.tr("Zeitformat:", "Time format:")
        enabled: form.cfg_clockStyle !== 2
        model: [form.tr("Wie im System", "Like the system"), form.tr("24 Stunden", "24 hours"), form.tr("12 Stunden", "12 hours")]
        currentIndex: form.cfg_timeFormat
        onActivated: index => form.cfg_timeFormat = index
    }
    QQC2.CheckBox {
        enabled: form.cfg_clockStyle !== 2
        text: form.tr("Sekunden anzeigen", "Show seconds")
        checked: form.cfg_showSeconds
        onToggled: form.cfg_showSeconds = checked
    }
    QQC2.CheckBox {
        Kirigami.FormData.label: form.tr("Datum:", "Date:")
        text: form.tr("Datum anzeigen", "Show date")
        checked: form.cfg_showDate
        onToggled: form.cfg_showDate = checked
    }
    QQC2.ComboBox {
        enabled: form.cfg_showDate
        model: [form.tr("Lang (Mittwoch, 18. November)", "Long (Wednesday, November 18)"),
                form.tr("Kurz (Mi., 18. Nov.)", "Short (Wed, Nov 18)"),
                form.tr("Zahlen (18.11.26)", "Numbers (11/18/26)")]
        currentIndex: form.cfg_dateFormat
        onActivated: index => form.cfg_dateFormat = index
    }

    // ---- Background ----
    Kirigami.Separator {
        Kirigami.FormData.isSection: true
        Kirigami.FormData.label: form.tr("Hintergrund", "Background")
    }
    QQC2.ComboBox {
        Kirigami.FormData.label: form.tr("Hintergrund:", "Background:")
        model: [form.tr("Hintergrundbild", "Wallpaper"), form.tr("Weichgezeichnetes Hintergrundbild", "Blurred wallpaper"), form.tr("Farbe", "Colour")]
        currentIndex: form.cfg_backgroundMode
        onActivated: index => form.cfg_backgroundMode = index
    }
    QQC2.CheckBox {
        enabled: form.cfg_backgroundMode === 0
        text: form.tr("Beim Entsperren weichzeichnen", "Blur while unlocking")
        checked: form.cfg_blurOnPrompt
        onToggled: form.cfg_blurOnPrompt = checked
    }
    RowLayout {
        Kirigami.FormData.label: form.tr("Weichzeichnung:", "Blur strength:")
        enabled: form.cfg_backgroundMode === 1 || (form.cfg_backgroundMode === 0 && form.cfg_blurOnPrompt)
        QQC2.Slider {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            from: 0; to: 100; stepSize: 5
            value: form.cfg_blurStrength
            onMoved: form.cfg_blurStrength = value
        }
        QQC2.Label { text: form.cfg_blurStrength + " %" }
    }
    RowLayout {
        Kirigami.FormData.label: form.tr("Abdunkeln:", "Darken:")
        QQC2.Slider {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            from: 0; to: 80; stepSize: 2
            value: form.cfg_dimming
            onMoved: form.cfg_dimming = value
        }
        QQC2.Label { text: form.cfg_dimming + " %" }
    }
    RowLayout {
        Kirigami.FormData.label: form.tr("Farbe:", "Colour:")
        enabled: form.cfg_backgroundMode === 2
        spacing: Kirigami.Units.smallSpacing
        Repeater {
            // Mac-like dark and soft colours.
            model: ["#1c1c1e", "#2c2c2e", "#1d2b53", "#3f4ab8", "#5b3a8e", "#1f4d3a", "#8a3b3b", "#c7c7cc"]
            delegate: QQC2.AbstractButton {
                required property string modelData
                implicitWidth: Kirigami.Units.gridUnit * 1.4
                implicitHeight: implicitWidth
                onClicked: form.cfg_backgroundColor = modelData
                QQC2.ToolTip.text: modelData
                QQC2.ToolTip.visible: hovered
                background: Rectangle {
                    radius: width / 2
                    color: parent.modelData
                    border.width: form.cfg_backgroundColor.toLowerCase() === parent.modelData ? 3 : 1
                    border.color: form.cfg_backgroundColor.toLowerCase() === parent.modelData
                                  ? Kirigami.Theme.highlightColor : Qt.rgba(0, 0, 0, 0.2)
                }
            }
        }
    }

    // ---- Widgets ----
    Kirigami.Separator {
        Kirigami.FormData.isSection: true
        Kirigami.FormData.label: form.tr("Widgets", "Widgets")
    }
    QQC2.CheckBox {
        Kirigami.FormData.label: form.tr("Anzeigen:", "Show:")
        text: form.tr("Wiedergabe (Musik und Videos steuern)", "Now playing (control music and videos)")
        checked: form.cfg_showMediaControls
        onToggled: form.cfg_showMediaControls = checked
    }
    QQC2.CheckBox {
        text: form.tr("Akku", "Battery")
        checked: form.cfg_showBattery
        onToggled: form.cfg_showBattery = checked
    }
    QQC2.CheckBox {
        text: form.tr("Tastaturbelegung", "Keyboard layout")
        checked: form.cfg_showKeyboardLayout
        onToggled: form.cfg_showKeyboardLayout = checked
    }
    QQC2.CheckBox {
        text: form.tr("Uhr und Widgets erst nach Tastendruck zeigen", "Show clock and widgets only after a key press")
        checked: form.cfg_hideWhenIdle
        onToggled: form.cfg_hideWhenIdle = checked
    }
    QQC2.TextField {
        Kirigami.FormData.label: form.tr("Mitteilung:", "Message:")
        Layout.preferredWidth: Kirigami.Units.gridUnit * 18
        placeholderText: form.tr("z. B. „Gefunden? Bitte melden unter …“", "e.g. \"Found this? Please call …\"")
        text: form.cfg_message
        onTextEdited: form.cfg_message = text
    }

    // ---- User ----
    Kirigami.Separator {
        Kirigami.FormData.isSection: true
        Kirigami.FormData.label: form.tr("Benutzer", "User")
    }
    QQC2.CheckBox {
        Kirigami.FormData.label: form.tr("Anzeigen:", "Show:")
        text: form.tr("Benutzerbild", "User picture")
        checked: form.cfg_showAvatar
        onToggled: form.cfg_showAvatar = checked
    }
    QQC2.ComboBox {
        enabled: form.cfg_showAvatar
        model: [form.tr("Normale Größe", "Normal size"), form.tr("Groß", "Large")]
        currentIndex: form.cfg_avatarSize
        onActivated: index => form.cfg_avatarSize = index
    }
    QQC2.CheckBox {
        text: form.tr("Name", "Name")
        checked: form.cfg_showUserName
        onToggled: form.cfg_showUserName = checked
    }
    QQC2.CheckBox {
        text: form.tr("Knöpfe für Ruhezustand und Benutzerwechsel", "Sleep and switch user buttons")
        checked: form.cfg_showPowerButtons
        onToggled: form.cfg_showPowerButtons = checked
    }
}
