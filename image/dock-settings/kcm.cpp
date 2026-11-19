/*
    System Settings > Dock (DECISIONS.md D27): settings for the Kestrel Dock.

    The dock is a Plasma widget in a panel. Its settings (icon size, magnification, dots) live
    in the widget's configuration and the behaviour (dodge windows, hide) and the height in the
    panel's. Both are read and written through Plasma's own scripting interface (the same one
    the desktop layout uses), so a change shows on the dock at once.

    SPDX-License-Identifier: GPL-2.0-or-later
*/
#include <KPluginFactory>
#include <KQuickConfigModule>

#include <QDBusConnection>
#include <QDBusMessage>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>

class KestrelDockKcm : public KQuickConfigModule
{
    Q_OBJECT
    Q_PROPERTY(bool dockFound READ dockFound NOTIFY changed)
    Q_PROPERTY(int iconSize READ iconSize WRITE setIconSize NOTIFY changed)
    Q_PROPERTY(bool magnify READ magnify WRITE setMagnify NOTIFY changed)
    Q_PROPERTY(double zoom READ zoom WRITE setZoom NOTIFY changed)
    Q_PROPERTY(bool showIndicators READ showIndicators WRITE setShowIndicators NOTIFY changed)
    // 0 only full-screen apps cover it, 1 dodge windows, 2 auto-hide, 3 windows may go below
    Q_PROPERTY(int hiding READ hiding WRITE setHiding NOTIFY changed)
    Q_PROPERTY(int iconMin MEMBER m_iconMin CONSTANT)
    Q_PROPERTY(int iconMax MEMBER m_iconMax CONSTANT)
    Q_PROPERTY(double zoomMax MEMBER m_zoomMax CONSTANT)

public:
    KestrelDockKcm(QObject *parent, const KPluginMetaData &data)
        : KQuickConfigModule(parent, data)
    {
        setButtons(Apply | Default);
        readGeometry();
    }

    bool dockFound() const { return m_found; }
    int iconSize() const { return m_iconSize; }
    bool magnify() const { return m_magnify; }
    double zoom() const { return m_zoom; }
    bool showIndicators() const { return m_showIndicators; }
    int hiding() const { return m_hiding; }

    void setIconSize(int v) { set(m_iconSize, std::clamp(v, m_iconMin, m_iconMax)); }
    void setMagnify(bool v) { set(m_magnify, v); }
    void setZoom(double v) { set(m_zoom, std::clamp(v, 1.2, m_zoomMax)); }
    void setShowIndicators(bool v) { set(m_showIndicators, v); }
    void setHiding(int v) { set(m_hiding, std::clamp(v, 0, 3)); }

    void load() override
    {
        const QString out = evaluate(QStringLiteral(R"JS(
            var r = { found: false };
            panels().forEach(function (p) {
                p.widgets().forEach(function (w) {
                    if (w.type !== "org.kestrel.dock") return;
                    w.currentConfigGroup = ["General"];
                    r.found = true;
                    r.iconSize = w.readConfig("iconSize", 48);
                    r.magnify = w.readConfig("magnify", true);
                    r.zoom = w.readConfig("zoom", 1.6);
                    r.showIndicators = w.readConfig("showIndicators", true);
                    r.hiding = p.hiding;
                });
            });
            print(JSON.stringify(r));
        )JS"));
        const QJsonObject r = QJsonDocument::fromJson(out.trimmed().toUtf8()).object();
        m_found = r.value(QStringLiteral("found")).toBool();
        m_iconSize = std::clamp(toInt(r.value(QStringLiteral("iconSize")), 48), m_iconMin, m_iconMax);
        m_magnify = toBool(r.value(QStringLiteral("magnify")), true);
        m_zoom = std::clamp(toDouble(r.value(QStringLiteral("zoom")), 1.6), 1.2, m_zoomMax);
        m_showIndicators = toBool(r.value(QStringLiteral("showIndicators")), true);
        const QString hiding = r.value(QStringLiteral("hiding")).toString();
        m_hiding = hiding == QLatin1String("dodgewindows") ? 1
            : hiding == QLatin1String("autohide")       ? 2
            : hiding == QLatin1String("windowsgobelow") ? 3
                                                        : 0;
        Q_EMIT changed();
        setNeedsSave(false);
    }

    void save() override
    {
        static const char *hidingNames[] = {"none", "dodgewindows", "autohide", "windowsgobelow"};
        const int height = m_overflow + m_pad + m_iconSize + m_bottom; // as plasma_theme.py dock_height()
        evaluate(QStringLiteral(R"JS(
            panels().forEach(function (p) {
                var isDock = false;
                p.widgets().forEach(function (w) {
                    if (w.type !== "org.kestrel.dock") return;
                    isDock = true;
                    w.currentConfigGroup = ["General"];
                    w.writeConfig("iconSize", %1);
                    w.writeConfig("magnify", %2);
                    w.writeConfig("zoom", %3);
                    w.writeConfig("showIndicators", %4);
                });
                if (isDock) {
                    p.height = %5;
                    p.hiding = "%6";
                }
            });
        )JS")
                     .arg(m_iconSize)
                     .arg(m_magnify ? QStringLiteral("true") : QStringLiteral("false"))
                     .arg(m_zoom, 0, 'f', 2)
                     .arg(m_showIndicators ? QStringLiteral("true") : QStringLiteral("false"))
                     .arg(height)
                     .arg(QLatin1String(hidingNames[m_hiding])));
        setNeedsSave(false);
    }

    void defaults() override
    {
        m_iconSize = m_defaultIcon;
        m_magnify = true;
        m_zoom = m_defaultZoom;
        m_showIndicators = true;
        m_hiding = 0;
        Q_EMIT changed();
        setNeedsSave(true);
    }

Q_SIGNALS:
    void changed();

private:
    template<typename T>
    void set(T &field, T value)
    {
        if (field != value) {
            field = value;
            Q_EMIT changed();
            setNeedsSave(true);
        }
    }

    static bool toBool(const QJsonValue &v, bool fallback)
    {
        if (v.isBool()) return v.toBool();
        if (v.isString()) return v.toString() == QLatin1String("true");
        return fallback;
    }
    static int toInt(const QJsonValue &v, int fallback)
    {
        if (v.isDouble()) return v.toInt();
        bool ok = false;
        const int i = v.toString().toInt(&ok);
        return ok ? i : fallback;
    }
    static double toDouble(const QJsonValue &v, double fallback)
    {
        if (v.isDouble()) return v.toDouble();
        bool ok = false;
        const double d = v.toString().toDouble(&ok);
        return ok ? d : fallback;
    }

    // The dock's geometry is generated from image/artwork/plasma_theme.py (single source).
    void readGeometry()
    {
        QFile f(QStringLiteral("/usr/share/plasma/plasmoids/org.kestrel.dock/contents/ui/geometry.js"));
        if (!f.open(QIODevice::ReadOnly)) return;
        const QString js = QString::fromUtf8(f.readAll());
        auto value = [&js](const char *name, double fallback) {
            const auto m = QRegularExpression(QStringLiteral("var %1 = ([0-9.]+);").arg(QLatin1String(name))).match(js);
            return m.hasMatch() ? m.captured(1).toDouble() : fallback;
        };
        m_overflow = int(value("overflow", m_overflow));
        m_pad = int(value("pad", m_pad));
        m_bottom = int(value("bottom", m_bottom));
        m_iconMin = int(value("iconMin", m_iconMin));
        m_iconMax = int(value("iconMax", m_iconMax));
        m_zoomMax = value("zoomMax", m_zoomMax);
        m_defaultIcon = int(value("icon", m_defaultIcon));
        m_defaultZoom = value("zoom", m_defaultZoom);
    }

    static QString evaluate(const QString &script)
    {
        QDBusMessage msg = QDBusMessage::createMethodCall(QStringLiteral("org.kde.plasmashell"), QStringLiteral("/PlasmaShell"),
                                                          QStringLiteral("org.kde.PlasmaShell"), QStringLiteral("evaluateScript"));
        msg << script;
        const QDBusMessage reply = QDBusConnection::sessionBus().call(msg, QDBus::Block, 10000);
        return reply.arguments().isEmpty() ? QString() : reply.arguments().constFirst().toString();
    }

    bool m_found = false;
    int m_iconSize = 48;
    bool m_magnify = true;
    double m_zoom = 1.6;
    bool m_showIndicators = true;
    int m_hiding = 0;
    int m_overflow = 90, m_pad = 6, m_bottom = 10, m_iconMin = 32, m_iconMax = 72, m_defaultIcon = 48;
    double m_zoomMax = 1.8, m_defaultZoom = 1.6;
};

K_PLUGIN_CLASS_WITH_JSON(KestrelDockKcm, "kcm_kestreldock.json")

#include "kcm.moc"
