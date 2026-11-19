/*
    Kestrel OS window decoration (DECISIONS.md D26).

    A small KDecoration3 plugin: macOS-style title bar with traffic-light buttons, a soft
    shadow and real rounded corners. The corners are rounded by KWin itself
    (setBorderRadius), which clips the whole window, the application's content included,
    instead of only drawing rounded shapes on the title bar.

    SPDX-License-Identifier: GPL-2.0-or-later
*/
#pragma once

#include <KDecoration3/Decoration>
#include <KDecoration3/DecorationButton>
#include <KDecoration3/DecorationButtonGroup>

#include <QVariantList>

namespace Kestrel
{

class Decoration : public KDecoration3::Decoration
{
    Q_OBJECT

public:
    explicit Decoration(QObject *parent = nullptr, const QVariantList &args = QVariantList());

    bool init() override;
    void paint(QPainter *painter, const QRectF &repaintArea) override;

    // Colours follow the window's colour scheme (light "Kestrel" or dark "Kestrel Dark").
    bool isDark() const;
    QColor titleBarColor() const;
    QColor titleTextColor() const;

    // macOS shows the symbols on all three buttons while the pointer is over any of them.
    bool buttonsHovered() const { return m_buttonsHovered; }
    void updateButtonsHovered();

private:
    void updateLayout();
    void updateButtonsGeometry();
    void updateShadow();
    bool isTiled() const;

    KDecoration3::DecorationButtonGroup *m_leftButtons = nullptr;
    KDecoration3::DecorationButtonGroup *m_rightButtons = nullptr;
    bool m_buttonsHovered = false;
};

class Button : public KDecoration3::DecorationButton
{
    Q_OBJECT

public:
    // Used by KWin's decoration settings page to preview single buttons.
    explicit Button(QObject *parent, const QVariantList &args);
    Button(KDecoration3::DecorationButtonType type, Decoration *decoration, QObject *parent = nullptr);

    static KDecoration3::DecorationButton *create(KDecoration3::DecorationButtonType type, KDecoration3::Decoration *decoration, QObject *parent);

    void paint(QPainter *painter, const QRectF &repaintArea) override;
};

} // namespace Kestrel
