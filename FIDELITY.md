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
  respawn downgrade/reset, and 80 shield frames. Matching fixed-state captures
  now cover Get Ready, death, Game Over, and high-score entry. Their capture
  setup reproduces the original pre-draw grid/particle updates, ring deformation,
  Game Over counter, and `3 mns, 21 secs` score text; a full interactive
  continuation check remains outstanding. The Get Ready title now uses the
  original vector-font formula and the three contracting rings use the integer
  midpoint-circle `Plot` algorithm from `utils.bmx`. Because the original
  capture hook runs before `Flip`, its PNG contains the preceding frontbuffer;
  the matching Swift references therefore render title frame 29 and ring frame
  19 (catalog frame 79), not the loop counters 30/20. This correction reduced
  normalized differences from 0.01828 to 0.01666 and from 0.02529 to 0.02175.
  `GetReady()` also calls `UpdateGrid()` directly before `UpdateAll()` performs
  a second Grid update on every displayed frame. The live sequence and capture
  harness now preserve that order, including applying the ring pull before both
  updates; the current ring difference falls from 0.01628 to 0.01009 while the
  title frame remains unchanged at 0.00558 after the shared Grid-anchor fixes.
  The midpoint-circle `Plot` pixels also reuse the tested top-left `DrawRect`
  conversion (`sceneY = -sourceY-1` for a relative 1×1 point), lowering the
  ring frame again from 0.01009 to 0.00725.
- Gameplay entity audit: `gridwars.bmx:190-3167, 4752-4977, 5691-5777` maps to
  `SpawnDirector`, `TriangleBondState`, `SnakeSegmentRule`, `BlackHoleRule`,
  `InterceptorShieldGeometry`, and the generator/enemy/power-up/projectile
  update paths in `GameScene`. The source-order audit covers all ten enemies,
  ten generator kinds, the staged waves, collision radii, score values,
  black-hole absorption, snake chain death, interceptor blocking, triangle
  ownership, cube splitting, power-up merging, bomb cooldown, and wave reset
  on player death. The 2048-slot `ParticleSimulation` now reproduces every
  gameplay emission recipe and colour from `gridwars.bmx`/`colordefs.bmx`.
  Enemy sprite transforms, per-kind auras, generator fill/outline geometry,
  warning flashes and attract-screen animation rates are now source-matched.
  The original and Swift capture catalogs expose matching isolated states for
  all ten enemies and generators. The isolated enemy player's source Y=100 is
  now converted to SpriteKit coordinates, improving all ten enemy captures by
  2.6–3.4%. The Snake fixture also reproduces `Sin(segmentIndex*20)` in degrees,
  with the source tail index and inverted scene Y; its normalized difference
  fell from 0.02209 to 0.01977. Matching BlitzMax's `ATan2(0,0)+90` first-draw
  result now gives every initially stationary tail segment a 90-degree
  rotation; the current catalog difference fell again from 0.01896 to 0.01830.
  Pairwise visual correction is still in progress, so the broad enemy
  checklist entries stay open.
- Grid and particle simulation: `gridparttrail.bmx:494-2017` maps to
  `GridSimulation`, `GridRenderer`, `ParticleSimulation`, and
  `ParticleRenderer`. The port has all 21 grid-style selectors, the original
  configurable 4/8/16/32-pixel point lattice and in-place spring update,
  push/pull/shockwave impulses, configurable particle-ring capacity, four
  particle render selectors,
  half-ring black-hole gravity, lifetime/decay/bounce behaviour, and exact
  gameplay emission counts. Unit tests cover lattice impulses, reset and
  damping plus particle lifetime, wrap, colour fade, palette and black-hole
  parity. The Grid update traverses visible rows in the original top-to-bottom
  order despite SpriteKit's inverted world y-axis, and a regression test locks
  the resulting in-place asymmetry. The renderer now follows each selector's
  source draw topology, excluded boundary rows/columns, alternating-cell phase,
  stretch colour/width formula, additive overdraw, original `particle.png`
  composition, and fixed-50-Hz animation phase. Compared with the catalog from
  before this source correction, all 20 nonempty selector metrics improved, the
  empty selector is now pixel-identical, and style 14 fell from 0.2501 to
  0.01364 normalized mean absolute difference. The Moiré selector remains open:
  its source-equivalent subdivided
  gradient is visually close, but SpriteKit's triangle rasterization still
  differs from the original OpenGL per-vertex gradient (0.07842). The four
  particle render paths now separately use
  the original doubled line vectors, line widths/alpha, half-scale 7.5-pixel
  image, and style-3 line-plus-stretched-image bloom. Their isolated differences
  are 0.00236, 0.00272, 0.00019, and 0.00265. The first value fell from 0.00775
  after applying the same `(x+0.5,y-0.5)` OpenGL pixel-center conversion as the
  direct one-pixel grid strokes; applying that conversion to the wide style-1
  and style-3 lines lowers them from 0.00870 and 0.00806. Compensating their
  source alpha for SpriteKit's additive premultiplication produces the final
  values above. Disabling SpriteKit line antialiasing and compensating the
  style-3 texture alpha were measured separately and rejected as regressions.
  The style-0 correction also lowers the title capture from 0.02116 to 0.02025.
  Two independent style-3 Swift
  captures are byte-identical. The isolated Grid/particle harness also hides
  the gameplay arena border, matching the direct original draw path and making
  the empty grid selector pixel-identical. Vertical particle boundary checks
  now apply the algebraic Y inversion of BlitzMax's top-down comparisons before
  updating SpriteKit coordinates; a focused two-edge test locks both reflected
  velocities, and the title difference improved from 0.021183 to 0.021162.
  Point-grid rectangles now preserve BlitzMax `DrawRect(x,y,w,h)`'s top-left
  anchor instead of centering SpriteKit paths around `(x,y)`; the scene-space Y
  origin is therefore `point.y-height`. This lowers isolated styles 0 and 1
  from 0.01175/0.00878 to 0.00294/0.00213, gameplay from 0.01594 to 0.00584,
  and Game Over from 0.01671 to 0.00663. Stroked OpenGL vertices require the
  complementary pixel-center translation `(x+0.5,y-0.5)` after scene-Y
  inversion. Limiting it to the direct OpenGL-derived stretched edge, checker,
  and diagonal paths lowers style 10 from 0.02550 to 0.01946, style 11 from
  0.03442 to 0.02676, and style 12 from 0.02091 to 0.01539; applying the shift
  to the Max2D-backed line styles was measured and rejected as a regression.
  The dense-mesh paths also preserve their distinct raw-OpenGL alpha behavior:
  style 8 carries Max2D's source alpha through SpriteKit's premultiplied
  additive node using `sqrt(alpha)`, while style 9's explicit `glColor3f`
  resets alpha to 1. Their differences fall from 0.03074/0.00935 to
  0.02865/0.00811. RGB-split style 13 likewise uses alpha 1, converts its red
  source offset from `(-4,-4)` to scene `(-4,+4)`, and uses 64 colour buckets
  to approximate the original per-vertex interpolation; its difference falls
  from 0.03046 to 0.02549. Increasing only the per-cell source-value
  approximation for filled stretched/sine quads from 16 to 64 levels lowers
  styles 16 and 17 from 0.02980/0.01852 to 0.02924/0.01746; changing their
  SpriteKit fill alpha was measured and rejected as a regression.
- Screens and runtime controls: `gridwars.bmx:3622-4319, 5383-5439` and
  `control.bmx:889-2570` map to `OriginalScreenFlow`, `OriginalMenuModel`,
  `OriginalVectorFont`, `OriginalScreenRenderer`, and the presentation/input
  paths in `GameScene`. The four attract pages use the original 900/750/900/900
  frame durations, Game Over uses 179 display frames, and every original menu
  branch is represented. Each menu now uses its fixed `control.bmx` title/row
  coordinates, 50 Hz colour/cursor animation, meter geometry, colour-picker
  sheet and captured-game scaling; Joypad and the original 640-wide Dual Stick
  configuration have dedicated layouts. Video and Game settings now use the
  original `Keep Changes?` transaction, including selective video rollback and
  the return-code-2 game termination after accepting changes during play.
  Attract and Game Over continuation now accepts only the configured BOMB key,
  mouse button, or controller button, while Escape/configured OPTION opens the
  menu; iOS exposes dedicated BOMB and OPT touch targets on those screens.
  F3-F7, F1/F2, the 1-4/X/Z/S cheat actions and the
  P-held/O-single-step loop are wired to the original macOS key positions;
  pause preserves the last gameplay frame without adding a non-original
  overlay.
  Rule tests cover timing, hierarchy, 0...10,000 star wrap, 119-step grid
  brightness, invalid-score state, 450-frame cheat grants, caps, and the
  original debug weapon patterns. `OriginalCameraRule` and the scene now apply
  the configured arena size, forced scrolling for oversized playfields, the
  original integer 500-pixel edge acceleration, ±80 overscroll, pointer-space
  conversion, and depth-divided star parallax. Matching original and Swift
  captures now cover every menu and transition. The four 600-frame attract
  references execute their actual per-page source order, including score/friend
  colour trails, firework aging, the title's two display black holes, particle
  gravity, and delayed title-particle start. Against the immediately preceding
  full catalog, normalized differences fell from 0.03220 to 0.02118 (title),
  0.01779 to 0.00723 (scores), 0.01565 to 0.00968 (friends), and 0.01396 to
  0.01055 (enemies). Two independent title captures are byte-identical. Further
  style-by-style correction is still required before checking the broad screen
  and menu entries. The Dual Stick page now uses the exact archived
  `brl/max2d.mod/blitzfont.bin` 8×16 glyph data used by BlitzMax `DrawText`,
  direct 8-bit text/fill colours, the original outlined command boxes and oval
  stick indicators, and the source's `1/128/255` scale values (while preserving
  its displayed `180` typo). Its normalized difference fell from 0.03857 to
  0.00881; the embedded font bytes have the same SHA-256 as the official file.
  Classic `Rect(...,0)` outlines now use hard, non-antialiased OpenGL pixel
  centers. A complete 16-menu regression pass worsened no capture: Game falls
  from 0.00521 to 0.00480, Hybrid from 0.00720 to 0.00691, Audio from 0.00375
  to 0.00366, and Joypad from 0.00423 to 0.00399; unaffected pages remain
  byte-identical to the preceding Swift catalog. The rotating target cursor
  also preserves Max2D `DrawLine`'s historical shared-start transform instead
  of drawing centered spokes. Its isolated bounds now match the original
  23×23 pixels; all 16 menus improve again, including Dual Analog to 0.00870,
  Joypad to 0.00391, and Options to 0.00147. Capture-time Joypad placement uses
  the original raw `(0,0)` mouse position while live selection placement is
  unchanged.
  The Video Settings preview now uses `DrawGrid(..., True)`'s exact 48×36
  source window at the `SCREENW/8`, `SCREENH/8` inset, hides the stars and arena
  border that the original page never draws, exposes the original 35 screen
  modes and their historical `/34` display, and preserves capture counter 20
  plus the unmoved top-edge pointer. Its normalized difference fell from
  0.02188 to 0.00877. Normal vector-font strokes now disable SpriteKit
  antialiasing and use the rectangular caps and miter joins of the original
  OpenGL line path. The multiply-overdrawn animated title keeps its stable
  smooth SpriteKit approximation; after the particle-line pixel correction its
  metric is 0.02025. Across the new
  87-state catalog this common correction improves screens including top
  scores (0.00708 to 0.00641), options (0.00194 to 0.00151), and high-score
  entry (0.01006 to 0.00819). Two independently rendered high-score-entry
  captures have identical SHA-256 hashes.
- Graphics and HUD: `images.bmx:34-100`, `gridwars.bmx:3266-3272, 5911-5932`,
  and the deterministic fixed-frame original images in
  `docs/captures/original/` map to
  `OriginalGraphics`, `OriginalHUDRenderer`, `OriginalScreenRenderer`, and the
  live texture-reload path in `GameScene`. All five original graphics folders
  are bundled without flattening, icon/snake animation sheets retain their
  set-specific frame sizes, and textures load by CGImage pixel dimensions so
  the 120-DPI metadata in Solid/Low assets cannot shrink game sprites. White
  entity art is no longer palette-tinted. Deterministic gameplay captures now
  recreate all 10,001 source star coordinates with BRL.Random, consuming the
  complete sequence before entity creation, and apply each entity's initial
  `Draw` rotation/scale before its first update. Stars now also preserve
  `SetScale(2,2); DrawRect(...,1,1)` as top-left-anchored 2×2 pixels, use
  `LIGHTBLEND`, and compensate SpriteKit's additive node-alpha
  premultiplication. Twelve representative captures all improve: gameplay
  falls from 0.00584 to 0.00516, default HUD from 0.00538 to 0.00470, Get Ready
  rings from 0.00725 to 0.00658, death from 0.00836 to 0.00769, Snake from
  0.00821 to 0.00754, and the high graphics set from 0.00609 to 0.00542. The
  vertical two-frame
  `icons.png` sheet is sliced as 1×2 rather than 2×1, and the white power-up
  star receives the live `rcol/gcol/bcol` multiplication used by BlitzMax.
  These common fixes lowered gameplay from 0.01838 to 0.01595 and all five
  graphics-set captures to 0.01588–0.01620. The score, high score, multiplier,
  lives and bomb indicators use the original vector font, coordinates, alpha
  and icon frames. The isolated original
  renderer now produces 87 valid full-frame 1024×768 attract, transition,
  gameplay, HUD, entity, generator, power-up, grid, particle, graphics-set, and
  menu references via `scripts/capture-original.sh`; capture mode bypasses all
  legacy configuration and high-score I/O. A persistence-free Swift catalog
  covers the same 87 states via `scripts/capture-screens.sh`, and
  `scripts/compare-captures.sh` measures every matching pair. Two independent
  complete original runs produced byte-identical PNGs. Enemy
  pages reproduce the original individual rotation, pulse and squash rates,
  while the score and friend pages retain their delayed colour trails instead
  of applying a uniform palette tint.
- Persistence and legacy data: `control.bmx:218-872`,
  `gridwars.bmx:3275-3610`, and `utils.bmx:46-74` map to
  `LegacyPersistence`, the high-score presentation in `GameScene` and
  `OriginalScreenRenderer`, and scene-phase saves in `GameView`. The Swift
  codecs preserve the original 280-line configuration order, all 19 colour
  records, all 30 score records and their byte-sum checksum, the strict
  insertion rule, eight-character name entry, play-time text, and recorded
  settings string. Fixture and store tests exercise round trips, corruption
  reset, legacy import, and Application Support writes; the loaded colour
  palette is applied to sprites, HUD, projectiles, generators, and particles.
- Audio: `sound.bmx:1-355` and every `PlaySound2` call in
  `gridwars.bmx:190-5604` map to `OriginalSoundEffect`,
  `OriginalSpatialAudio`, `OriginalAudioEngine`, and the entity lifecycle in
  `GameScene`. All shipped mappings use the original effect, rate, playfield-
  relative pan and attenuation; the archive's referenced-but-missing
  `shieldwarning.wav` remains intentionally silent just as its null BlitzMax
  `TSound` did. Eight rate-shifted black-hole loop channels are supported.
  Theme0/1/2 were rendered from the preserved Impulse Tracker modules to
  lossless 44.1-kHz stereo ALAC for AVFoundation, and the Original/User sound
  set plus SFX/music volume controls update the live engine.
- Input: `gridwars.bmx:4982-5321`, `control.bmx:2187-3389`, and
  `utils.bmx:286-399` map to `OriginalInputResolver`, `PlayerMotionState`, the
  controller polling/input paths in `GameScene`, the macOS event bridge in
  `GameView`, and the configuration pages in `OriginalMenuModel`. The five
  device modes and all three Hybrid variants preserve the original movement,
  retained-autofire aim, mouse sensitivity divisor, configured bomb/option
  buttons, four-button/D-pad swap, axis formula, paired dead zones and port
  behavior. Apple GameController supplies 15 legacy axis slots and 16 button
  slots; macOS events translate to the original 8...255 key namespace; iOS
  twin sticks feed the same movement/weapon rules. Nine focused rule tests
  cover the modes, remapping, calibration, and touch equivalence.
- Language semantics: `docs/bb/blitzmax-ng/brl/random.mod/random.bmx` confirms
  inclusive integer `Rand`, upper-exclusive floating-point `Rnd`, and the
  Park–Miller state plus two-state `RndDouble` construction. The Swift
  `BlitzMaxRandomNumberGenerator` reproduces the archived algorithm and the
  capture harness consumes it in the same call order for colour cycling,
  fireworks, and particle creation; fixed integer, double, and 64-bit test
  vectors lock the sequence. The
  archived legacy `Language/Data types.bbdoc` documents the implicit numeric
  conversions used by the original. Swift random ranges and intentional
  integer truncations follow those references.
- Build evidence (2026-08-25): the macOS unit-test action (78 tests) and generic
  iOS Simulator Debug build both pass. The rule suite
  covers initial difficulty, motion, weapons, scoring, upgrades, spawn timing,
  triangle bonds, snake following, black-hole integer conversions,
  interceptor geometry, generator non-kill scoring, grid deformation and the
  original particle ring, legacy persistence, checksum handling, and
  high-score name entry, audio manifest/spatial mixing, readable lossless
  tracker conversions, all five input modes, remapping, calibration, touch
  equivalence, graphics-set metadata, original menu text/controller direction,
  and fixed-frame capture selection.

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
- [x] Configurable spacing, RGB, opacity, full-grid mode, scroll offsets, arena
      sizes, and border.
- [x] Grid push, pull, shockwave, black-hole deformation, and reset.
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
- [x] Runtime F3–F7 controls and F1/F2 cheat mode with keys 1–4, X, Z, S, P,
      and O.
- [ ] Screenshot capture.

## Input

- [x] Dual Analog, Mouse, Keyboard, Joypad, and all three Hybrid modes.
- [x] Autofire, remappable keys/buttons, axes, inversion, scale, center, dead
      zones, joystick port selection, and calibration.
- [x] macOS keyboard/mouse/controller equivalents.
- [x] iPhone/iPad touch equivalents without changing gameplay rules.

## Persistence and data compatibility

- [x] Parse and emit every original `Config.txt` field in original order.
- [x] Parse and emit `Colours.txt` entries.
- [x] Parse, validate, display, insert, and emit all 30 original high-score
      records and their checksum (`hiscores.dat`).
- [x] Eight-character high-score name entry and recorded settings string.
- [x] Use the platform application-support directory while importing legacy
      `~/.config/gridwars` data when present.

## Audio and music

- [x] Every sound mapping in `sound.bmx:84-206` with SFX volume, distance
      attenuation, stereo pan, and pitch/rate changes.
- [x] Eight concurrent black-hole loops and lifecycle management.
- [x] Intro, gameplay, and high-score tracker music, looped at configured
      volume; convert only when required by AVFoundation/SpriteKit.
- [x] Original and User sound-set selection.

## Final verification

- [x] Pure rule tests cover difficulty, spawn scheduling, scoring, upgrades,
      persistence, checksums, and deterministic entity transitions.
- [x] The macOS app/test action and generic iOS Simulator build pass with
      Swift 6 strict concurrency.
- [x] Automated capture scenes cover each entity, grid style, power-up, HUD,
      and menu state.
- [ ] Side-by-side captures against the BlitzMax reference have been reviewed
      at matching 1024×768 state and frame counts.
- [ ] Full playthrough smoke tests cover start, death/respawn, game over,
      high-score insertion, options persistence, and attract-mode return.
