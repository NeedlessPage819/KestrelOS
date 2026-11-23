/*
    Kestrel lock screen clock (DECISIONS.md D23): the date in a small line above a large
    time, like the Mac. Style, weight, 12/24 hours, seconds and the date format can be set.

    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: clock

    property real screenHeight: 800
    property date now: new Date()

    // clockStyle: 0 large, 1 small, 2 hidden
    readonly property int style: config.clockStyle
    readonly property var weights: [Font.Light, Font.Normal, Font.DemiBold, Font.Bold]

    // 12 hours when chosen, or (automatic) when the language uses them, as in English.
    readonly property bool twelveHours: config.timeFormat === 2 ||
        (config.timeFormat === 0 && /a/i.test(Qt.locale().timeFormat(Locale.ShortFormat).replace(/'[^']*'/g, "")))

    // The time like the Mac's lock screen: "6:03" in 12-hour languages, without AM/PM. In Qt, "h"
    // only counts to 12 when the format also has AM/PM, so the time is formatted with it and the
    // AM/PM text removed afterwards (removing it from the format gave "18:03p").
    function timeText(d) {
        const secs = config.showSeconds ? ":ss" : "";
        if (!twelveHours) return Qt.locale().toString(d, "H:mm" + secs);
        let s = Qt.locale().toString(d, "h:mm" + secs + " AP");
        for (const t of [Qt.locale().amText, Qt.locale().pmText, "AM", "PM"]) if (t) s = s.replace(t, "");
        return s.trim();
    }

    function dateText() {
        // The long format without the year: "Mittwoch, 18. November" / "Wednesday, November 18".
        const long = Qt.locale().dateFormat(Locale.LongFormat).replace(/[,.]?\s*y+[.,]?/, "").trim();
        switch (config.dateFormat) {
        case 1: return Qt.locale().toString(now, long.replace("dddd", "ddd").replace("MMMM", "MMM"));
        case 2: return Qt.locale().toString(now, Locale.ShortFormat);
        default: return Qt.locale().toString(now, long);
        }
    }

    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: clock.now = new Date()
    }

    ColumnLayout {
        id: column
        anchors.centerIn: parent
        spacing: 0

        Text {
            Layout.alignment: Qt.AlignHCenter
            visible: config.showDate
            text: clock.dateText()
            renderType: Text.CurveRendering
            color: "white"
            opacity: 0.92
            font.family: "Inter"
            font.weight: Font.DemiBold
            font.pixelSize: Math.round(clock.screenHeight * (clock.style === 0 ? 0.027 : 0.022))
        }

        Text {
            id: time
            renderType: Text.CurveRendering   // crisp large digits, no colour fringes
            Layout.alignment: Qt.AlignHCenter
            visible: clock.style !== 2
            text: clock.timeText(clock.now)
            color: "white"
            opacity: 0.94
            font.family: "Inter"
            font.weight: clock.weights[Math.max(0, Math.min(3, config.clockWeight))]
            font.pixelSize: Math.round(clock.screenHeight * (clock.style === 0 ? 0.15 : 0.075))
            font.letterSpacing: -Math.round(clock.screenHeight * (clock.style === 0 ? 0.15 : 0.075)) * 0.02
            font.features: { "tnum": 1 }   // digits of equal width, so the time does not wobble
            // Tight line box: the large digits otherwise leave a big gap under the date.
            lineHeight: 0.92
        }
    }

    // A very soft shadow keeps the white text readable on light wallpapers.
    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Qt.rgba(0, 0, 0, 0.35)
        shadowBlur: 0.6
        shadowVerticalOffset: 1
    }
}
