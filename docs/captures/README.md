# Visual reference captures

These images support the 1024×768 visual audit of the Swift port against the
original GridWars 5.4 renderer.

## Original renderer

`original/` contains fixed-frame PNGs rendered from a temporary, instrumented
copy of the repository's BlitzMax source. The repository source itself was not
modified. The reference executable was built with the official BlitzMax NG
macOS arm64 release `v0.165.3.61.macos.arm64`, archived under `docs/bb/` by URL
and checksum.

The modern compiler required compatibility-only edits in the temporary copy:

- rename the game's `Rect` helper to avoid the newer `BRL.Max2D.Rect` symbol;
- remove a duplicate legacy framework declaration;
- enable the compiler's legacy numeric-conversion mode.

The capture hook changes only the selected presentation page, the 1024×768
window mode, and PNG export after the named frame. Available references are:

- `title-600.png`
- `scores-600.png`
- `friends-600.png`

Further launches of the legacy executable were denied by the workspace safety
policy because it may write configuration files. Enemy and options layouts are
therefore audited directly against `gridwars.bmx` and `control.bmx` until those
captures can be produced in an isolated user-approved environment.

## Swift renderer

The macOS target supports a persistence-free capture mode for the title,
scores, friends, enemies, representative gameplay, and every options/config
page. Run:

```sh
sh scripts/capture-screens.sh
```

An optional first argument selects the output directory. The capture mode does
not load or save player configuration or high scores. It requires an active,
unlocked macOS window session so SpriteKit can create a render texture.
