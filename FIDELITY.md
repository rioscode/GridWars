# GridWars 5.4 Fidelity Matrix

This file defines the acceptance surface for the native Swift port. A checked
item requires three forms of evidence: an original BlitzMax source reference,
the corresponding Swift implementation, and a test or visual/runtime check.

## Evidence in progress

- Player motion and weapons: `gridwars.bmx:96, 5308-5347, 5443-5604` map to
  `PlayerMotionState`, `PlayerWeaponRule`, and the player/shot update paths in
  `GameScene`. `GameRulesTests` verifies inertia, the effective six-pixel
  maximum speed caused by the original `Int = 6.5` declaration, boundary
  reversal, cannon counts, timers, shot speeds, timed shooters, and shield
  frames. Visual verification of trail, facing, and shield presentation is
  still required before checking the corresponding items.
- Player lifecycle: `gridwars.bmx:4344-4503` maps to the frame-based death and
  Get Ready states in `GameScene`: 256 death particles, non-killer removal,
  100 death frames, 60 title frames, 40 contraction frames, delayed life loss,
  respawn downgrade/reset, and 80 shield frames. Runtime capture and the full
  Game Over/high-score continuation remain outstanding.
- Gameplay entity audit: `gridwars.bmx:190-3167, 4752-4977, 5691-5777` maps to
  `SpawnDirector`, `TriangleBondState`, `SnakeSegmentRule`, `BlackHoleRule`,
  `InterceptorShieldGeometry`, and the generator/enemy/power-up/projectile
  update paths in `GameScene`. The source-order audit covers all ten enemies,
  ten generator kinds, the staged waves, collision radii, score values,
  black-hole absorption, snake chain death, interceptor blocking, triangle
  ownership, cube splitting, power-up merging, bomb cooldown, and wave reset
  on player death. Entity presentation, per-event particle recipes, spatial
  audio and matching runtime captures remain outstanding, so the broad enemy
  checklist entries stay open.
- Language semantics: `docs/bb/blitzmax-ng/brl/random.mod/random.bmx` confirms
  inclusive integer `Rand` and upper-exclusive floating-point `Rnd`; the
  archived legacy `Language/Data types.bbdoc` documents the implicit numeric
  conversions used by the original. Swift random ranges and intentional
  integer truncations follow those references.
- Build evidence (2026-08-24): the macOS unit-test action and generic iOS
  device Debug build both pass with code signing disabled. The rule suite
  covers initial difficulty, motion, weapons, scoring, upgrades, spawn timing,
  triangle bonds, snake following, black-hole integer conversions,
  interceptor geometry and generator non-kill scoring.

## Core loop and progression

- [ ] Fixed 50 Hz gameplay timing (`gridwars.bmx:3622-3704`).
- [ ] Easy, Medium, and Hard initial state and speed modifiers
      (`gridwars.bmx:4645-4750`).
- [ ] Original staged spawn scheduler, corner patterns, generators, wave caps,
      and per-minute speed increases (`gridwars.bmx:4752-4977`).
- [ ] Original score values and cumulative kill thresholds
      `25, 100, 200, 400, 800, 1600, 2500, 3500, 5000, 5500` for multipliers
      1× through 10× (`gridwars.bmx:101, 3168-3246`).
- [ ] Power-up, extra-player, and extra-bomb score thresholds and messages.
- [ ] Player death sequence, killer preservation, upgrade loss, respawn,
      shield, and game-over sequence (`gridwars.bmx:4433-4590`).
- [ ] Bomb destroys all eligible enemies without points, resets multiplier,
      distorts the grid, and grants the short shield (`gridwars.bmx:3138-3164`).

## Enemies and hazards

- [ ] Paul the Pinwheel: bounce/separation, 25 points (`nme1`).
- [ ] Dimmy the Diamond: jitter, homing, separation, 50 points (`nme2`).
- [ ] Shy the Square: projectile avoidance, homing, separation, 100 points
      (`nme`).
- [ ] Cubie the Cube: orbit motion, large/small split, 100/50 points (`nme3`).
- [ ] Sammy the Seeker: fast homing and separation, 10 points (`nme4`).
- [ ] Dwight the Black Hole: activation, growth/shrink, absorption, pull,
      collision, split explosion, dynamic score, and loop audio (`nme5`).
- [ ] Selena the Snake: 25-segment chain, head navigation, tail hits, staged
      chain explosion, 100 head points (`nme6`).
- [ ] Ivan the Interceptor: facing AI, shield cone, projectile blocking, 100
      points (`nme7`).
- [ ] Indy the Butterfly: fast homing/separation, 10 points (`nme8`).
- [ ] Trish the Triangle: pairing, elastic bond, bond collision, black-hole
      interaction, 150 points (`le`).
- [ ] Ten generator variants with original health, birth rate, warning flash,
      scoring, and geometry (`ge`).

## Player, weapons, and power-ups

- [ ] Original inertia, maximum speed, boundary response, facing, and trail.
- [ ] One through four front-cannon formations and original shot timers/speeds.
- [ ] Reverse and side shooters with exact timed duration.
- [ ] Super shots pierce; bouncy shots reflect; both retain black-hole
      interaction and their original particle colours.
- [ ] All nine power-ups: reverse, side, extra cannon, faster shots, extra
      player, extra bomb, shield, super shots, and bouncy shots (`pu`).
- [ ] Power-up selection bias, caps/2000-point fallback, aging, merging into a
      butterfly generator, and expiration into a butterfly.

## Grid, particles, and rendering

- [ ] Grid styles 0 through 20 and their exact composition
      (`gridparttrail.bmx:494-1662`).
- [ ] Configurable spacing, RGB, opacity, full-grid mode, scroll offsets, arena
      sizes, and border.
- [ ] Grid push, pull, shockwave, black-hole deformation, and reset.
- [ ] Star count/depth parallax and all four particle styles.
- [ ] Particle gravity, lifetime, decay, capacity, fireworks, trails, and
      per-entity particle recipes.
- [ ] Solid, Low, Medium, High, and User graphic sets with correct frames,
      blend modes, rotation, scale, and bloom appearance.
- [ ] Original vector font, HUD positions, score popups, shield, icons, target,
      playfield clipping, and scrolling camera.

## Screens and interaction

- [ ] Animated title/credits screen and timed attract-mode order.
- [ ] Top-scores screens for all three difficulties and settings inspection.
- [ ] “Know Your Friends” and “Know Your Enemies” screens.
- [ ] Get Ready, death, Game Over, pause/step, and exit flows.
- [ ] Options, Configure, Video, Game, Audio, Controller, Hybrid, Mouse,
      Keyboard, Joypad, and Dual Analog screens (`control.bmx`).
- [ ] Runtime F3–F7 controls and F1/F2 cheat mode with keys 1–4, X, Z, S, P,
      and O.
- [ ] Screenshot capture.

## Input

- [ ] Dual Analog, Mouse, Keyboard, Joypad, and all three Hybrid modes.
- [ ] Autofire, remappable keys/buttons, axes, inversion, scale, center, dead
      zones, joystick port selection, and calibration.
- [ ] macOS keyboard/mouse/controller equivalents.
- [ ] iPhone/iPad touch equivalents without changing gameplay rules.

## Persistence and data compatibility

- [ ] Parse and emit every original `Config.txt` field in original order.
- [ ] Parse and emit `Colours.txt` entries.
- [ ] Parse, validate, display, insert, and emit all 30 original high-score
      records and their checksum (`hiscores.dat`).
- [ ] Eight-character high-score name entry and recorded settings string.
- [ ] Use the platform application-support directory while importing legacy
      `~/.config/gridwars` data when present.

## Audio and music

- [ ] Every sound mapping in `sound.bmx:84-206` with SFX volume, distance
      attenuation, stereo pan, and pitch/rate changes.
- [ ] Eight concurrent black-hole loops and lifecycle management.
- [ ] Intro, gameplay, and high-score tracker music, looped at configured
      volume; convert only when required by AVFoundation/SpriteKit.
- [ ] Original and User sound-set selection.

## Final verification

- [ ] Pure rule tests cover difficulty, spawn scheduling, scoring, upgrades,
      persistence, checksums, and deterministic entity transitions.
- [ ] macOS and iOS builds and tests pass with Swift 6 strict concurrency.
- [ ] Automated capture scenes cover each entity, grid style, power-up, HUD,
      and menu state.
- [ ] Side-by-side captures against the BlitzMax reference have been reviewed
      at matching 1024×768 state and frame counts.
- [ ] Full playthrough smoke tests cover start, death/respawn, game over,
      high-score insertion, options persistence, and attract-mode return.
