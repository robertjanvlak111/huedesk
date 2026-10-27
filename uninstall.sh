#!/usr/bin/env bash
#
# Removes everything install.sh created. Your bridge pairing is stored in
# Plasma's own applet config and is removed with the widget.
#
set -euo pipefail

APPLET_ID="com.rvlak.huedesk"
PLASMOID_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/plasma/plasmoids/$APPLET_ID"
APP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/huedesk"
BIN="$HOME/.local/bin/huedesk-settings"
DESKTOP="${XDG_DATA_HOME:-$HOME/.local/share}/applications/com.rvlak.huedesk.settings.desktop"

ok() { printf '  \033[32m✓\033[0m %s\n' "$*"; }

echo "Removing Hue Desk"
for target in "$PLASMOID_DIR" "$APP_DIR" "$BIN" "$DESKTOP"; do
    if [ -e "$target" ]; then
        rm -rf "$target"
        ok "removed $target"
    fi
done

echo
echo "Remove the widget from your desktop by right-clicking it and choosing Remove."
echo "Restart the shell to drop it from the widget list:"
echo "  kquitapp6 plasmashell && kstart plasmashell"
