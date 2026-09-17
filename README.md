# omarchy-mozax

Toggleable mosaic effect for the Omarchy desktop background. The effect is
applied to the running wallpaper, so the wallpaper, theme and background
cycling keep working as usual.

## Install

```bash
omarchy plugin add https://github.com/rubichandrap/omarchy-mozax.git --enable --yes
omarchy restart shell
```

## Use

The mosaic effect is on as soon as the plugin is enabled. These commands
control it:

```bash
omarchy-shell background mosaicToggle      # flip the effect on or off
omarchy-shell background mosaicStatus      # "true 8" - state and block size
omarchy-shell background mosaicBlockSize 8 # block edge in logical pixels
```

`mosaicBlock` is the block edge length in logical pixels: 8 is fine, 16
medium, 24 coarse.

## Notes

- Fork of the built-in `omarchy.background` renderer (declared through
  `omarchy.clonedFrom`), so it replaces the built-in while enabled and
  updates to the built-in do not reach it.
- The mosaic state is in-memory: a shell restart returns it to its default,
  which is on.
- Uninstall with `omarchy plugin remove rubichandrap.mozax`; the built-in
  background comes back.
- Editing the plugin's QML needs `omarchy restart shell` - hot reload does
  not replace a running service instance.
