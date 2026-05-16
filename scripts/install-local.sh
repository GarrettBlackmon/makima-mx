#!/usr/bin/env bash
# Per-user install for makima-mx. Creates:
#   ~/.local/bin/makima-mx          - launcher pointing at this repo
#   ~/.local/share/applications/makima-mx.desktop
#   ~/.local/share/icons/hicolor/{scalable,256x256,128x128,64x64}/apps/makima-mx.{svg,png}
#
# Idempotent. Re-run after pulling updates.
#
# Uninstall: scripts/uninstall-local.sh
set -euo pipefail

# Resolve repo root (parent of scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
APPS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
ICON_BASE="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor"

mkdir -p "$BIN_DIR" "$APPS_DIR" \
  "$ICON_BASE/scalable/apps" \
  "$ICON_BASE/256x256/apps" \
  "$ICON_BASE/128x128/apps" \
  "$ICON_BASE/64x64/apps"

# 1. launcher
cat > "$BIN_DIR/makima-mx" <<EOF
#!/usr/bin/env bash
exec quickshell -p "$REPO_ROOT/shell.qml" "\$@"
EOF
chmod +x "$BIN_DIR/makima-mx"

# 2. .desktop
cat > "$APPS_DIR/makima-mx.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=makima-mx
GenericName=Mouse Remapper
Comment=Visual remapper for Logitech MX Master 3/3S buttons
Exec=makima-mx
Icon=makima-mx
Terminal=false
Categories=Settings;HardwareSettings;Utility;
Keywords=mouse;remap;makima;logitech;mx master;binding;
StartupNotify=true
EOF

# 3. icons (SVG + PNG sizes for theme fallback)
install -m644 "$REPO_ROOT/assets/icon.svg"     "$ICON_BASE/scalable/apps/makima-mx.svg"
install -m644 "$REPO_ROOT/assets/icon-256.png" "$ICON_BASE/256x256/apps/makima-mx.png"
install -m644 "$REPO_ROOT/assets/icon-128.png" "$ICON_BASE/128x128/apps/makima-mx.png"
install -m644 "$REPO_ROOT/assets/icon-64.png"  "$ICON_BASE/64x64/apps/makima-mx.png"

# 4. refresh caches (best-effort)
command -v update-desktop-database >/dev/null && update-desktop-database "$APPS_DIR" 2>/dev/null || true
command -v gtk-update-icon-cache   >/dev/null && gtk-update-icon-cache -q -t "$ICON_BASE"  2>/dev/null || true

echo "Installed:"
echo "  launcher  $BIN_DIR/makima-mx"
echo "  .desktop  $APPS_DIR/makima-mx.desktop"
echo "  icons     $ICON_BASE/{scalable,256x256,128x128,64x64}/apps/makima-mx.{svg,png}"
echo
echo "If ~/.local/bin is not in PATH, add it (or copy/symlink the launcher to /usr/local/bin)."
