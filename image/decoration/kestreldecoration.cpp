/*
    Kestrel OS window decoration (DECISIONS.md D26). See kestreldecoration.h.

    SPDX-License-Identifier: GPL-2.0-or-later
*/
#include "kestreldecoration.h"

#include <KDecoration3/DecoratedWindow>
#include <KDecoration3/DecorationSettings>
#include <KDecoration3/DecorationShadow>
#include <KDecoration3/ScaleHelpers>
#include <KPluginFactory>

#include <QPainter>
#include <QPainterPath>
#include <QPalette>
#include <QTimer>

#include <algorithm>
#include <cmath>
#include <vector>

K_PLUGIN_FACTORY_WITH_JSON(KestrelDecorationFactory, "kestrel.json", registerPlugin<Kestrel::Decoration>(); registerPlugin<Kestrel::Button>();)

namespace Kestrel
{
using KDecoration3::DecorationButtonType;

// Geometry in logical pixels (same as the earlier Aurorae theme, DECISIONS.md D15).
static constexpr qreal TitleHeight = 30;
static constexpr qreal CornerRadius = 10;
static constexpr qreal ButtonDiameter = 13;
static constexpr qreal ButtonWidth = 20;   // circle plus the gap to the next one
static constexpr qreal ButtonSideMargin = 9;
static constexpr qreal ResizeBorder = 6;

// Light and dark colours (DECISIONS.md D20).
struct Palette {
    QColor title, titleInactive, text, textInactive, buttonInactive, buttonInactiveBorder, outline;
    qreal outlineOpacity, shadowOpacity, shadowOpacityInactive;
};
static const Palette LightPalette{QColor(0xf3, 0xf3, 0xf5), QColor(0xf7, 0xf7, 0xf8), QColor(58, 58, 60), QColor(160, 160, 164),
                                  QColor(0xdc, 0xdc, 0xde), QColor(0xc9, 0xc9, 0xcc), QColor(0, 0, 0), 0.16, 0.30, 0.15};
static const Palette DarkPalette{QColor(0x2c, 0x2b, 0x30), QColor(0x30, 0x2f, 0x34), QColor(230, 230, 232), QColor(140, 140, 146),
                                 QColor(0x4a, 0x4a, 0x4f), QColor(0x3e, 0x3e, 0x43), QColor(255, 255, 255), 0.16, 0.55, 0.30};

struct TrafficLight {
    QColor fill, border;
};
static TrafficLight trafficLight(DecorationButtonType type)
{
    switch (type) {
    case DecorationButtonType::Close:
        return {QColor(0xff, 0x5f, 0x57), QColor(0xe2, 0x46, 0x3f)};
    case DecorationButtonType::Minimize:
        return {QColor(0xfe, 0xbc, 0x2e), QColor(0xde, 0x9f, 0x1f)};
    case DecorationButtonType::Maximize:
        return {QColor(0x28, 0xc8, 0x40), QColor(0x1a, 0xa5, 0x2c)};
    default:
        return {QColor(0xa0, 0xa0, 0xa6), QColor(0x8a, 0x8a, 0x90)};
    }
}

// --------------------------------------------------------------------------------------
// Shadow: two soft layers like macOS (a wide ambient one and a tight contact one), blurred
// with three box blurs (close to a Gaussian). KWin stretches the image along the edges.

static void boxBlurAlpha(std::vector<float> &a, int w, int h, int r)
{
    if (r < 1) {
        return;
    }
    std::vector<float> tmp(a.size());
    const float norm = 1.0f / (2 * r + 1);
    for (int y = 0; y < h; ++y) { // horizontal
        float sum = 0;
        for (int x = -r; x <= r; ++x) {
            sum += a[y * w + std::clamp(x, 0, w - 1)];
        }
        for (int x = 0; x < w; ++x) {
            tmp[y * w + x] = sum * norm;
            sum += a[y * w + std::min(x + r + 1, w - 1)] - a[y * w + std::max(x - r, 0)];
        }
    }
    for (int x = 0; x < w; ++x) { // vertical
        float sum = 0;
        for (int y = -r; y <= r; ++y) {
            sum += tmp[std::clamp(y, 0, h - 1) * w + x];
        }
        for (int y = 0; y < h; ++y) {
            a[y * w + x] = sum * norm;
            sum += tmp[std::min(y + r + 1, h - 1) * w + x] - tmp[std::max(y - r, 0) * w + x];
        }
    }
}

static std::shared_ptr<KDecoration3::DecorationShadow> createShadow(qreal strength)
{
    struct Layer {
        int blur;
        qreal offsetY, opacity;
    };
    const Layer layers[] = {{26, 12, 0.85}, {4, 1, 0.35}};

    const int pad = 3 * 26 + 12;                                          // room for the widest layer
    const int box = int(2 * (CornerRadius + 3 * 26));                     // corners never reach the stretched middle
    const int size = box + 2 * pad;
    std::vector<float> total(size * size, 0.0f);

    for (const Layer &layer : layers) {
        QImage shape(size, size, QImage::Format_ARGB32_Premultiplied);
        shape.fill(Qt::transparent);
        QPainter p(&shape);
        p.setRenderHint(QPainter::Antialiasing);
        p.setPen(Qt::NoPen);
        p.setBrush(Qt::black);
        p.drawRoundedRect(QRectF(pad, pad + layer.offsetY, box, box), CornerRadius, CornerRadius);
        p.end();
        std::vector<float> a(size * size);
        for (int y = 0; y < size; ++y) {
            const QRgb *line = reinterpret_cast<const QRgb *>(shape.constScanLine(y));
            for (int x = 0; x < size; ++x) {
                a[y * size + x] = qAlpha(line[x]) / 255.0f;
            }
        }
        const int r = std::max(1, layer.blur / 3);
        for (int i = 0; i < 3; ++i) {
            boxBlurAlpha(a, size, size, r);
        }
        for (size_t i = 0; i < a.size(); ++i) {
            total[i] += a[i] * layer.opacity * strength;
        }
    }

    QImage image(size, size, QImage::Format_ARGB32_Premultiplied);
    for (int y = 0; y < size; ++y) {
        QRgb *line = reinterpret_cast<QRgb *>(image.scanLine(y));
        for (int x = 0; x < size; ++x) {
            const int alpha = std::clamp(int(std::lround(total[y * size + x] * 255.0f)), 0, 255);
            line[x] = qRgba(0, 0, 0, alpha);
        }
    }

    // No shadow under the window itself (it would show through translucent windows).
    QPainter p(&image);
    p.setRenderHint(QPainter::Antialiasing);
    p.setPen(Qt::NoPen);
    p.setBrush(Qt::black);
    p.setCompositionMode(QPainter::CompositionMode_DestinationOut);
    p.drawRoundedRect(QRectF(pad + 1, pad + 1, box - 2, box - 2), CornerRadius - 1, CornerRadius - 1);
    p.end();

    auto shadow = std::make_shared<KDecoration3::DecorationShadow>();
    shadow->setPadding(QMarginsF(pad, pad, pad, pad));
    shadow->setInnerShadowRect(QRectF(size / 2.0, size / 2.0, 1, 1));
    shadow->setShadow(image);
    return shadow;
}

// --------------------------------------------------------------------------------------

Decoration::Decoration(QObject *parent, const QVariantList &args)
    : KDecoration3::Decoration(parent, args)
{
}

bool Decoration::isDark() const
{
    return window()->palette().color(QPalette::Window).lightness() < 128;
}

QColor Decoration::titleBarColor() const
{
    const Palette &pal = isDark() ? DarkPalette : LightPalette;
    return window()->isActive() ? pal.title : pal.titleInactive;
}

QColor Decoration::titleTextColor() const
{
    const Palette &pal = isDark() ? DarkPalette : LightPalette;
    return window()->isActive() ? pal.text : pal.textInactive;
}

bool Decoration::isTiled() const
{
    return window()->adjacentScreenEdges() != Qt::Edges() || window()->isMaximized();
}

bool Decoration::init()
{
    auto w = window();
    auto s = settings();

    m_leftButtons = new KDecoration3::DecorationButtonGroup(KDecoration3::DecorationButtonGroup::Position::Left, this, &Button::create);
    m_rightButtons = new KDecoration3::DecorationButtonGroup(KDecoration3::DecorationButtonGroup::Position::Right, this, &Button::create);

    auto relayout = [this]() {
        updateLayout();
    };
    connect(w, &KDecoration3::DecoratedWindow::maximizedChanged, this, relayout);
    connect(w, &KDecoration3::DecoratedWindow::adjacentScreenEdgesChanged, this, relayout);
    connect(w, &KDecoration3::DecoratedWindow::shadedChanged, this, relayout);
    connect(w, &KDecoration3::DecoratedWindow::widthChanged, this, &Decoration::updateButtonsGeometry);
    connect(w, &KDecoration3::DecoratedWindow::nextScaleChanged, this, relayout);
    connect(w, &KDecoration3::DecoratedWindow::activeChanged, this, [this]() {
        updateLayout(); // outline colour
        updateShadow();
        update();
    });
    connect(w, &KDecoration3::DecoratedWindow::paletteChanged, this, [this]() {
        updateLayout();
        updateShadow();
        update();
    });
    connect(w, &KDecoration3::DecoratedWindow::captionChanged, this, [this]() {
        update(titleBar());
    });
    connect(s.get(), &KDecoration3::DecorationSettings::reconfigured, this, relayout);
    connect(s.get(), &KDecoration3::DecorationSettings::fontChanged, this, relayout);
    connect(s.get(), &KDecoration3::DecorationSettings::decorationButtonsLeftChanged, this, [this]() {
        QTimer::singleShot(0, this, &Decoration::updateButtonsGeometry);
    });
    connect(s.get(), &KDecoration3::DecorationSettings::decorationButtonsRightChanged, this, [this]() {
        QTimer::singleShot(0, this, &Decoration::updateButtonsGeometry);
    });

    updateLayout();
    updateShadow();
    return true;
}

void Decoration::updateLayout()
{
    const qreal scale = window()->nextScale();
    const bool tiled = isTiled();
    const bool maximized = window()->isMaximized();

    setBorders(QMarginsF(0, KDecoration3::snapToPixelGrid(TitleHeight, scale), 0, 0));
    setResizeOnlyBorders(maximized ? QMarginsF() : QMarginsF(ResizeBorder, 4, ResizeBorder, ResizeBorder));
    setTitleBar(QRectF(0, 0, window()->width(), KDecoration3::snapToPixelGrid(TitleHeight, scale)));
    setOpaque(maximized);

    // Real rounded corners: KWin clips the whole window (title bar and content) to this.
    const qreal radius = (tiled || !settings()->isAlphaChannelSupported()) ? 0 : KDecoration3::snapToPixelGrid(CornerRadius, scale);
    setBorderRadius(KDecoration3::BorderRadius(radius));

    // A hairline around the window, light on dark windows and dark on light ones, like macOS.
    if (maximized) {
        setBorderOutline(KDecoration3::BorderOutline());
    } else {
        const Palette &pal = isDark() ? DarkPalette : LightPalette;
        QColor color = pal.outline;
        color.setAlphaF(pal.outlineOpacity * (window()->isActive() ? 1.0 : 0.7));
        setBorderOutline(KDecoration3::BorderOutline(KDecoration3::pixelSize(scale), color, KDecoration3::BorderRadius(radius)));
    }

    updateButtonsGeometry();
}

void Decoration::updateButtonsGeometry()
{
    const auto buttons = m_leftButtons->buttons() + m_rightButtons->buttons();
    for (KDecoration3::DecorationButton *button : buttons) {
        button->setGeometry(QRectF(0, 0, ButtonWidth, TitleHeight));
    }
    m_leftButtons->setSpacing(0);
    m_rightButtons->setSpacing(0);
    m_leftButtons->setPos(QPointF(ButtonSideMargin, 0));
    m_rightButtons->setPos(QPointF(size().width() - m_rightButtons->geometry().width() - ButtonSideMargin, 0));
    setTitleBar(QRectF(0, 0, window()->width(), borderTop()));
    update();
}

void Decoration::updateShadow()
{
    // Cached per style: building the shadow image is the only expensive step.
    static std::shared_ptr<KDecoration3::DecorationShadow> cache[2][2]; // [dark][active]
    const bool dark = isDark();
    const bool active = window()->isActive();
    auto &shadow = cache[dark][active];
    if (!shadow) {
        const Palette &pal = dark ? DarkPalette : LightPalette;
        shadow = createShadow(active ? pal.shadowOpacity : pal.shadowOpacityInactive);
    }
    setShadow(shadow);
}

void Decoration::updateButtonsHovered()
{
    bool hovered = false;
    const auto buttons = m_leftButtons->buttons() + m_rightButtons->buttons();
    for (KDecoration3::DecorationButton *button : buttons) {
        hovered = hovered || button->isHovered();
    }
    if (hovered != m_buttonsHovered) {
        m_buttonsHovered = hovered;
        update(titleBar());
    }
}

void Decoration::paint(QPainter *painter, const QRectF &repaintArea)
{
    const QRectF bar(0, 0, size().width(), borderTop());
    if (!bar.intersects(repaintArea)) {
        return;
    }

    // KWin rounds the corners (setBorderRadius), so a plain rectangle is enough here.
    painter->fillRect(bar, titleBarColor());

    // Title, centred over the whole window like on macOS; moved aside only if it would
    // run into the buttons.
    painter->setFont(settings()->font());
    painter->setPen(titleTextColor());
    const qreal leftEnd = m_leftButtons->geometry().right() + 8;
    const qreal rightStart = m_rightButtons->buttons().isEmpty() ? bar.width() - 8 : m_rightButtons->geometry().left() - 8;
    const qreal avail = std::max<qreal>(0, rightStart - leftEnd);
    const QString caption = painter->fontMetrics().elidedText(window()->caption(), Qt::ElideMiddle, int(avail));
    const qreal textWidth = painter->fontMetrics().horizontalAdvance(caption);
    qreal x = (bar.width() - textWidth) / 2;
    x = std::clamp(x, leftEnd, std::max(leftEnd, rightStart - textWidth));
    painter->drawText(QRectF(x, 0, textWidth + 1, bar.height()), Qt::AlignVCenter | Qt::AlignLeft | Qt::TextSingleLine, caption);

    m_leftButtons->paint(painter, repaintArea);
    m_rightButtons->paint(painter, repaintArea);
}

// --------------------------------------------------------------------------------------

Button::Button(KDecoration3::DecorationButtonType type, Decoration *decoration, QObject *parent)
    : KDecoration3::DecorationButton(type, decoration, parent)
{
    setGeometry(QRectF(0, 0, ButtonWidth, TitleHeight));
    connect(this, &KDecoration3::DecorationButton::hoveredChanged, decoration, &Decoration::updateButtonsHovered);
}

Button::Button(QObject *parent, const QVariantList &args)
    : Button(args.at(0).value<KDecoration3::DecorationButtonType>(), args.at(1).value<Decoration *>(), parent)
{
}

KDecoration3::DecorationButton *Button::create(KDecoration3::DecorationButtonType type, KDecoration3::Decoration *decoration, QObject *parent)
{
    auto d = qobject_cast<Decoration *>(decoration);
    if (!d) {
        return nullptr;
    }
    switch (type) {
    case DecorationButtonType::Close:
    case DecorationButtonType::Minimize:
    case DecorationButtonType::Maximize:
        break;
    default:
        return nullptr; // only the three traffic lights, as on macOS
    }
    auto b = new Button(type, d, parent);
    auto w = d->window();
    if (type == DecorationButtonType::Close) {
        b->setVisible(w->isCloseable());
        QObject::connect(w, &KDecoration3::DecoratedWindow::closeableChanged, b, &Button::setVisible);
    } else if (type == DecorationButtonType::Minimize) {
        b->setVisible(w->isMinimizeable());
        QObject::connect(w, &KDecoration3::DecoratedWindow::minimizeableChanged, b, &Button::setVisible);
    } else if (type == DecorationButtonType::Maximize) {
        b->setVisible(w->isMaximizeable());
        QObject::connect(w, &KDecoration3::DecoratedWindow::maximizeableChanged, b, &Button::setVisible);
    }
    return b;
}

void Button::paint(QPainter *painter, const QRectF &repaintArea)
{
    Q_UNUSED(repaintArea)
    auto deco = qobject_cast<Decoration *>(decoration());
    if (!deco || !isVisible()) {
        return;
    }
    const bool active = deco->window()->isActive();
    const bool showSymbol = deco->buttonsHovered();
    const Palette &pal = deco->isDark() ? DarkPalette : LightPalette;

    TrafficLight light = trafficLight(type());
    if (!active && !showSymbol) {
        light = {pal.buttonInactive, pal.buttonInactiveBorder};
    }
    if (isPressed()) {
        light.fill = light.fill.darker(120);
        light.border = light.border.darker(120);
    }

    const QRectF g = geometry();
    const QPointF c(g.left() + ButtonDiameter / 2 + 0.5, g.center().y());
    const qreal r = ButtonDiameter / 2;

    painter->save();
    painter->setRenderHint(QPainter::Antialiasing);
    painter->setPen(QPen(light.border, 0.75));
    painter->setBrush(light.fill);
    painter->drawEllipse(c, r - 0.375, r - 0.375);

    if (showSymbol) {
        QPen pen(QColor(0, 0, 0, 140), 1.2);
        pen.setCapStyle(Qt::RoundCap);
        painter->setPen(pen);
        const qreal k = r * 0.42;
        switch (type()) {
        case DecorationButtonType::Close:
            painter->drawLine(c + QPointF(-k, -k), c + QPointF(k, k));
            painter->drawLine(c + QPointF(-k, k), c + QPointF(k, -k));
            break;
        case DecorationButtonType::Minimize:
            painter->drawLine(c + QPointF(-k * 1.2, 0), c + QPointF(k * 1.2, 0));
            break;
        case DecorationButtonType::Maximize: {
            // macOS: two small triangles pointing apart (enter/leave full size).
            painter->setPen(Qt::NoPen);
            painter->setBrush(QColor(0, 0, 0, 140));
            const qreal t = r * 0.55;
            QPainterPath path;
            path.moveTo(c + QPointF(-t, -t * 0.25));
            path.lineTo(c + QPointF(-t, t));
            path.lineTo(c + QPointF(t * 0.25, t));
            path.closeSubpath();
            path.moveTo(c + QPointF(t, t * 0.25));
            path.lineTo(c + QPointF(t, -t));
            path.lineTo(c + QPointF(-t * 0.25, -t));
            path.closeSubpath();
            painter->drawPath(path);
            break;
        }
        default:
            break;
        }
    }
    painter->restore();
}

} // namespace Kestrel

#include "kestreldecoration.moc"
