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
- SpriteKit for rendering, physics, particles, and audio playback
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
they can be tested without rendering.

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

## Definition of done for the first milestone

- `xcodebuild` succeeds for the macOS scheme.
- `xcodebuild` succeeds for an available iOS Simulator destination.
- Gameplay unit tests pass.
- The player can move, aim, shoot, use a bomb, defeat enemies, collect a
  power-up, gain score, lose lives, reach game over, and restart.
- `README.md` explains how to build and run the Swift port.

## Current status

The source-level implementation inventory is complete on the
`codex/swift-port` branch. Behavioural acceptance continues one subsystem at a
time, and each completed fidelity milestone has its own commit:

- [x] Shared SwiftUI/SpriteKit app sources
- [x] macOS keyboard and mouse input
- [x] iOS twin-stick touch input
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
- [ ] Physical iPhone/iPad gameplay and lifecycle smoke test
- [x] 127 gameplay, input, persistence, audio, and rendering-rule unit tests
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

`FIDELITY.md` is the acceptance ledger. The isolated BlitzMax harness and the
Swift port now each capture the same 136 attract, transition, gameplay, HUD,
entity, enemy-motion/lifecycle, generator, power-up, grid, particle,
player/weapon, graphics-set, and menu states. The catalog also isolates HUD
overlap order and a scrolled 1280×960 arena. The original reference checksums
are pinned, and the comparison tool verified all 136 1024×768 pairs.
Style-by-style visual
correction reduced the pixel difference for all 20 nonempty grid selectors and
made the empty selector pixel-identical. The Moiré selector still exposes a
known OpenGL per-vertex-gradient versus SpriteKit rasterization difference. An
interactive macOS smoke runs now verify start, menus, Continue, bomb,
death/respawn, final Game Over, high-score insertion and checksum persistence,
the 750-frame post-game Title return, accepted-and-restored settings, the
source pause latch/O release, attract return, runtime function keys, and actual
process termination through Exit Program. The held-P single-step branch is
covered by its source-specific deterministic rule test because the UI driver
cannot hold two non-modifier keys simultaneously. Physical iPhone/iPad
hardware remains the final platform gate; this evidence gap is not represented
as completed 1:1 proof. The complete visual review and the renderer-specific
acceptance boundary are recorded in `docs/CAPTURE-REVIEW.md`.
