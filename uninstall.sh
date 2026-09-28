#!/bin/bash
#
# Undo install.sh: give Omarchy its stock idle service back and remove
# glyphfield's commands and hook. Your settings in ~/.config/glyphfield are
# left alone.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"

# shellcheck source=lib/omarchy.sh
source "$REPO_DIR/lib/omarchy.sh"

echo "Restoring the stock screensaver..."
clear_screensaver_command && echo "  removed idle.screensaverCommand (if it was ours)"
if retired=$(retire_clone) && [[ -n $retired ]]; then
  echo "  disabled $(basename "$retired"), re-enabled omarchy.idle"
  echo "  (the clone is left at $retired; delete it if you like)"
fi
restart_shell || echo "  run omarchy-restart-shell to finish restoring stock"

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
