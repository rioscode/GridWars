# Metal effects prototype

## Status and scope

The Metal path is an experimental, default-off compositor for exactly two
effects:

- Grid style 1, `GridStyle.pointsCycling`;
- particle style 1, the wide additive line style.

Gameplay state, the 50-Hz simulation, collisions, input, audio, entities, HUD,
menus, all other Grid styles, and all other particle styles remain in the
existing Swift/SpriteKit implementation. The CPU snapshot passed to Metal is a
presentation-only view of those authoritative simulations.

The integrated `MTKView`/`SKRenderer` host is macOS-only. On iOS the app always
uses the normal SpriteKit `SKView`; the shared Metal snapshot and encoder source
is present in both application targets, but no iOS view selects it.

## Opt in, opt out, and run

Build the macOS app as usual:

```sh
xcodebuild -project GridWars.xcodeproj -scheme GridWars-macOS \
  -configuration Debug -derivedDataPath .build/DerivedData build

APP=.build/DerivedData/Build/Products/Debug/GridWars.app/Contents/MacOS/GridWars
```

With no switch, the app uses the normal SpriteKit host. Enable the prototype
for one process with either the environment or the command-line switch:

```sh
GRIDWARS_METAL_EFFECTS=1 "$APP"
"$APP" --metal-effects
```

The explicit disable switch has highest precedence, including when the
environment enables Metal:

```sh
GRIDWARS_METAL_EFFECTS=1 "$APP" --no-metal-effects
```

There is deliberately no persisted setting yet. Restarting without an opt-in
returns to SpriteKit.

## Integrated architecture

`GameView` selects `MetalPlatformGameView` only on macOS and only after
`MetalEffectsConfiguration.current` resolves to enabled. The Metal host owns an
`MTKView`, an `SKRenderer` for the existing scene, one command queue, and a
`MetalEffectsRenderer` for the two covered effects. The view requests 60-Hz
presentation, while `GameScene` remains authoritative at 50 Hz.

SpriteKit has no supported insertion point between arbitrary sibling nodes, so
one transparent SpriteKit overlay would put trails on the wrong side of the
particle pass. The compositor instead renders the scene in this order:

1. Clear to black and draw Grid style 1 with Metal when it is covered.
2. Draw the SpriteKit background pass: the SpriteKit Grid fallback when needed,
   stars, low effects, Get Ready rings, and player trails.
3. Draw particle style 1 with Metal when covered; otherwise draw the SpriteKit
   particle pass.
4. Draw the SpriteKit foreground pass: arena border, higher effects, enemies,
   projectiles, pickups, player and shield, HUD, and screens. Existing SpriteKit
   `zPosition` ordering remains authoritative inside each pass.

The scene records and restores every affected node's prior `isHidden` value
around these passes. Menus and states without eligible coverage are rendered as
one full SpriteKit frame. The frozen options-menu background is also captured
from a full offscreen SpriteKit render, so opening a menu does not freeze a
partially composed scene.

Both effect snapshots use the same presentation interpolation alpha as
SpriteKit. Simulation still advances in fixed 20-ms steps. Grid positions,
particle positions and velocities, the camera, and SpriteKit node positions are
interpolated only for display; before input or the next fixed step, the scene
restores the current authoritative values. Interpolated values therefore never
feed collisions or gameplay decisions.

## Metal raster and buffers

The Metal snapshot preserves the source-visible details already encoded by the
SpriteKit renderer: the Grid's source-ordered base/column/row point passes,
top-left rectangles, particle pixel-center correction, doubled velocity,
two-pixel butt-capped lines, color boost, alpha, additive blending, aspect-fit
mapping, and camera offset.

Each effect pass uploads 48-byte instances into its own grow-only,
triple-buffered shared-buffer ring. One frame slot is acquired and shared by
the Grid and particle encoders; each covered effect is one instanced triangle
draw. The buffers grow to the next power of two and are not shrunk during play.

The drawable and offscreen menu texture use `bgra8Unorm`, not
`bgra8Unorm_srgb`. The legacy Max2D evidence and SpriteKit captures treat the
supplied RGB channels as display-space values; an sRGB attachment would encode
the Metal fragment output a second time.

`GridWarsSwift/Game/GridWarsEffects.metal` is currently an explicit text
resource in the macOS app, iOS app, and test bundles, not a Sources-build-phase
member. `MetalEffectsRenderer` first accepts a default Metal library only when
it already contains both required functions. Otherwise it reads that bundled
`.metal` file and compiles it with `makeLibrary(source:)` at runtime. There is
no second embedded Swift shader string in the current implementation.

## Automatic fallbacks

The prototype must always remain removable without changing gameplay code. Its
current fallback boundaries are:

- no Metal device or command queue, missing shader resource, shader/pipeline
  failure, or renderer initialization failure: create the normal `SKView` host;
- unsupported Grid or particle style: keep that individual SpriteKit effect;
- menu or frame with no Metal coverage: render the complete frame in SpriteKit;
- synchronous render-target or command-encoder failure: restore node
  visibility, disable the prototype for the rest of the process, and render
  the current frame fully with SpriteKit;
- asynchronous command-buffer GPU error: detect it on the next draw, disable
  the prototype for the rest of the process, and continue with SpriteKit.

Failures are reported to standard error. The feature is not automatically
re-enabled within the same process after a rendering failure.

## Deterministic capture comparison

Capture the two covered scenarios with identical deterministic state:

```sh
APP=.build/DerivedData/Build/Products/Debug/GridWars.app/Contents/MacOS/GridWars

"$APP" --capture-screen grid-01 \
  --capture-output /private/tmp/grid-spritekit.png
GRIDWARS_METAL_EFFECTS=1 "$APP" --capture-screen grid-01 \
  --capture-output /private/tmp/grid-metal.png

"$APP" --capture-screen particle-1 \
  --capture-output /private/tmp/particle-spritekit.png
GRIDWARS_METAL_EFFECTS=1 "$APP" --capture-screen particle-1 \
  --capture-output /private/tmp/particle-metal.png
```

For a full catalog run, the environment is inherited by every capture process:

```sh
GRIDWARS_METAL_EFFECTS=1 \
  sh scripts/capture-screens.sh /private/tmp/GridWarsMetalCatalog
sh scripts/compare-captures.sh \
  docs/captures/original /private/tmp/GridWarsMetalCatalog
```

The focused 1024x768 captures currently measure as follows. The metric is the
normalized grayscale mean absolute difference used by
`scripts/compare-captures.sh`; it is a triage signal, not an acceptance proof.

| Pair | Difference |
| --- | ---: |
| SpriteKit Grid 1 vs Metal Grid 1 | `0.0000587151` |
| SpriteKit particle 1 vs Metal particle 1 | `0.0016534` |
| original Grid 1 vs Metal Grid 1 | `0.00198938` |
| original Grid 1 vs SpriteKit Grid 1 | `0.00205562` |
| original particle 1 vs Metal particle 1 | `0.00322177` |
| original particle 1 vs SpriteKit particle 1 | `0.00272125` |

Metal Grid 1 is visually very close to SpriteKit and is marginally closer to
the original in this capture. Metal particle 1 has harder triangle-expanded
line rasterization, caps, and edge coverage than SpriteKit; it is visibly less
faithful and remains experimental.

## Release Instruments A/B

`--effects-benchmark` creates one static deterministic gameplay presentation:
Grid style 1, 2,048 active style-1 particles, no stars, hidden player/HUD, and
no persistence load or save. Use new output paths for every recording because
`xctrace` does not overwrite an existing trace:

```sh
xcodebuild -project GridWars.xcodeproj -scheme GridWars-macOS \
  -configuration Release -derivedDataPath .build/DerivedData build

APP=.build/DerivedData/Build/Products/Release/GridWars.app/Contents/MacOS/GridWars
mkdir -p .build/metal-comparison

xcrun xctrace record --template 'Game Performance' --time-limit 8s \
  --output .build/metal-comparison/spritekit-run.trace --no-prompt \
  --launch -- "$APP" --effects-benchmark

xcrun xctrace record --template 'Game Performance' --time-limit 8s \
  --output .build/metal-comparison/metal-run.trace --no-prompt \
  --env GRIDWARS_METAL_EFFECTS=1 \
  --launch -- "$APP" --effects-benchmark
```

The final recorded A/B was one 8-second Release run per renderer at 1024x768
and 60-Hz display presentation. For app-specific present-request intervals in
the steady 3-8 second window it produced:

| Renderer | Intervals | p50 | p95 | mean |
| --- | ---: | ---: | ---: | ---: |
| SpriteKit | 290 | 16.6771 ms | 17.6055 ms | 17.1844 ms |
| Metal | 293 | 16.6548 ms | 17.3597 ms | 17.0063 ms |

The same 3-8 second window produced these supporting measurements:

| Renderer | CPU samples/frame mean (p95) | GPU span mean (p95) |
| --- | ---: | ---: |
| SpriteKit | 1.9069 ms (4 ms) | 0.6752 ms (1.2332 ms) |
| Metal | 1.6826 ms (4 ms) | 0.5713 ms (1.2986 ms) |

CPU duration is estimated from 1-ms Instruments samples. GPU duration is the
span from the first to last app-specific GPU interval grouped by GPU frame.
This is a single, vsync-limited run: it suggests modest average CPU/GPU savings
but no material p95 frame-pacing improvement, and GPU p95 is slightly worse.
Large maxima in either trace are outliers, and display-wide surface rates must
not be presented as app-specific FPS.

## Current decision and remaining gates

Keep the prototype disabled by default. The Grid result is promising enough to
retain for further experiments, but the current data does not justify shipping
Metal as the normal renderer, and the particle raster still needs fidelity
work.

Before promoting either path, repeat Release measurements across multiple runs
and hardware and improve particle edge fidelity. The complete 136-state
SpriteKit catalog has been regenerated after Phase 1 (126 byte-identical, ten
with only `2.31e-9` to `3.12e-6` normalized mean raster noise), both platform
builds pass, and all 139 macOS tests pass. The SpriteKit implementation remains
the permanent rollback path.
