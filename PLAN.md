# GridWars Swift Port Plan

## Goal

Port GridWars 5.4 from BlitzMax to a native Swift/SpriteKit application that
runs on macOS and iOS while keeping the original source and assets available as
the gameplay reference.

The final target is a behaviourally and visually faithful reproduction of
GridWars 5.4. Platform integration and rendering use native Apple frameworks,
but gameplay constants, progression, presentation, menus, assets, audio cues,
and persisted data must match the original unless `FIDELITY.md` records a
verified platform-specific equivalent.

## Supported platforms

- macOS 14 or newer
- iOS and iPadOS 17 or newer
- Swift 6
- SpriteKit as the canonical/default renderer on macOS and iOS, and for the
  scene, particles, physics, and audio playback
- An opt-in, default-off macOS Metal prototype for Grid style 1 and Particle
  style 1; iOS always uses SpriteKit
- SwiftUI for the application shell and platform lifecycle

## Architecture

- `GridWarsSwift/App`: SwiftUI application entry point and platform views.
- `GridWarsSwift/Game`: shared SpriteKit scene, entities, game state, input,
  spawning, scoring, and effects.
- `GridWarsSwift/Resources`: copied/adapted original graphics, sounds, and music.
- `GridWarsSwiftTests`: deterministic tests for pure gameplay rules.
- `GridWars.xcodeproj`: macOS, iOS, and test targets.

The game scene owns the real-time loop. Platform views translate mouse,
keyboard, touch, and controller input into a small shared input state. Pure
rules such as score thresholds and spawn pacing stay outside SpriteKit where
they can be tested without rendering. The authoritative simulation remains a
fixed 50-Hz step. Separate previous/current presentation snapshots interpolate
visual transforms, Grid points, stars, and particle position/velocity between
steps without feeding interpolated values back into gameplay. The optional
Metal path is an effects renderer around the same SpriteKit scene; it does not
own gameplay, collisions, audio, or input.

## Milestones

### 1. Project scaffold

- Create a multiplatform Xcode project with macOS and iOS application targets.
- Share Swift gameplay sources and resources between both applications.
- Add a unit-test target for platform-independent rules.
- Verify both application targets compile from the command line.

### 2. Playable core

- Render the scrolling neon grid and star field.
- Add player movement, aiming, projectiles, arena bounds, and collisions.
- Reproduce every original enemy, generator, projectile, and power-up rule.
- Add lives, bombs, score, multiplier, game-over, and restart flow.
- Add keyboard/mouse controls on macOS and twin virtual sticks on iOS.

### 3. Assets and feedback

- Reuse the original PNG and WAV resources.
- Add hit, explosion, pickup, and bomb feedback.
- Add power-ups and HUD indicators.
- Confirm resources are packaged in both application bundles.

### 4. Compatibility and verification

- Build Debug configurations for macOS and an iOS Simulator.
- Run unit tests.
- Launch the macOS application and smoke-test the primary game loop.
- Resolve warnings that indicate correctness or portability problems.

### 5. Full fidelity

- Recreate every original enemy and all 21 grid selectors.
- Reproduce the complete configuration and high-score menus.
- Match every original sound/music backend detail.
- Tune difficulty and spawn timing against side-by-side gameplay captures.
- Complete every item in `FIDELITY.md` and attach authoritative verification.

### 6. Rendering performance experiment

- Phase 1 caches decoded `CGImage` values (including missing-image results),
  complete `SKTexture` values, and animation-frame textures in
  `OriginalGraphics`.
- Phase 1 keeps the HUD and screen content alive, pools Grid and particle
  nodes, resets reused node state, and hides unused pool entries instead of
  rebuilding complete node trees each frame.
- SpriteKit particles use pooled, reusable line and sprite geometry. They are
  intentionally not combined into a single compound path: per-particle colour
  and exact additive overlap/draw order require independently drawn geometry.
- Phase 1 separates the fixed 50-Hz authority state from interpolated
  presentation state, including camera-relative stars and particle velocity.
- Phase 2 provides a default-off macOS Metal A/B prototype for only legacy
  Grid style 1 and Particle style 1. It is enabled with
  `GRIDWARS_METAL_EFFECTS=1` or `--metal-effects`; `--no-metal-effects` wins.
  All other effects fall back to SpriteKit, and iOS remains entirely on the
  SpriteKit path.
- Keep the Metal prototype opt-in until measurements show a repeatable gain and
  each effect passes the same screenshot-fidelity boundary. Do not move
  gameplay logic, collisions, audio, or input to Metal.

## Definition of done for the first milestone

- `xcodebuild` succeeds for the macOS scheme.
- `xcodebuild` succeeds for an available iOS Simulator destination.
- Gameplay unit tests pass.
- The player can move, aim, shoot, use a bomb, defeat enemies, collect a
  power-up, gain score, lose lives, reach game over, and restart.
- `README.md` explains how to build and run the Swift port.

## Current status

The source-level implementation and acceptance inventory is complete on the
`codex/swift-port` branch. Each completed fidelity milestone has its own
commit:

- [x] Shared SwiftUI/SpriteKit app sources
- [x] macOS keyboard and mouse input
- [x] iOS twin-stick touch input, including fixed side-gutter controls on
      widescreen iPhones and the floating 4:3 fallback
- [x] All five original control modes and all three Hybrid configurations
- [x] Apple controller ports, button remapping, axis mapping, and calibration
- [x] Core combat, scoring, lives, bombs, enemies, and power-ups
- [x] Original PNG and WAV resources packaged for both targets
- [x] All enemies, generators, projectiles, power-ups, and spawn rules
- [x] All 21 grid selectors and all four particle selectors
- [x] Original graphics sets, vector HUD, screens, and fixed menu layouts
- [x] Original WAV mappings and lossless conversions of the tracker music
- [x] Legacy configuration, colours, high scores, and checksum compatibility
- [x] Original arena sizing, camera scrolling, star parallax, pause, and cheats
- [x] Transactional Video/Game settings confirmation and rollback
- [x] Official BlitzMax/BlitzBasic language references archived in `docs/bb`
- [x] Reusable BlitzMax-to-Swift rewrite notes for coordinates, transforms,
      textures, blending, timing, randomness, persistence, and verification
- [x] macOS Debug build
- [x] Generic iOS Simulator Debug build
- [x] Generic unsigned iPhoneOS arm64 Debug build
- [x] iPhone 17 Pro and iPad Air 11-inch Simulator touch/layout smoke tests,
      plus iPhone persistence, lifecycle, and exit validation
- [x] Physical iPhone 17 Pro Max gameplay, touch, menu, lifecycle, and
      persistence smoke test on iOS 26.6
- [x] 143 gameplay, input, persistence, audio, rendering, interpolation, and
      Metal-prototype unit tests
- [x] macOS launch and rendering smoke test
- [x] Deterministic 136-state Swift capture catalog at 1024×768
- [x] Manual side-by-side review of all 136 Original/Swift capture pairs,
      including full-resolution review of the largest renderer differences
- [x] Source-ordered Grid simulation and style-specific rendering pass for all
      21 selectors, including fixed-50-Hz animation phases and original
      particle-image composition
- [x] All four BlitzMax particle draw paths, including doubled vector lines,
      half-scale image particles, and the separate bloom-image pass
- [x] Archived BRL.Random-compatible seeded generator and source-ordered
      600-frame attract capture simulation
- [x] BRL.Random as the live gameplay RNG, with source-ordered Spawn scheduler,
      corner/SafeXY sampling, per-kind constructors, recursive Snake calls,
      Diamond's zero-valued jitter calls, and particle/power-up branches
- [x] Source-specific Dual Analog configuration renderer using the official
      8×16 BRL Max2D bitmap font and original `1/128/255` scale values
- [x] Source-rasterized Get Ready rings, vector title, and pre-`Flip`
      frontbuffer frame selection
- [x] Source-coordinate isolated enemy player placement and degree-based Snake
      segment wave
- [x] Source-sized Video Settings preview grid, original 35-entry screen-mode
      table, capture-mode window state, and menu counter/pointer phase
- [x] SpriteKit-Y-transformed BlitzMax particle boundary response
- [x] BRL-seeded capture stars and initial entity transforms, vertical HUD
      icon frames, and cycling-colour power-up star
- [x] Capture-specific arena-border visibility regression guard
- [x] Source-equivalent 90-degree initial Snake tail rotation for the
      zero-velocity first draw
- [x] OpenGL-like unsmoothed vector-font strokes with butt caps and miter joins,
      retaining the overlapping title's stable smooth SpriteKit raster
- [x] BlitzMax top-left `DrawRect` anchoring for point grids after SpriteKit Y
      conversion
- [x] OpenGL-to-SpriteKit pixel-center alignment for stretched edge, checker,
      and diagonal grid lines
- [x] Dense-mesh raw-OpenGL alpha semantics and SpriteKit additive
      premultiplication compensation
- [x] RGB-split raw-OpenGL alpha, scene-inverted red-channel offset, and finer
      per-vertex colour approximation
- [x] RGB-split source traversal, repeated-corner phase, and side-specific red
      displacement checks
- [x] 64-level per-cell colour/alpha approximation for stretched and sine
      filled grid quads
- [x] 64-level continuous colour/width approximation for stretched line grids
      and selector-specific hard rasterization for Grid style 11
- [x] Get Ready's two source-ordered Grid updates per displayed frame, including
      pull-before-update ordering
- [x] Centralized 50-Hz simulation timing plus audited difficulty, all four
      wave cadences, score values, multiplier and award thresholds
- [x] Source-ordered generator `SafeXY`/BRL.Random state, ten geometries,
      health-based birth/warning timing, inherited blend, and fill-alpha quirks
- [x] Source-ordered 180-frame bottom power-up threshold message, including
      halfway text refresh, inherited lower-HUD alpha, and Game Over countdown
- [x] Source-exact motion constants, separation thresholds, boundary response,
      rotation handedness, kill ordering, and Cubie split offsets for the six
      basic enemy types, verified by paired 30-frame motion captures
- [x] Dwight Black Hole activation, shrink/growth, mutual orbit, absorption,
      pull, collision/score thresholds, loop rates, overload spawn ring, and
      floating kill-score presentation
- [x] Selena Snake source-handed head steering, per-axis corner turns, global
      speed progression, 25-node following order, Tail hit persistence,
      generator `SafeXY`, and 30/300-frame staged chain destruction
- [x] Ivan Interceptor source-space facing AI, live-speed steering, boundary
      rollback, frame-cached shield collision cone, legacy `PointInTri` edge
      behavior, projectile blocking, shield renderer, and destruction order
- [x] Trish Triangle list-ordered pairing, elastic bond, endpoint-local
      strength/resistance, duplicate bond rendering, projectile impulse,
      player-line collision, Black-Hole spin/break, and kill ordering
- [x] Player inertia, effective integer speed cap, boundary rollback, facing,
      three-part trail, 18-point shield, and source-ordered normal cannon,
      reverse, and side-shooter formations
- [x] Super piercing, Bouncy reflection, live upgrade-timer colour precedence,
      two-half-step projectile order, source `1...H` scene bounds, minimum-speed
      typo, and active Black-Hole deflection
- [x] All nine Power-up effects, raw-value selection and need bias, source-Y
      spawn sampling, frozen collection order, capped-score fallback,
      50-frame messages, aging, attraction, merge/expiry Butterflies, and
      active-Black-Hole absorption
- [x] Top-left 1×1 `Plot` pixel anchoring for midpoint-circle Get Ready rings
- [x] OpenGL pixel-center anchoring for one-pixel particle line style 0
- [x] OpenGL pixel-center anchoring and additive-alpha compensation for the
      wide particle line styles 1 and 3
- [x] Hard, pixel-centered BlitzMax `Rect(...,0)` outlines across all classic
      settings and controller menus
- [x] Max2D's shared-start rotation quirk and hard line raster for animated
      menu target cursors, including capture-time mouse placement
- [x] Top-left, 2×2 `DrawRect` star pixels with `LIGHTBLEND` and additive-alpha
      compensation
- [x] Source-initialized 10,001-star table, integer brightness, tall-arena
      depth parallax, and RNG consumption before gameplay entity creation
- [x] Screen-wide attract particle bounds, source-angle handedness, firework
      branch call order, configurable 50,000-slot rendering, and Dwight's
      eight-particle 60-frame ambient ring
- [x] Point-grid major highlights begin at source row/column four rather than
      incorrectly treating index zero as a highlighted multiple
- [x] Texture, decoded-image, missing-image, and animation-frame caches in
      `OriginalGraphics`
- [x] Persistent HUD content plus reusable screen, Grid, and particle node
      pools with explicit reused-state reset and hidden inactive tails
- [x] Presentation-only interpolation over the authoritative fixed 50-Hz
      simulation, including camera-relative stars and particle velocity
- [x] Pooled reusable SpriteKit particle geometry, retaining per-particle
      colour and source-ordered additive overlap instead of compound batching
- [x] Deterministic dynamic iOS performance benchmark with points-of-interest
      signposts and optional SpriteKit FPS/node/draw/quad counters
- [x] Projectile collision candidates classified once per update and reused
      across all projectile half-steps, preserving source kind and list order
- [x] Three physical-iPhone current-release Game Performance measurements plus
      a 30-second Allocations trace
- [x] Typed projectile, Green Square, and Black-Hole live state in the dense
      projectile hot path, with source-equivalent Green avoidance gating
- [x] Three Phase-2 physical-iPhone Game Performance measurements and focused
      capture verification
- [ ] Final post-Black-Hole CPU/allocation trace with the device unlocked
- [x] Active-enemy 1x/2x benchmark fixtures with aggregate Enemy AI,
      Triangle-Bond, and Black-Hole-AI signposts
- [x] Source-ordered, frame-local EnemyFrameIndex for regular enemy updates,
      same-kind separation, and Black-Hole lookups
- [x] First physical-iPhone active-enemy 1x/2x Release trace pair, with a
      60-Hz cadence check and Time-Profiler export
- [ ] Corrected 2x shot-overload trace and three repeatable runs per profile
- [x] Physical normal-game sustained-fire trace reproducing the reported
      shooting hitch and identifying synchronous one-shot audio setup
- [ ] Physical A/B trace of the installed reusable one-shot audio pool
- [x] Default-off macOS Metal prototype for Grid style 1 and Particle style 1,
      with SpriteKit fallback and an unchanged SpriteKit-only iOS path

`FIDELITY.md` is the acceptance ledger. The isolated BlitzMax harness and the
Swift port now each capture the same 136 attract, transition, gameplay, HUD,
entity, enemy-motion/lifecycle, generator, power-up, grid, particle,
player/weapon, graphics-set, and menu states. The catalog also isolates HUD
overlap order and a scrolled 1280×960 arena. The original reference checksums
are pinned, and the comparison tool verified all 136 1024×768 pairs.
Style-by-style visual
correction reduced the pixel difference for all 20 nonempty grid selectors and
made the empty selector pixel-identical. The Moiré selector still exposes a
known OpenGL per-vertex-gradient versus SpriteKit rasterization difference.
Interactive macOS smoke runs now verify start, menus, Continue, bomb,
death/respawn, final Game Over, high-score insertion and checksum persistence,
the 750-frame post-game Title return, accepted-and-restored settings, the
source pause latch/O release, attract return, runtime function keys, and actual
process termination through Exit Program. The held-P single-step branch is
covered by its source-specific deterministic rule test because the UI driver
cannot hold two non-modifier keys simultaneously. iPhone 17 Pro and iPad Air
11-inch Simulator runs additionally verify aspect-fit mobile layout, touch
start and both virtual sticks. The iPhone run also verifies BOMB,
OPT/Continue, background/foreground persistence, and the mobile Title-return
equivalent for Exit Program. A signed Debug build and XCUITest then repeated
the mobile interaction flow on a physical iPhone 17 Pro Max with iOS 26.6:
BOMB start, both virtual sticks, BOMB shockwave, OPT/Continue, Home/foreground,
and cold relaunch all passed. Seven retained test screenshots were inspected,
and the device app container held the expected 280-line `Config.txt`, 76-line
`Colours.txt`, and 150-line `hiscores.dat`. A fresh post-runtime 136-state
macOS catalog was byte-identical to the manually accepted catalog. The later
rendering-performance pass was also checked across all 136 states: 126 captures
stayed byte-identical and the remaining ten showed only isolated
raster/subpixel noise with normalized mean differences from `2.31e-9` through
`3.12e-6`; no layout, state, or layer-order regression was visible.
The complete visual review and the renderer-specific acceptance boundary are
recorded in `docs/CAPTURE-REVIEW.md`.

## Rendering-performance result (2026-08-26)

Focused Phase-1 regression captures retained the previous Swift output: six
representative persistent-screen/HUD captures were byte-identical, and pooled
particle styles 0 through 3 measured normalized mean grayscale differences of
`0`, `4.63e-9`, `0`, and `1.35e-8` from the preceding SpriteKit renderer.

For the opt-in Metal prototype, `scripts/compare-captures.sh` measured a
SpriteKit-to-Metal difference of `5.87151e-05` for Grid style 1 and `0.0016534`
for Particle style 1. Against the original reference, the Grid measurements
were `0.00198938` for Metal and `0.00205562` for SpriteKit; the particle
measurements were `0.00322177` for Metal and `0.00272125` for SpriteKit. Metal
Particle style 1 is therefore not fidelity-accepted and the prototype remains
default-off.

One final eight-second Release `Game Performance` Instruments run per renderer
used the same static 1024×768/60-Hz benchmark (Grid style 1 plus 2,048 Particle
style 1 particles). In the steady 3–8-second window, app-specific present
request spacing was SpriteKit `n=290`, p50 `16.6771 ms`, p95 `17.6055 ms`;
Metal was `n=293`, p50 `16.6548 ms`, p95 `17.3597 ms`. One-millisecond CPU
sampling averaged `1.9069 ms/frame` for SpriteKit and `1.6826 ms/frame` for
Metal. App-specific GPU-frame spans averaged `0.6752 ms` and `0.5713 ms`, while
GPU p95 was `1.2332 ms` and `1.2986 ms` respectively. This single,
vsync-limited run shows modest average CPU/GPU reductions but no material p95
frame-pacing win; the GPU p95 did not improve. Maxima and display-wide FPS are
not reliable decision inputs here.

## iOS dynamic-performance phase 1 (2026-08-30)

The immutable pre-optimization baseline is commit `aac3d9c`, tagged
`pre-ios-performance-optimization`. The first implementation phase adds a
deterministic `--ios-performance-benchmark` with 500 projectiles, a stable
dense enemy mix, a deforming Grid, 2,048 particles, and points-of-interest
signposts for display update, fixed simulation, projectile work, Grid render,
and presentation render. `--performance-stats` exposes SpriteKit's FPS, node,
draw, and quad counters.

Projectile collision candidates are now classified once at the start of an
update and reused for both half-steps of every projectile. The classification
is rebuilt after synchronous enemy-tree count changes; removed nodes are
ignored, while children spawned by a Cube split are visible to the next
half-step. The original collision-kind priority and child-list order remain
unchanged.

The macOS Debug and Release builds, generic iOS Simulator Debug build, and all
141 macOS tests pass. Five focused projectile captures measure
`0.00339833...0.00385059` normalized mean grayscale difference from the
original references, within the established accepted boundary.

Three wired iPhone 17 Pro Max Release runs now show 13.99–16.79 presentation
updates per second, median display spacing near 66.7 ms, and three to four
fixed simulation steps per display update. Projectile work measures about
16.2–16.4 ms p50 per fixed step and accounts for 91.71% of representative
main-thread samples; Green Square avoidance alone accounts for 47.07%. A
separate 30.852-second Allocations trace records 1.22 GiB and 21.27 million
heap allocations, including 224.32 MB below Green Square avoidance. GPU frame
p95 is 30.1–30.8 ms. All three runs remained at the same `Fair` thermal state.
The before/after percentage remains open because the immutable baseline
predates the benchmark harness. Detailed evidence and the revised priority are
in `docs/iOS-Performance/MEASUREMENTS-2026-08-30.md` and
`docs/iOS-Performance/PLAN.md`.

## iOS dynamic-performance phase 2 (2026-08-30)

Projectile velocity is now loaded once and carried as typed Swift state
through both half-steps, collision handling, upgrades, and Black-Hole
deflection. Green Squares keep live velocity on the typed SpriteKit node and
skip velocity reads/mutation when the source-equivalent predicted-danger
vector cannot be inside the original 100-unit avoidance radius. The allocation
trace then exposed Black-Hole size/active string-key bridging as the next
projectile hotspot, so those live values now use the same typed boundary while
`userData` remains synchronized for compatibility and capture fixtures.

Three wired Release traces reduce projectile p50 from 16.2–16.4 ms to
5.1–5.6 ms (65.7–68.3 percent). Run 1 sustains 59.99 Hz with no 33-ms frames;
runs 2 and 3 measure 53.25 and 49.69 Hz while projectile CPU remains stable.
The Green Square allocation path is absent from the Phase-2 trace. A final
post-Black-Hole trace remains pending because Instruments found the device
locked during the follow-up attempt.

All 141 macOS tests, macOS Debug/Release builds, the generic iOS Simulator
Debug build, and the signed physical-iPhone Release build pass. The five
focused projectile captures remain exactly at their previously accepted
`0.00339833...0.00385059` differences. Detailed evidence is in
`docs/iOS-Performance/MEASUREMENTS-PHASE2-2026-08-30.md`.

## Next iOS performance phase: active enemy scaling

Physical-iPhone gameplay still lags in crowded waves. The current performance
benchmark cannot measure that symptom because it freezes its 83 enemies and
its timed fixed step does not call live enemy AI. The next phase therefore
starts with a retained real-play trace and a deterministic active-enemy 1x/2x
fixture before changing implementation.

The first implementation now has a source-ordered, frame-local enemy index
with arrays by kind and a small Black-Hole list. It removes repeated child-list
filtering from regular enemy updates, same-kind separation, and Black-Hole
influence without changing update order. Triangle stable-ID lookup is
intentionally deferred. Only if physical 1x/2x traces still identify pair
checks as dominant should a source-ordered spatial broad phase be added for
projectile collision and same-kind separation. Typed enemy state, pooled
Triangle bonds, and stable presentation snapshots follow in separate measured
steps. Grid/GPU/particle work remains later until active enemy simulation is
inside budget.

The first valid paired 10-second Release traces present at 60 Hz with no
20-ms display-swap gaps or 100-ms hangs. Enemy AI rises from 0.213 ms to
0.625 ms median between the two fixtures, but projectile collision plus
Grid/presentation rendering remains more expensive. This does not reproduce
the user's hitch: the initial 2x profile unintentionally retained the normal
500-projectile cap despite requesting 1,000 shots, and it excludes Snake-tail
and guaranteed Triangle-bond churn. The benchmark-only cap correction is
installed for the follow-up; detailed evidence is in
`docs/iOS-Performance/MEASUREMENTS-ACTIVE-ENEMY-2026-08-30.md`.

The subsequent normal-game live-shooting trace does reproduce the user's
report: its retained firing window has a 150.014-ms display-swap median and a
333.364-ms maximum. Main-thread samples show `AudioFileOpenURL`,
`AVAudioPlayer.prepareToPlay`, and AudioQueue XPC work directly below
projectile-impact and enemy-destruction calls. A prewarmed polyphonic one-shot
pool is installed for the A/B run; details and presentation notes are in
`docs/iOS-Performance/MEASUREMENTS-LIVE-SHOOTING-2026-08-30.md`.

The executable plan is in `docs/iOS-Performance/PLAN.md`. Detailed technical,
risk, and data-capture notes are in
`docs/iOS-Performance/NEXT-STEPS-NOTES.md`.
