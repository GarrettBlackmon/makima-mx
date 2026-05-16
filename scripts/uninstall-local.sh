#!/usr/bin/env bash
# Remove the per-user files created by install-local.sh.
# Does NOT touch ~/.config/makima-mx/profiles.json (your saved state).
set -euo pipefail

BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
APPS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
ICON_BASE="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor"

rm -f "$BIN_DIR/makima-mx"
rm -f "$APPS_DIR/makima-mx.desktop"
rm -f "$ICON_BASE/scalable/apps/makima-mx.svg"
rm -f "$ICON_BASE/256x256/apps/makima-mx.png"
rm -f "$ICON_BASE/128x128/apps/makima-mx.png"
rm -f "$ICON_BASE/64x64/apps/makima-mx.png"

command -v update-desktop-database >/dev/null && update-desktop-database "$APPS_DIR" 2>/dev/null || true
command -v gtk-update-icon-cache   >/dev/null && gtk-update-icon-cache -q -t "$ICON_BASE"  2>/dev/null || true

echo "Uninstalled launcher + .desktop + icons."
echo "Your bindings at ~/.config/makima-mx/profiles.json were left alone."
