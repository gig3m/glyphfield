# Shared by install.sh, uninstall.sh and the post-update hook: how glyphfield
# gets Omarchy's idle service to launch it. Source this; don't run it.
#
# Two ways, newest first:
#
#   setting  Omarchy's idle service reads idle.screensaverCommand from
#            shell.json (proposed upstream in omacom/omarchy#10483). One config
#            line, nothing cloned.
#   clone    Older Omarchy hardcodes omarchy-launch-screensaver in the idle
#            service, so clone it into <user>.idle and swap that one command.
#
# The paths can be overridden (GLYPHFIELD_STOCK_IDLE, GLYPHFIELD_SHELL_JSON,
# GLYPHFIELD_PLUGIN_DIR) to test against copies.

STOCK_IDLE="${GLYPHFIELD_STOCK_IDLE:-/usr/share/omarchy/shell/plugins/services/idle}"
SHELL_JSON="${GLYPHFIELD_SHELL_JSON:-$HOME/.config/omarchy/shell.json}"
PLUGIN_DIR="${GLYPHFIELD_PLUGIN_DIR:-$HOME/.config/omarchy/plugins}"
STOCK_CMD="omarchy-launch-screensaver"
CUSTOM_CMD="glyphfield-launch-screensaver"

# Does this Omarchy's idle service read idle.screensaverCommand?
supports_screensaver_command() {
  grep -q 'screensaverCommand' "$STOCK_IDLE/Service.qml" 2>/dev/null
}

# Set idle.screensaverCommand to our launcher. Keeps a backup of shell.json.
set_screensaver_command() {
  local tmp
  mkdir -p "$(dirname "$SHELL_JSON")"
  [[ -s $SHELL_JSON ]] || echo '{"version": 1}' >"$SHELL_JSON"
  cp -a "$SHELL_JSON" "$SHELL_JSON.bak.$(date +%s)"
  tmp=$(mktemp "$SHELL_JSON.XXXXXX")
  jq --arg c "$CUSTOM_CMD" '.idle = ((.idle // {}) | .screensaverCommand = $c)' "$SHELL_JSON" >"$tmp" &&
    mv "$tmp" "$SHELL_JSON" || { rm -f "$tmp"; return 1; }
}

# Remove idle.screensaverCommand, but only if it is ours.
clear_screensaver_command() {
  local tmp
  [[ -s $SHELL_JSON ]] || return 0
  [[ $(jq -r '.idle.screensaverCommand // empty' "$SHELL_JSON") == "$CUSTOM_CMD" ]] || return 0
  cp -a "$SHELL_JSON" "$SHELL_JSON.bak.$(date +%s)"
  tmp=$(mktemp "$SHELL_JSON.XXXXXX")
  jq 'del(.idle.screensaverCommand)' "$SHELL_JSON" >"$tmp" && mv "$tmp" "$SHELL_JSON" || { rm -f "$tmp"; return 1; }
}

# The <user>.idle clone of omarchy.idle, if any. It is named after whoever
# cloned it, so find it by its origin.
find_clone() {
  local c
  for c in "$PLUGIN_DIR"/*.idle; do
    [[ -f $c/manifest.json ]] || continue
    grep -q '"clonedFrom": *"omarchy.idle"' "$c/manifest.json" && { echo "$c"; return; }
  done
}

# The clone, only if glyphfield set it up (it launches our command).
our_clone() {
  local c
  c=$(find_clone)
  [[ -n $c ]] && grep -q "$CUSTOM_CMD" "$c/Service.qml" 2>/dev/null && echo "$c"
}

# Copy the packaged idle service over the clone (manifest aside) and swap the
# launcher. Fails, touching nothing, if the swap no longer applies.
sync_clone() {
  local clone=$1 tmp src file
  tmp=$(mktemp -d)
  for src in "$STOCK_IDLE"/*; do
    file=$(basename "$src")
    [[ -f $src && $file != manifest.json ]] || continue
    if [[ $file == Service.qml ]]; then
      sed "s/\b${STOCK_CMD}\b/${CUSTOM_CMD}/g" "$src" >"$tmp/$file"
    else
      cp "$src" "$tmp/$file"
    fi
  done
  if ! grep -q "$CUSTOM_CMD" "$tmp/Service.qml" 2>/dev/null; then
    rm -rf "$tmp"
    return 1
  fi
  SYNCED=()
  for src in "$tmp"/*; do
    file=$(basename "$src")
    if ! cmp -s "$src" "$clone/$file"; then
      cp "$src" "$clone/$file"
      SYNCED+=("$file")
    fi
  done
  rm -rf "$tmp"
}

# Hand idle duty back to the stock service and park our clone (left on disk).
retire_clone() {
  local c
  c=$(our_clone)
  [[ -n $c ]] || return 0
  omarchy plugin enable omarchy.idle >/dev/null 2>&1 || true
  omarchy plugin disable "$(basename "$c")" >/dev/null 2>&1 || true
  echo "$c"
}

# The idle service is keepLoaded, and changing idle.* in shell.json stops its
# monitor until restart (omacom/omarchy#8038), so every switch ends here.
restart_shell() {
  omarchy-restart-shell >/dev/null 2>&1
}
