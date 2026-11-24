// System Settings > Dock (DECISIONS.md D27). The values live in kcm.cpp.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    readonly property bool german: Qt.locale().name.startsWith("de")
    function tr(de, en) { return german ? de : en }

    Kirigami.PlaceholderMessage {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.gridUnit * 4
        visible: !kcm.dockFound
        icon.name: "preferences-desktop-panel"
        text: page.tr("Kein Kestrel-Dock gefunden", "No Kestrel Dock found")
        explanation: page.tr("Die Einstellungen gelten für das Dock unten auf dem Bildschirm.",
                             "These settings apply to the dock at the bottom of the screen.")
    }

    Kirigami.FormLayout {
        visible: kcm.dockFound

        RowLayout {
            Kirigami.FormData.label: page.tr("Größe:", "Size:")
            QQC2.Label { text: page.tr("Klein", "Small") }
            QQC2.Slider {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 14
                from: kcm.iconMin
                to: kcm.iconMax
                stepSize: 4
                snapMode: QQC2.Slider.SnapAlways
                value: kcm.iconSize
                onMoved: kcm.iconSize = value
            }
            QQC2.Label { text: page.tr("Groß", "Large") }
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            Kirigami.FormData.label: page.tr("Vergrößerung:", "Magnification:")
            text: page.tr("Symbole unter dem Mauszeiger vergrößern", "Magnify icons under the pointer")
            checked: kcm.magnify
            onToggled: kcm.magnify = checked
        }
        RowLayout {
            enabled: kcm.magnify
            QQC2.Label { text: page.tr("Wenig", "Less") }
            QQC2.Slider {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 14
                from: 1.2
                to: kcm.zoomMax
                stepSize: 0.05
                value: kcm.zoom
                onMoved: kcm.zoom = value
            }
            QQC2.Label { text: page.tr("Stark", "More") }
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.ComboBox {
            Kirigami.FormData.label: page.tr("Ausblenden:", "Hide:")
            model: [page.tr("Nur bei Vollbild-Apps", "Only for full-screen apps"),
                    page.tr("Wenn ein Fenster das Dock berührt", "When a window touches the dock"),
                    page.tr("Immer automatisch ausblenden", "Always hide automatically")]
            currentIndex: kcm.hiding
            onActivated: index => kcm.hiding = index
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: [page.tr("Das Dock bleibt sichtbar. Maximierte Fenster reichen bis an das Dock, nur Spiele und Videos im Vollbild verdecken es.",
                           "The dock stays visible. Maximized windows reach down to the dock; only full-screen games and videos cover it."),
                   page.tr("Das Dock verschwindet, sobald ein Fenster es berührt, und kommt zurück, wenn der Mauszeiger an den unteren Rand geht.",
                           "The dock disappears as soon as a window touches it and comes back when the pointer reaches the bottom edge."),
                   page.tr("Das Dock erscheint nur, wenn der Mauszeiger an den unteren Rand geht.",
                           "The dock appears only when the pointer reaches the bottom edge.")][kcm.hiding]
        }
        QQC2.CheckBox {
            Kirigami.FormData.label: page.tr("Fenster:", "Windows:")
            text: page.tr("Dock über Fenstern schweben lassen", "Let the dock float over windows")
            // Only meaningful while the dock always shows; the other choices hide it anyway.
            enabled: kcm.hiding === 0
            checked: kcm.overWindows
            onToggled: kcm.overWindows = checked
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            visible: kcm.hiding === 0
            text: page.tr("Maximierte Fenster nutzen die ganze Bildschirmhöhe, das Dock liegt über ihnen. Ohne Haken enden sie über dem Dock, wie auf dem Mac.",
                          "Maximized windows use the full screen height and the dock sits on top of them. Unchecked, they end above the dock, like on the Mac.")
        }
        QQC2.CheckBox {
            Kirigami.FormData.label: page.tr("Anzeigen:", "Show:")
            text: page.tr("Punkte unter geöffneten Apps", "Dots under open apps")
            checked: kcm.showIndicators
            onToggled: kcm.showIndicators = checked
        }
    }
}
