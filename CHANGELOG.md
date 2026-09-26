# Changelog

All notable changes to Mozax are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[semantic versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-09-26

The glow is rebuilt around the same field the omarchy-site header runs: a tile
lights only when the light under the cursor beats a threshold it owns.

### Added

- **Dithered lighting.** Every tile's threshold is an 8x8 ordered dither rank
  mixed with a per-tile random offset, hashed from a 64x64 noise patch so a tile
  keeps its rank while it sits still. The pool arrives as a loose constellation
  that thickens toward the cursor and dissolves at its edge, rather than a disc
  of solid tiles.
- **Ambient drift.** A second, fainter pool wanders the screen on two
  incommensurate periods so it never repeats. It dims to 40% while it charges,
  then blooms the Omarchy mark: once a second or two after it starts drifting,
  and every two to three seconds after that.
- **Hold to charge.** A press charges over 1.1s. A quick click leaves a small
  mark, a long hold blooms a wide one, and either way it dissolves through the
  same threshold as the glow.
- **`glowScatter`** (0 ordered dither to 0.6 fully random) and **`glowDrift`**,
  with matching `glowScatter`, `glowScatterStatus` and `glowDrift` IPC calls.
- **`burst col row`** and **`glowHover x y`**, to place the mark or the pool from
  a script.

### Changed

- The lit tiles are a pool of items sized to the pool's reach, rebuilt each
  frame. A parked cursor costs nothing: the repaint flag goes false and the
  frame loop stops touching the tiles. The old trail FIFO, per-tile delegate
  recycling and burst animations are gone, taking about 550 lines with them.
- Tiles are coloured from a 32-step ramp between `darker(accent, 2.3)` and
  `lighter(accent, 1.45)`, so a lit tile reads as lit instead of pasted on.
- `glowRadius` now names the radius of the solid core. The scattered halo
  reaches about twice as far, because the dither throws most of the light away.
- Defaults: `glowRadius` 3 to 4, `glowIntensity` 0.45 to 0.7.

### Removed

- **`glowDuration`** — a mark's lifetime is now the site's
  `(0.65 + 0.55 x charge)` seconds instead of riding on a fade slider.
- **`glowBorder`** — a one pixel lip has no room to sit in on a 4px tile.
- **`glowTrail`** — the pool was never smoothed to begin with. The site lights
  the cells under the cursor and only eases its response, so the control was a
  lag in different units.

Their controls, properties and IPC calls are gone with them. Old keys in
`mozax.json` are ignored on load, so nothing needs migrating.

## [1.1.0] - 2026-09-24

- Bar widget with live popup controls, on the bar and controllable over IPC.
- Tabbed controls (Glow, Grid, Pixel, Audio) with custom sliders.
- Colour pickers for the grid and the glow.
- Mosaic audio visualizer alongside the spectrum bars, sharing one Cava feed.
- Visualizer width as a ratio, a percentage, or full width.
- Knob state persisted to `~/.local/state/omarchy/mozax.json`, so IPC-tuned
  settings survive a shell restart.
- Troubleshooting section for the black desktop after disabling Mozax.
- Visualizer sits flush with the bottom of the screen.

## [1.0.0] - 2026-09-17

- Mosaic wallpaper pixelation.
- Grid overlay with gap width, colour and opacity, snapped to the tile lattice.
- Interactive cursor-hover tile glow with radial falloff, bound to the active
  theme accent.
- Click burst of the Omarchy mosaic logo, snapped to the glowing tile origin.
- Bottom spectrum-bar audio visualizer powered by Cava.
