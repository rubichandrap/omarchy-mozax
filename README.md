# omarchy-mozax

Grid overlay and optional mosaic pixelation for the Omarchy desktop
background. The wallpaper itself is untouched - the effects draw on top of
it, so theme and background cycling keep working as usual.

## Install

```bash
omarchy plugin add https://github.com/rubichandrap/omarchy-mozax.git --enable --yes
omarchy restart shell
```

## Use

The grid overlay is on as soon as the plugin is enabled; the mosaic
pixelation is off by default. These commands control them:

```bash
omarchy-shell background gridToggle        # grid overlay on or off
omarchy-shell background gridStatus        # "true 16" - state and line pitch
omarchy-shell background gridSize 16       # line pitch in logical pixels

omarchy-shell background mosaicToggle      # mosaic pixelation on or off
omarchy-shell background mosaicStatus      # "false 8" - state and block size
omarchy-shell background mosaicBlockSize 8 # block edge in logical pixels
```

`gridColor` and `gridOpacity` (properties in `Background.qml`) control the
line colour and strength.

## Notes

- Fork of the built-in `omarchy.background` renderer (declared through
  `omarchy.clonedFrom`), so it replaces the built-in while enabled and
  updates to the built-in do not reach it.
- Effect state is in-memory: a shell restart returns it to the defaults,
  grid on and mosaic off.
- Uninstall with `omarchy plugin remove rubichandrap.mozax`; the built-in
  background comes back.
- Editing the plugin's QML needs `omarchy restart shell` - hot reload does
  not replace a running service instance.
