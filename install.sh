#!/usr/bin/env bash
#
# Hue Desk installer. Everything goes under your home directory; nothing
# needs root, and nothing is written outside ~/.local.
#
set -euo pipefail

APPLET_ID="com.rvlak.huedesk"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PLASMOID_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/plasma/plasmoids/$APPLET_ID"
APP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/huedesk"
BIN_DIR="$HOME/.local/bin"
DESKTOP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"

say()  { printf '\033[1;33m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
die()  { printf '\033[31mError:\033[0m %s\n' "$*" >&2; exit 1; }

say "Checking what you have"

command -v curl >/dev/null || die "curl is required. Install it and run this again."
ok "curl"

if command -v plasmashell >/dev/null; then
    PLASMA_VER="$(plasmashell --version 2>/dev/null | grep -oE '[0-9]+' | head -1 || echo 0)"
    [ "${PLASMA_VER:-0}" -ge 6 ] || die "Hue Desk needs KDE Plasma 6 (found $PLASMA_VER)."
    ok "KDE Plasma $PLASMA_VER"
else
    die "plasmashell was not found. Hue Desk is a KDE Plasma 6 widget."
fi

HAVE_PYSIDE=no
if python3 -c "import PySide6" 2>/dev/null; then
    HAVE_PYSIDE=yes
    ok "PySide6 (settings app will be installed)"
else
    warn "PySide6 not found - the widget will work, but the settings app needs it."
    warn "  Fedora/Bazzite: sudo dnf install python3-pyside6"
    warn "  Arch:           sudo pacman -S pyside6"
    warn "  Debian/Ubuntu:  sudo apt install python3-pyside6"
fi

say "Installing the widget"
mkdir -p "$(dirname "$PLASMOID_DIR")"
rm -rf "$PLASMOID_DIR"
cp -r "$SRC/package" "$PLASMOID_DIR"
ok "$PLASMOID_DIR"

if [ "$HAVE_PYSIDE" = yes ]; then
    say "Installing the settings app"
    rm -rf "$APP_DIR"
    mkdir -p "$APP_DIR"
    cp -r "$SRC/settings-app/"* "$APP_DIR/"
    mkdir -p "$BIN_DIR"
    cat > "$BIN_DIR/huedesk-settings" <<LAUNCH
#!/usr/bin/env bash
exec python3 "$APP_DIR/huedesk_settings.py" "\$@"
LAUNCH
    chmod +x "$BIN_DIR/huedesk-settings"
    ok "$BIN_DIR/huedesk-settings"

    mkdir -p "$DESKTOP_DIR"
    cat > "$DESKTOP_DIR/com.rvlak.huedesk.settings.desktop" <<DESK
[Desktop Entry]
Type=Application
Name=Hue Desk Settings
GenericName=Hue Desk widget configuration
Comment=Change how the Hue Desk desktop widget looks and behaves
Exec=$BIN_DIR/huedesk-settings
Icon=$PLASMOID_DIR/contents/icons/bulb.svg
Terminal=false
Categories=Settings;DesktopSettings;Qt;KDE;
Keywords=hue;huedesk;philips;light;widget;
DESK
    ok "$DESKTOP_DIR/com.rvlak.huedesk.settings.desktop"
    update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true

    case ":$PATH:" in
        *":$BIN_DIR:"*) ;;
        *) warn "$BIN_DIR is not on your PATH; launch it from your app menu instead." ;;
    esac
fi

say "Loading it into Plasma"
if kquitapp6 plasmashell >/dev/null 2>&1; then
    for _ in $(seq 1 40); do
        pgrep -x plasmashell >/dev/null || break
        sleep 0.25
    done
    (kstart plasmashell >/dev/null 2>&1 &) || true
    ok "restarted plasmashell so the widget appears"
else
    warn "Could not restart plasmashell. Log out and in, or run:"
    warn "  kquitapp6 plasmashell && kstart plasmashell"
fi

cat <<DONE

Installed.

  1. Right-click your desktop and choose "Add Widgets…"
  2. Search for "Hue Desk" and drag it onto the desktop
  3. Press the round button on your Hue bridge, then choose "Pair"

DONE
if [ "$HAVE_PYSIDE" = yes ]; then
    echo "  Settings: launch \"Hue Desk Settings\" from your app menu."
    echo
fi
