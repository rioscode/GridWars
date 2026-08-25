# GridWars 5.4 Fidelity Matrix

This file defines the acceptance surface for the native Swift port. A checked
item requires three forms of evidence: an original BlitzMax source reference,
the corresponding Swift implementation, and a test or visual/runtime check.

## Evidence in progress

- Player motion and weapons: `gridwars.bmx:96, 4982-5604, 5963-5988`,
  `gridparttrail.bmx:2017-2080`, and `utils.bmx:178-191` map to
  `PlayerMotionState`, `PlayerTrailState`, `PlayerVisualRule`,
  `PlayerWeaponRule`, and the player/shot paths in `GameScene`. The port keeps
  the effective six-pixel maximum speed caused by the original `Int = 6.5`,
  inertia, axis-local boundary rollback and memory reversal. Facing and shot
  artwork rotations account for both the scene-Y inversion and the source
  images' opposite up/down orientation. Three trails per frame retain the
  source sine/cosine offsets, scene-inverted cosine, delayed movement/fade,
  doubled point-plus-particle composition, alpha, and additive layer order.
  The shield uses the original 18-point path, blink rule, frame-based scale,
  alpha blend, and draw order. One through four front-cannon formations,
  reverse/side shooters, source-handed angle order, speeds, and timers are
  preserved. Eight isolated references cover motion, boundary response,
  shield, all four cannon counts, and reverse/side shooting; their normalized
  differences are `0.00585720`, `0.00481007`, `0.00472743`, `0.00471062`,
  `0.00471184`, `0.00471593`, `0.00471702`, and `0.00473237`. All 115 catalog
  pairs pass, and two independent complete original runs are byte-identical.
- Projectile upgrades: `gridwars.bmx:92-93, 2882-3141, 5456-5460` and
  `colordefs.bmx:42-53` map to `ProjectileUpdateRule`,
  `ProjectileUpgradeRule`, and `GameScene.updateProjectiles`. Each projectile
  still executes two source-ordered half-steps, including collision before
  active-Black-Hole deflection and the original typo that normalizes `dx`
  twice without changing `dy`. Upgrade behavior and colour are read from the
  live global-equivalent timers on every frame; Super takes precedence when
  both timers are active. Super collisions run their enemy effects but keep
  the shot, while Bouncy reflects. Converting source bounds `0...H-1` through
  `sceneY = H-sourceY` gives the non-obvious SpriteKit interval `1...H`.
  Five isolated captures cover two-target Super piercing, that exact upper
  Bouncy boundary, a green Bouncy collision, and red/green active-Black-Hole
  deflection. Their normalized differences are `0.00516206`, `0.00470918`,
  `0.00499543`, `0.00480980`, and `0.00481247`; two Swift runs are
  byte-identical, as are two independent complete 120-state original runs.
- Power-ups: `gridwars.bmx:2570-2876, 3168-3260, 5444-5460` maps to
  `OriginalPowerUpSpawnState`, `OriginalPowerUpRule`, `GameSession`, and the
  power-up paths in `GameScene`. All nine kinds retain their exact icon frame,
  message, timed or immediate effect, cap, and multiplier-scaled 2000-point
  fallback. Source raw values now map `0/1` to Reverse/Side and `7/8` to
  Super/Bouncy without the former inversion. Random selection preserves every
  conditional BRL.Random call and need bias; position is sampled X then source
  Y before scene inversion, followed by constructor rotation, direction, and
  magnitude. Only `MakePowerUp` supplies the two-frame freeze and Grid push;
  direct construction does not. Manual squared collision replaces asynchronous
  SpriteKit contact delivery, preserving collection before the two-frame
  freeze check—including the original possibility of repeated collection
  while frozen—and the rest
  of the dying update. Same-frame shield drawing, score-threshold events,
  50-frame vector messages, and pickup audio retain source order. Lifecycle
  behavior keeps boundary correction, range-limited random homing, the
  200/300/400-frame merge/attract/expiry thresholds, list-ordered reciprocal
  attraction, per-merge particles and Butterfly generator, Reverse/Side
  expiry into a Butterfly, and active-Black-Hole force, growth, 15-particle
  `r`-oriented absorption ring, and post-removal random call. Star and icon
  aging switch independently after frames 300 and 360 to exact
  `(180,80,200)` multiplication. Nine static icons, nine collection results,
  and aged, merge, expiry, and Black-Hole captures measure respectively
  `0.00472276...0.00478242`, `0.00505081...0.00574582`, `0.00507924`,
  `0.00480415`, `0.00476707`, and `0.00492752`. Two independent complete
  original runs are byte-identical, the added Black Hole reference is
  independently byte-identical, the 134-state Swift catalog is byte-identical
  across two runs, and all 134 original/Swift pairs pass.
- Grid, stars, and particles: `gridparttrail.bmx:16-31, 298-2109`,
  `gridwars.bmx:1159-1170, 5642-5682` map to `GridSimulation`,
  `GridRenderer`, `OriginalStarRule`, `ParticleSimulation`,
  `ParticleRenderer`, `OriginalFireworkRule`, and
  `OriginalBlackHoleParticleRule`. Grid updates retain the observable
  top-to-bottom in-place traversal and all 21 selector-specific draw paths;
  the point selectors now begin major highlights at row/column four, not
  zero. The complete inclusive `0...10000` star table is created before later
  random gameplay state, with cyclic depths, truncated integer brightness,
  top-left 2×2 additive pixels, and tall-playfield parallax preserved after
  scene-Y conversion. Particle creation retains all source kinds, angle
  handedness, doubled initial velocity, gravity, decay, fading, ring-buffer
  capacity, and both arena-bound `Update` and screen-bound `UpdateWide`.
  Visual capacity now grows to every active configured slot instead of
  stopping at 2048. Fireworks preserve style-specific random-call order, and
  active Black Holes emit the missing eight slow directed particles every 60
  rotations. Five new rule tests cover star generation/parallax, generic
  angle conversion, wide bounds, edge-firework order, and the Black Hole
  recipe. The four particle captures differ by only
  `0.000187054...0.00272124`; point grids 0/1 measure `0.00281094` and
  `0.00205562`, and the new Black Hole particle state measures `0.0047782`.
  All 134 original/Swift pairs remain valid at 1024×768.
- Player lifecycle: `gridwars.bmx:4344-4503` maps to the frame-based death and
  Get Ready states in `GameScene`: 256 death particles, non-killer removal,
  100 death frames, 60 title frames, 40 contraction frames, delayed life loss,
  respawn downgrade/reset, and 80 shield frames. Matching fixed-state captures
  now cover Get Ready, death, Game Over, and high-score entry. Their capture
  setup reproduces the original pre-draw grid/particle updates, ring deformation,
  Game Over counter, and `3 mns, 21 secs` score text. A live macOS continuation
  now verifies that death hides the player, clears the active wave, enters Get
  Ready, respawns at center, and returns through Game Over to the attract score
  pages after the final life. The Get Ready title now uses the
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
  Generator capture setup now consumes the post-star BRL.Random direction
  before rotation, runs `SafeXY` in source top-left coordinates, and retains
  the player drawn by `DrawAll`. All ten generator captures improve from
  0.00516–0.00591 to 0.00475–0.00485. Generator rendering also preserves the
  inherited `LIGHTBLEND`, the eight-frame warning window, hit-dependent birth
  period, and the source's uninitialized-`sc` alpha quirk for Triangle and
  Butterfly fills. The live runtime now uses the archived BRL.Random generator
  rather than Swift's standard RNG. `SpawnDirector`, corner expansion,
  `SafeXY`, entity construction, power-up selection, particles, fireworks and
  update-time random branches therefore share the source's inclusive `Rand`
  and upper-exclusive `Rnd` state progression. Enemy construction no longer
  consumes an unused Swift-only `phase` or a Snake turn value for every kind.
  It preserves each kind's actual constructor order, including Interceptor's
  direction/magnitude/rotation order and all inert recursive Snake-tail
  rotations/direction flips. Diamond update also consumes both zero-valued
  `Rand(-0.2,0.2)` calls whenever its leading branch succeeds. Spawn positions
  are sampled in source top-left coordinates before the scene-Y conversion.
  Negating Interceptor's source rotation after that conversion lowers its
  isolated difference from `0.00488409` to `0.00471283`. Focused sequence
  tests lock these call orders. Pinwheel, Diamond, Green Square, Cube, Seeker,
  Triangle, and Butterfly rotations now apply the same scene-Y handedness
  conversion. The six basic enemies also use source-exact homing acceleration,
  squared separation tests, boundary margins and double position correction,
  speed caps, player collision thresholds, Green Square projectile avoidance,
  Cube orbit direction, and score/sound/split/particle/shockwave ordering.
  Cube splitting retains the source's constant `Rand(-30,-30)` X offset and
  inverted random Y offset. Paired captures place two enemies nine pixels
  around center and execute 30 direct update frames in both renderers. Their
  normalized differences are `0.00474285` Pinwheel, `0.00474284` Diamond,
  `0.00476267` Green Square, `0.00475674` Cube, `0.00471401` Seeker, and
  `0.00472140` Butterfly. Together with focused rule tests and the existing
  score tests, these accept the six basic enemy checklist entries; the
  compound types are accepted individually below. Dwight's audit
  now additionally locks inactive-to-active shrink behavior, 0.75 size loss,
  time-scaled absorption growth, player/projectile/enemy pull and collision
  thresholds, dynamic absorption score, eight-channel loop rate/position
  updates, and both terminal paths. Its mutual close-range force applies the
  source's sequential `ddx`/`ddy` update after scene-Y inversion; correcting
  those tangential signs moves both Black Holes to the exact reference
  positions after 30 frames. Overload children are computed and truncated in
  source coordinates before their scene-Y conversion, and its 36-particle ring
  inverts the source cosine Y offset. The shared floating-score renderer also
  reproduces `score.DrawPoints`: 30-frame life, leftward X origin, life-based
  scale/colour, vector strokes, and additive blend. Dedicated motion, terminal
  shrink, and overload captures measure `0.00471957`, `0.00503964`, and
  `0.00488539`, accepting the Black Hole checklist entry.
  Selena's audit preserves the 25-node recursive list order, source-space head
  heading with scene-inverted sine acceleration, random turn reversals,
  per-axis 90-degree boundary turns, 15-point Tail following, 24-point player
  collision radius, `81+sz` projectile threshold, persistent Tail hits, and
  the 30/300-frame scored/bomb cascade. Existing enemies now read the mutable
  global-equivalent session speed each frame, and generator-born Snakes keep
  the source's 160-point `SafeXY` because the trailing call argument is `rr`,
  not `close`. Motion, Tail-hit, and eight-step cascade captures measure
  `0.00566157`, `0.00755665`, and `0.00641933`, accepting the Snake checklist
  entry. Ivan's audit against `gridwars.bmx:1570-1775, 3078-3108` and
  `utils.bmx:193-209, 259-279` keeps `rot`/`rotdir` in source degrees, converts
  the facing acceleration to scene-handed coordinates, reads the mutable live
  speed, and preserves the two independent boundary rollbacks. The shield is
  active only at `Abs(rotdir) <= 4`; its projectile triangle comes from the
  endpoints cached by the previous `Draw`, not the current visible path. Swift
  reproduces the source's incomplete `PointInTri` literally, including its
  omitted forward edge, impossible Y branch, and mismatched denominator guard.
  Body hits, shield blocks, player collision, Black Hole absorption, 100-point
  kill path, sound cooldown and 16 particles follow source order. The animated
  three-line fan is rendered separately with the source `rot+270` transform;
  correcting its child sign removes a behind-the-ship mirror. Motion, active
  shield, and projectile-block captures measure `0.00471278`, `0.00476220`,
  and `0.00479132`. All 103 catalog pairs pass and two independent complete
  original runs are byte-identical, accepting the Interceptor checklist entry.
  Trish's audit against `gridwars.bmx:2293-2564, 3056-3065, 5608-5623` and
  `utils.bmx:240-258` preserves per-entry list-ordered pairing, the 32-point
  attach threshold, 64/150-point elastic bounds, 32-point acceleration,
  live-speed cap, eight-point bounce, 24-point player collision, and 12-point
  bond-line collision. Strength and resistance remain endpoint-local; both
  endpoints draw the same additive bond, possibly in different colours after
  a hit, and each attached sprite retains the source `r*2`/`r*4+180` pair.
  Projectile hits emit four strength-coloured particles before adding
  `shotVelocity*5/16` and subtracting 2.5 strength. A zero-strength hit detaches
  without killing; the next unattached hit takes the 150-point, shockwave,
  killed-sound, and 32-particle path. Point-free `le.Kill(False)` intentionally
  keeps that killed sound. Bonded Black-Hole handling designates one resistant
  partner even for an inactive hole, applies the scene-Y-corrected spin,
  subtracts 0.25 strength, and directly removes a broken endpoint without kill
  effects before growing the hole. Motion, elastic-bond, projectile-hit, and
  Black-Hole-break captures measure `0.00471665`, `0.00484561`, `0.00478878`,
  and `0.00485916`; the static paired capture improves to `0.00481618`. All
  107 catalog pairs pass and two independent complete original runs are
  byte-identical, accepting the Triangle checklist entry.
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
  0.02865/0.00811. Raising the continuous stretch colour/width approximation
  from 16 to 64 buckets further lowers styles 9–12 to
  0.00810/0.01939/0.02667/0.01538. The source-style hard line raster is useful
  only for style 11's closed `DrawLine` cells: disabling SpriteKit antialiasing
  there lowers it again to 0.02542, while the same change was measured and
  rejected for style 12. RGB-split style 13 likewise uses alpha 1, converts its
  red source offset from `(-4,-4)` to scene `(-4,+4)`, and uses 64 colour
  buckets to approximate the original per-vertex interpolation; its difference
  initially fell from 0.03046 to 0.02549. Restoring the source's top-left,
  clockwise traversal, its repeated bottom-right corner, shrink-after-left
  order, and side-specific red displacement test lowers it again to 0.01446.
  Increasing only the per-cell source-value
  approximation for filled stretched/sine quads from 16 to 64 levels lowers
  styles 16 and 17 from 0.02980/0.01852 to 0.02924/0.01746; changing their
  SpriteKit fill alpha was measured and rejected as a regression. Preserving
  every original `DrawPoly` as a separate additive node subsequently lowers
  styles 14, 15, and 16 to 0.01030, 0.00741, and 0.02861. Restoring style 17's
  source top-to-bottom alpha sequence at the same time lowers it to 0.00835.
  Moiré style 18 now maps the top-down source row into scene order and keeps
  the raw-OpenGL triangle at the cell's bottom-right corner after Y inversion;
  the former top-right triangle was a double inversion. Six bounded colour
  subdivisions and the measured additive alpha compensation approximate the
  unavailable OpenGL Gouraud fill, lowering its difference from 0.07842 to
  0.03088. Twelve subdivisions were slower and slightly worse.
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
  metric was 0.02025. Correcting the scene-Y handedness of black-hole
  tangential forces lowers it to 0.01633, and applying Max2D's line pixel
  center only to the static title credits lowers it again to 0.01489. The
  overdrawn logo remains unshifted because the same offset regresses its
  isolated region. Across the new
  97-state catalog this common correction improves screens including top
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
  renderer now produces 134 valid full-frame 1024×768 attract, transition,
  gameplay, HUD, entity, enemy-motion/lifecycle, generator, power-up, grid,
  particle, player/weapon, graphics-set, and menu references via
  `scripts/capture-original.sh`;
  capture mode bypasses all
  legacy configuration and high-score I/O. A persistence-free Swift catalog
  covers the same 134 states via `scripts/capture-screens.sh`, and
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
  `BlitzMaxRandomNumberGenerator` reproduces the archived algorithm. Both the
  live runtime and capture harness consume it in source order for spawning,
  corner selection, `SafeXY`, entity construction, colour cycling, fireworks,
  power-ups, enemy update branches, and particle creation. Fixed integer,
  double, 64-bit, enemy-constructor, recursive Snake, Diamond-jitter and
  generator-frame vectors lock the sequence. The
  archived legacy `Language/Data types.bbdoc` documents the implicit numeric
  conversions used by the original. Swift random ranges and intentional
  integer truncations follow those references.
- Build evidence (2026-08-25): the macOS unit-test action (119 tests) and generic
  iOS Simulator Debug build both pass. The rule suite
  covers initial difficulty, motion, weapons, scoring, upgrade effects,
  power-up selection/spawn/lifecycle thresholds, spawn timing,
  triangle bonds, snake following, black-hole integer conversions,
  interceptor geometry, generator non-kill scoring, grid deformation and the
  original particle ring, star creation/parallax, wide particle bounds,
  firework order, Black Hole ambient particles, legacy persistence, checksum
  handling, and
  high-score name entry, audio manifest/spatial mixing, readable lossless
  tracker conversions, all five input modes, remapping, calibration, touch
  equivalence, graphics-set metadata, original menu text/controller direction,
  and fixed-frame capture selection.

## Core loop and progression

- [x] Fixed 50 Hz gameplay timing (`gridwars.bmx:3622-3704`).
- [x] Easy, Medium, and Hard initial state and speed modifiers
      (`gridwars.bmx:4645-4750`).
- [x] Original staged spawn scheduler, corner patterns, generators, wave caps,
      and per-minute speed increases (`gridwars.bmx:4752-4977`).
- [x] Original score values and cumulative kill thresholds
      `25, 100, 200, 400, 800, 1600, 2500, 3500, 5000, 5500` for multipliers
      1× through 10× (`gridwars.bmx:101, 3168-3246`).
- [x] Power-up, extra-player, and extra-bomb score thresholds.
- [x] Original bottom status message position, colour, midpoint threshold
      refresh, and 180-frame fade after multiplier reset
      (`gridwars.bmx:3205-3213, 5784-5794`). The dedicated 1024×768 reference
      pair measures `0.00513419` across the complete frame.
- [x] Player death sequence, killer preservation, upgrade loss, respawn,
      shield, and game-over sequence (`gridwars.bmx:4433-4590`).
- [x] Bomb destroys all eligible enemies without points, resets multiplier,
      distorts the grid, and grants the short shield (`gridwars.bmx:3138-3164`).

## Enemies and hazards

- [x] Paul the Pinwheel: bounce/separation, 25 points (`nme1`).
- [x] Dimmy the Diamond: jitter, homing, separation, 50 points (`nme2`).
- [x] Shy the Square: projectile avoidance, homing, separation, 100 points
      (`nme`).
- [x] Cubie the Cube: orbit motion, large/small split, 100/50 points (`nme3`).
- [x] Sammy the Seeker: fast homing and separation, 10 points (`nme4`).
- [x] Dwight the Black Hole: activation, growth/shrink, absorption, pull,
      collision, split explosion, dynamic score, and loop audio (`nme5`).
- [x] Selena the Snake: 25-segment chain, head navigation, tail hits, staged
      chain explosion, 100 head points (`nme6`).
- [x] Ivan the Interceptor: facing AI, shield cone, projectile blocking, 100
      points (`nme7`).
- [x] Indy the Butterfly: fast homing/separation, 10 points (`nme8`).
- [x] Trish the Triangle: pairing, elastic bond, bond collision, black-hole
      interaction, 150 points (`le`).
- [x] Ten generator variants with original health, birth rate, warning flash,
      scoring, and geometry (`ge`).

## Player, weapons, and power-ups

- [x] Original inertia, maximum speed, boundary response, facing, and trail.
- [x] One through four front-cannon formations and original shot timers/speeds.
- [x] Reverse and side shooters with exact timed duration.
- [x] Super shots pierce; bouncy shots reflect; both retain black-hole
      interaction and their original particle colours.
- [x] All nine power-ups: reverse, side, extra cannon, faster shots, extra
      player, extra bomb, shield, super shots, and bouncy shots (`pu`).
- [x] Power-up selection bias, caps/2000-point fallback, aging, merging into a
      butterfly generator, and expiration into a butterfly.

## Grid, particles, and rendering

- [x] Grid styles 0 through 20 and their exact composition
      (`gridparttrail.bmx:494-1662`).
- [x] Configurable spacing, RGB, opacity, full-grid mode, scroll offsets, arena
      sizes, and border.
- [x] Grid push, pull, shockwave, black-hole deformation, and reset.
- [x] Star count/depth parallax and all four particle styles.
- [x] Particle gravity, lifetime, decay, capacity, fireworks, trails, and
      per-entity particle recipes.
- [ ] Solid, Low, Medium, High, and User graphic sets with correct frames,
      blend modes, rotation, scale, and bloom appearance.
- [ ] Original vector font, HUD positions, score popups, shield, icons, target,
      playfield clipping, and scrolling camera.

## Screens and interaction

- [ ] Animated title/credits screen and timed attract-mode order.
- [ ] Top-scores screens for all three difficulties and settings inspection.
- [ ] “Know Your Friends” and “Know Your Enemies” screens.
- [x] Get Ready, death/respawn, Game Over, and attract-mode return.
- [ ] Pause/step and exit flows.
- [ ] Options, Configure, Video, Game, Audio, Controller, Hybrid, Mouse,
      Keyboard, Joypad, and Dual Analog screens (`control.bmx`).
- [x] Runtime F3–F7 controls and F1/F2 cheat mode with keys 1–4, X, Z, S, P,
      and O.
- [x] Screenshot capture.

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
- [x] Interactive macOS smoke testing covers attract start, Get Ready, live
      gameplay, movement/fire input, Options → Settings → Controls, Continue,
      bomb count/grid distortion, death cleanup, respawn, final Game Over,
      attract return, and F3–F7/F1 runtime controls.
- [ ] Side-by-side captures against the BlitzMax reference have been reviewed
      at matching 1024×768 state and frame counts.
- [ ] Full playthrough smoke tests cover start, death/respawn, game over,
      high-score insertion, options persistence, and attract-mode return.
