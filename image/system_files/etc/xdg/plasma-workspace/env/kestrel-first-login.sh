# Kestrel OS (DECISIONS.md D23): Plasma Setup's light/dark switch applies Fedora's own
# look-and-feel (a Fedora patch) and copies the result to the new user. On that user's
# first login, before Plasma builds the desktop, switch to the matching Kestrel package so
# the user gets the Kestrel dock, top bar and theme. Later logins are left alone, so a
# look the user picks themselves stays.
_kestrel_cfg=${XDG_CONFIG_HOME:-$HOME/.config}
if [ ! -e "$_kestrel_cfg/plasma-org.kde.plasma.desktop-appletsrc" ] && [ -f "$_kestrel_cfg/kdeglobals" ]; then
    case $(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage 2>/dev/null) in
        org.fedoraproject.fedoradark.desktop|org.kde.breezedark.desktop)
            QT_QPA_PLATFORM=offscreen plasma-apply-lookandfeel --apply org.kestrel.desktop.dark >/dev/null 2>&1 ;;
        org.fedoraproject.fedora.desktop|org.fedoraproject.fedoralight.desktop|org.kde.breeze.desktop)
            QT_QPA_PLATFORM=offscreen plasma-apply-lookandfeel --apply org.kestrel.desktop >/dev/null 2>&1 ;;
    esac
fi
unset _kestrel_cfg
