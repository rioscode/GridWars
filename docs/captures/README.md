# Visual reference captures

These images support the 1024×768 visual audit of the Swift port against the
original GridWars 5.4 renderer.

## Original renderer

`original/` contains deterministic fixed-frame PNGs rendered from an isolated,
instrumented copy of the repository's BlitzMax source. The repository source
itself is never modified. The reference executable was built with the official
BlitzMax NG macOS arm64 release `v0.165.3.61.macos.arm64`.

The reproducible harness is `scripts/capture-original.sh`; its small source
instrumentation lives in `scripts/original-capture.patch`. The modern compiler
requires compatibility-only edits in the temporary copy:

- rename the game's `Rect` helper to avoid the newer `BRL.Max2D.Rect` symbol;
- remove a duplicate legacy framework declaration;
- use the original implicit numeric conversions, which BlitzMax NG reports as
  warnings;
- bypass the modern `GraphicsModeExists` window-mode rejection for the fixed
  1024×768 capture window;
- disable Retina backing so `GrabPixmap` returns the complete logical frame
  instead of one quadrant of the 2× framebuffer.

Capture mode uses the original compiled renderer and assets, fixes the random
seed, installs default scores and colours, and skips all reads and writes under
`~/.config/gridwars`. It changes only the selected presentation page, fixed
window mode, and PNG export after the named frame. Available references are:

- `title-600.png`
- `scores-600.png`
- `friends-600.png`
- `enemies-600.png`
- `options-20.png`

`original/SHA256SUMS` pins the exact reference artifacts. To regenerate them:

```sh
./scripts/capture-original.sh /path/to/BlitzMax
```

The script copies source and assets to a `mktemp` directory, patches and builds
only that copy, captures the five states, then deletes the temporary build.

## Swift renderer

The macOS target supports a persistence-free capture mode for 87 fixed states:
the attract screens, gameplay transitions, every enemy and generator, every
power-up, all 21 grid styles, all particle and graphics sets, HUD variants, and
every menu page. Captures are normalized to the original 1024×768 pixel size.
Run:

```sh
sh scripts/capture-screens.sh
```

An optional first argument selects the output directory. The capture mode does
not load or save player configuration or high scores. It requires an active,
unlocked macOS window session so SpriteKit can create a render texture.
