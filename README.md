# glyphfield

A full-screen terminal animation: a grid of glyphs painted by a moving
geometric pattern. It was built as a screensaver for
[Omarchy](https://omarchy.org), but it runs in any truecolor terminal.

It's a single Python file with no dependencies, and needs Python 3.11 or newer.

## Styles

- **kaleido**: a swirling kaleidoscope. Colored bands and glyph weights come
  from interference patterns folded into mirrored sectors.
- **mirror**: works like a real kaleidoscope. Small "beads", each a cluster of
  identical glyphs in one color and a random pixel pattern, are born at the
  center. They stream outward and grow toward the corners, and every bead is
  mirrored four ways (eight with `--folds 8`).
- **bloom**: rings breathing out from the center, with spiral dark ripples.

The layout adapts to the terminal's shape, so portrait and landscape displays
both fill the screen. The animation clock speeds up and slows down at
irrational rates, so the pattern never repeats exactly. Use `--steady` for
constant speed and an exact loop.

## Usage

```sh
glyphfield                  # style and settings from the config file
glyphfield --style mirror   # pick a style
glyphfield --tune           # live settings overlay
```

Any key exits, except in `--tune`, where `q` quits.

### Tuner

`glyphfield --tune` runs the animation full-size with a settings panel in the
top-left corner:

| Key | Action |
|---|---|
| `↑` `↓` | pick a setting |
| `←` `→` | adjust it (`[` `]` for ×5) |
| `tab` or `1` `2` `3` | switch style |
| `space` | toggle on/off settings |
| `r` / `R` | reset one setting / the whole style |
| `s` | save to the config file |
| `h` | hide the panel |
| `q` | quit |

Mirror exposes the bead count, bead size, glyphs per bead, symmetry, ring
spacing, center motif size and per-color weights.

### Config

Settings live in `~/.config/glyphfield/config.toml`, with one table per style
and a top-level `style`. The tuner writes this file. Command-line flags
override it.

## Install

```sh
git clone https://github.com/gig3m/glyphfield
ln -s "$PWD/glyphfield/glyphfield" ~/.local/bin/glyphfield
```

## License

MIT
