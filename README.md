# omarchy-mozax

Grid overlay, interactive cursor-hover tile glow, and optional mosaic pixelation
for the Omarchy desktop wallpaper.

The wallpaper itself remains untouched — the grid and dynamic lighting effects
draw directly on top of it. Theme switches and background cycling continue working
as normal.

## Features

- **Cursor-Hover Tile Glow**: As the cursor moves across the desktop, tiles light up
  and shine brighter based on their underlying wallpaper colors with smooth radial falloff.
- **Glowing Trail**: Leaves a smooth, fading wake behind the cursor (configurable duration
  or instant follow).
- **Grid Overlay**: Configurable line pitch (16px default), gap width, color, and opacity.
- **Mosaic Pixelation**: Optional retro blocky wallpaper variant.

## Install

```bash
omarchy plugin add https://github.com/rubichandrap/omarchy-mozax.git --enable --yes
omarchy restart shell
```

Or for local development:

```bash
cp -r ~/Projects/github.com/rubichandrap/omarchy-mozax ~/.config/omarchy/plugins/rubichandrap.mozax
omarchy restart shell
```

## Use

### Glow Controls

The tile glow is enabled by default. You can adjust its behavior dynamically via IPC:

```bash
omarchy-shell background glowToggle            # toggle glow on or off
omarchy-shell background glowStatus            # state, intensity, duration, trail, color, radius
omarchy-shell background glowRadius 2          # spotlight radius in tiles (0 = single tile)
omarchy-shell background glowIntensity 0.40    # peak center brightness (0.0 - 1.0)
omarchy-shell background glowDuration 400      # fade-out trail duration in ms (0 = instant)
omarchy-shell background glowTrail true        # true = smooth fading trail, false = instant follow
omarchy-shell background glowColor "#ffffff"   # glow overlay colour (white illuminates wallpaper)
omarchy-shell background glowBorder true       # subtle illuminated tile border (true/false)
```

### Grid Overlay Controls

The grid is enabled by default with a 16px pitch and 1px black gap:

```bash
omarchy-shell background gridToggle            # grid overlay on or off
omarchy-shell background gridStatus            # state, pitch, gap, colour, opacity
omarchy-shell background gridSize 16           # line pitch in logical pixels
omarchy-shell background gridGap 1             # band width: 1 = thin lines
omarchy-shell background gridOpacity 1.0       # strength of the bands (0-1)
omarchy-shell background gridColor "#000000"   # band colour
```

### Mosaic Pixelation Controls

Mosaic pixelation is off by default:

```bash
omarchy-shell background mosaicToggle          # mosaic pixelation on or off
omarchy-shell background mosaicStatus          # "false 8" - state and block size
omarchy-shell background mosaicBlockSize 8     # block edge in logical pixels
```

## How It Works

1. **Wayland Background Layer**: The background runs on `WlrLayer.Background` with an active `MouseArea`. When the cursor moves over visible desktop wallpaper, pointer coordinates update continuously. (When application windows cover the desktop, Hyprland directs pointer events to those windows).
2. **Tile Calculation**: Coordinates snap mathematically to grid cells around the cursor within `glowRadius`.
3. **Radial Distance Falloff**: Tiles within the radius illuminate with cosine distance falloff:
   $$\text{falloff} = \cos\left(\frac{\text{dist}}{\text{maxDist}} \times \frac{\pi}{2}\right)$$
   The tile directly under the cursor is brightest, tapering down smoothly to the outer perimeter.
4. **Decay Pool**: A circular pool of 128 delegates animates opacity decay smoothly over `glowDuration` milliseconds, giving a glowing wake effect without extra delegate allocations.

## Notes

- Fork of the built-in `omarchy.background` renderer (declared through `omarchy.clonedFrom`). It replaces the default background renderer while enabled.
- State is in-memory: a shell restart returns settings to their defaults (grid on, glow on, mosaic off).
- Uninstall with `omarchy plugin remove rubichandrap.mozax` to restore the default background.
