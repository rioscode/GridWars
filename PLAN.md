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

The source-level implementation audit is complete on the `codex/swift-port`
branch. Each major fidelity milestone has its own commit:

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
- [x] macOS Debug build
- [x] Generic iOS Simulator Debug build
- [x] 62 gameplay, input, persistence, audio, and rendering-rule unit tests
- [x] macOS launch and rendering smoke test

`FIDELITY.md` is the acceptance ledger. Automated fixed-state capture support
is implemented, but authoritative 1024×768 side-by-side review still requires
an active unlocked macOS window session and a runnable BlitzMax reference
binary. A full manual playthrough on physical iPhone/iPad hardware also remains
verification work; these evidence gaps are not represented as completed 1:1
proof.
