#!/bin/bash
#
# Install glyphfield, and on Omarchy make it the screensaver.
#
#   ./install.sh            install, screensaver style: kaleido
#   ./install.sh mirror     pick the screensaver style
#   ./install.sh --no-screensaver   just the glyphfield command
#
# Everything lands in user-owned locations; nothing under /usr/share/omarchy is
# touched, so an Omarchy update will not clobber it. Commands are symlinked, so
# a `git pull` in this checkout updates them in place.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
CONF_DIR="$HOME/.config/glyphfield"
HOOK_DIR="$HOME/.config/omarchy/hooks/post-update.d"
PLUGIN_DIR="$HOME/.config/omarchy/plugins"
STOCK_IDLE="/usr/share/omarchy/shell/plugins/services/idle"
STOCK_CMD="omarchy-launch-screensaver"
CUSTOM_CMD="glyphfield-launch-screensaver"

say() { printf '  %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

style=kaleido
screensaver=1
for arg in "$@"; do
  case $arg in
  --no-screensaver) screensaver=0 ;;
  kaleido | mirror | bloom) style=$arg ;;
  *) die "unknown argument: $arg (styles: kaleido, mirror, bloom)" ;;
  esac
done

python3 -c 'import sys; sys.exit(sys.version_info < (3, 11))' 2>/dev/null ||
  die "glyphfield needs Python 3.11 or newer"

link() {
  local src=$1 dst=$BIN_DIR/$(basename "$1")
  if [[ -e $dst && ! -L $dst ]]; then
    mv "$dst" "$dst.bak.$(date +%s)"
    say "backed up an existing $(basename "$dst")"
  fi
  ln -sfn "$src" "$dst"
  say "$(basename "$dst")"
}

echo "Installing commands into $BIN_DIR..."
mkdir -p "$BIN_DIR"
chmod +x "$REPO_DIR/glyphfield" "$REPO_DIR"/bin/*
link "$REPO_DIR/glyphfield"
if ((screensaver)); then
  for f in "$REPO_DIR"/bin/*; do link "$f"; done
fi
case ":$PATH:" in *":$BIN_DIR:"*) ;; *) say "note: $BIN_DIR is not on your PATH" ;; esac

if ((!screensaver)); then
  echo "Done. Try: glyphfield --tune"
  exit 0
fi

command -v omarchy >/dev/null || die "not an Omarchy system; rerun with --no-screensaver"
[[ -f $STOCK_IDLE/Service.qml ]] || die "Omarchy's idle service is not at $STOCK_IDLE"

echo "Pointing Omarchy's idle service at glyphfield..."
# Omarchy hardcodes the screensaver launcher in the idle plugin, shell.json has
# no setting for it, and /usr/share/omarchy/bin outranks ~/.local/bin on PATH,
# so cloning the plugin is the only supported way to launch something else.
find_clone() {
  local c
  for c in "$PLUGIN_DIR"/*.idle; do
    [[ -f $c/manifest.json ]] || continue
    grep -q '"clonedFrom": *"omarchy.idle"' "$c/manifest.json" && { echo "$c"; return; }
  done
}
clone=$(find_clone)
if [[ -n $clone ]]; then
  # A clone that launches something other than stock or us belongs to someone
  # else (another screensaver project, or your own edits): leave it alone.
  if ! grep -q "$CUSTOM_CMD" "$clone/Service.qml" &&
    ! grep -q "\b$STOCK_CMD\b" "$clone/Service.qml"; then
    die "$(basename "$clone") already launches a different screensaver; not touching it"
  fi
  say "reusing $(basename "$clone")"
else
  omarchy plugin clone omarchy.idle >/dev/null
  clone=$(find_clone)
  [[ -n $clone ]] || die "could not clone omarchy.idle"
  say "cloned omarchy.idle to $(basename "$clone")"
fi

# Copy the packaged plugin over the clone (manifest aside) and swap the one
# command, exactly as the post-update hook will after each update.
for src in "$STOCK_IDLE"/*; do
  file=$(basename "$src")
  [[ -f $src && $file != manifest.json ]] || continue
  if [[ $file == Service.qml ]]; then
    sed "s/\b${STOCK_CMD}\b/${CUSTOM_CMD}/g" "$src" >"$clone/$file"
  else
    cp "$src" "$clone/$file"
  fi
done
grep -q "$CUSTOM_CMD" "$clone/Service.qml" ||
  die "Omarchy's idle service changed shape; the launcher swap needs updating"
omarchy plugin enable "$(basename "$clone")" >/dev/null 2>&1 || true
omarchy plugin disable omarchy.idle >/dev/null 2>&1 || true
say "$(basename "$clone") now launches $CUSTOM_CMD"

echo "Installing the post-update hook..."
mkdir -p "$HOOK_DIR"
ln -sfn "$REPO_DIR/hooks/post-update.d/glyphfield-resync-idle.hook" "$HOOK_DIR/glyphfield-resync-idle.hook"
say "glyphfield-resync-idle.hook"

echo "Setting the screensaver style..."
mkdir -p "$CONF_DIR"
echo "$style" >"$CONF_DIR/screensaver"
say "$style  ($CONF_DIR/screensaver)"

cat <<DONE

Done. glyphfield runs at your screensaver idle timeout (idle.screensaver in
~/.config/omarchy/shell.json). To see it now:

    $CUSTOM_CMD force

Change the look:   glyphfield --tune   (s saves; the screensaver uses it)
Change the style:  echo mirror > $CONF_DIR/screensaver
Stock art again:   empty that file, or run ./uninstall.sh
DONE
