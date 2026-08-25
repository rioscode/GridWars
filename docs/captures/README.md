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
  instead of one quadrant of the 2× framebuffer; and
- store screenshots as opaque RGB so an undefined window-framebuffer alpha
  channel cannot affect otherwise identical PNGs.

Capture mode uses the original compiled renderer, entity types, draw functions,
and assets; fixes the random seed; installs default scores and colours; and
skips all reads and writes under `~/.config/gridwars`. It changes only the
selected fixed state, window mode, and PNG export after the named frame. The
94 available references cover:

- the title, scores, friends, and enemies attract pages at frame 600;
- the options page at frame 20;
- gameplay, default and upgraded HUD states, and the fading power-up threshold
  message;
- Get Ready title/rings, player death, Game Over, and high-score entry;
- all ten isolated enemies, six paired 30-frame basic-enemy motion states, and
  all ten generator variants;
- all nine power-ups;
- all 21 grid styles and all four particle styles; and
- Solid, Low, Medium, High, and User graphics sets; and
- every options, confirmation, settings, video, game, audio, and controller
  menu page.

`original/SHA256SUMS` pins the exact reference artifacts. To regenerate them:

```sh
./scripts/capture-original.sh /path/to/BlitzMax
```

Pass an output directory as the second argument. An optional third argument
captures just one named state, for example:

```sh
./scripts/capture-original.sh /path/to/BlitzMax /tmp/gridwars-original death
```

The script copies source and assets to a `mktemp` directory, textually includes
`scripts/original-catalog.bmx`, patches and builds only that copy, captures the
94 states, then deletes the temporary build.

## Swift renderer

The macOS target supports a persistence-free capture mode for 94 fixed states:
the attract screens, gameplay transitions, every enemy and generator, every
power-up, six basic-enemy motion checks, all 21 grid styles, all particle and
graphics sets, HUD variants, and every menu page. Captures are normalized to
the original 1024×768 pixel size.
Run:

```sh
sh scripts/capture-screens.sh
```

An optional first argument selects the output directory. The capture mode does
not load or save player configuration or high scores. It requires an active,
unlocked macOS window session so SpriteKit can create a render texture.

## Comparison

With ImageMagick installed, compare every currently matching original/Swift
pair and verify that both inputs are 1024×768:

```sh
sh scripts/compare-captures.sh docs/captures/original docs/captures/swift
```

The CSV value is the normalized mean absolute pixel difference: zero is exact
pixel identity. Small nonzero values are expected where BlitzMax/OpenGL and
SpriteKit rasterize the same vector edges differently. Review the images as
well; the metric alone is not fidelity acceptance.
