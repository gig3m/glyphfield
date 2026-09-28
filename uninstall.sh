#!/bin/bash
#
# Undo install.sh: give Omarchy its stock idle service back and remove
# glyphfield's commands and hook. Your settings in ~/.config/glyphfield are
# left alone.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
PLUGIN_DIR="$HOME/.config/omarchy/plugins"

echo "Restoring the stock idle service..."
for c in "$PLUGIN_DIR"/*.idle; do
  [[ -f $c/manifest.json ]] || continue
  grep -q '"clonedFrom": *"omarchy.idle"' "$c/manifest.json" || continue
  grep -q glyphfield-launch-screensaver "$c/Service.qml" 2>/dev/null || continue
  omarchy plugin enable omarchy.idle >/dev/null 2>&1 || true
  omarchy plugin disable "$(basename "$c")" >/dev/null 2>&1 || true
  echo "  disabled $(basename "$c"), re-enabled omarchy.idle"
  echo "  (the clone is left at $c; delete it if you like)"
done

echo "Removing the post-update hook..."
rm -f "$HOME/.config/omarchy/hooks/post-update.d/glyphfield-resync-idle.hook"

echo "Removing commands..."
for name in glyphfield glyphfield-launch-screensaver glyphfield-screensaver; do
  dst=$BIN_DIR/$name
  if [[ -L $dst && $(readlink "$dst") == "$REPO_DIR"/* ]]; then
    rm "$dst"
    echo "  $name"
  fi
done

echo "Done. Settings kept in ~/.config/glyphfield."
