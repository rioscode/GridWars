# BlitzMax-to-Swift Rewrite Notes

This document records the non-obvious rules discovered while reproducing
GridWars 5.4 with Swift, SpriteKit, and SwiftUI. It is intended to make a future
rewrite repeatable. The original `.bmx` source remains authoritative;
`FIDELITY.md` records the current implementation and evidence.

## Source map

Start with these files instead of translating the program in file order:

- `gridwars.bmx`: game states, entities, combat, HUD, attract screens, timing;
- `gridparttrail.bmx`: grid simulation/rendering, particles, stars;
- `control.bmx`: menus, controls, persistence, target cursor;
- `vectorfont.bmx`: vector glyph data and drawing order;
- `images.bmx`, `sound.bmx`, and `colordefs.bmx`: assets and mappings;
- `utils.bmx`: numeric helpers and historical conversion behavior.

The archived BlitzMax, BRL Max2D, and BlitzBasic references are in `docs/bb/`.
In particular, consult the archived Max2D implementation as well as its prose
documentation: driver behavior can matter more than a command's public
description.

## Coordinate systems

BlitzMax uses a top-left origin with positive Y downward. SpriteKit uses a
bottom-left origin with positive Y upward. For an arena of height `H`:

```text
sceneX = sourceX
sceneY = H - sourceY
velocitySceneY = -velocitySourceY
```

Do not apply this conversion twice. Keep simulation state consistently in one
coordinate system and isolate conversions at source-facing boundaries.

Max2D rectangles use their top-left coordinate. A source rectangle
`DrawRect(x,y,w,h)` becomes:

```text
CGRect(x: x, y: H - y - h, width: w, height: h)
```

`SKShapeNode(rectOf:)` is center-anchored and is therefore wrong for this case.
The port centralizes the conversion in `OriginalDrawRectRule`.

After Y inversion, direct OpenGL line vertices require the complementary pixel
center translation `(x+0.5, y-0.5)`. This is not a universal SpriteKit offset:
apply it only to source paths proven to be direct OpenGL/Max2D stroke raster.
The port centralizes it in `OriginalLineRasterRule`.

Examples that required top-left anchoring are point-grid rectangles, midpoint
circle `Plot` pixels, and stars. The source draws stars with
`SetScale(2,2); DrawRect(...,1,1)`, so the visible result is a 2×2 top-left
pixel block, not a centered 2×2 node.

Star creation and drawing use different coordinate stages. Create the complete
inclusive `0...MAXSTARS` table up front, even when only 301 stars are visible.
The original creates this table from the default random stream before reseeding
gameplay, so preserve that separate initialization lifecycle as well as the
number of calls.
For a source star `(x,y)` with depth `d`, a scene-space base suitable for a
world node translated by the camera is
`(x, screenH-y+(playfieldH-screenH)/d)`. Then subtract the scene camera offset
by `1/d`. This reproduces the original `stary-gyoff/d` for playfields taller
than the screen. Brightness is an integer assignment of `480/d`, truncated
before clamping to 255; keeping it as an untruncated floating channel changes
the shallow star levels.

The ordinary world camera uses the source X offset unchanged. Its scene Y
offset is the complement `playfieldH - screenH - sourceGYOffset`. Keep HUD and
fixed controls outside this translated world, and crop the world at the
1024×768 viewport. This preserves both negative source overscroll and the
source-space top-left Y convention.

The original presentation is a fixed landscape game. On iPadOS, declaring
only the two landscape orientations without `UIRequiresFullScreen` triggers a
device-build validation warning because multitasking applications are expected
to support every orientation. Declare the mobile target as requiring full
screen in both Debug and Release. This preserves the 4:3 aspect-fit arena and
prevents a platform windowing requirement from silently broadening the
original orientation contract.

Run source-space helpers in source space. `SafeXY` clamps and offsets a
top-left-Y position, and its non-close branch chooses
`Rand(0, 360 * 8) / 8.0` before applying `Sin` to X and `Cos` to Y. Convert the
incoming SpriteKit point to top-left coordinates, execute that algorithm, and
flip Y only on return. Changing the sign inside an otherwise scene-space copy
does not preserve its clamp and retry behavior.

## Transforms and angles

BlitzMax angles are expressed in degrees. SpriteKit rotations use radians.
Remember that the scene-Y inversion changes the apparent rotation direction.
For source draw angles the direct conversion is
`sceneRadians = -sourceDegrees * pi / 180`; applying only the degree-to-radian
factor mirrors rotating enemies. The same Y inversion changes a Cube's source
orbit `(sin(angle)*tier, cos(angle)*tier)` to scene
`(sin(angle)*tier, -cos(angle)*tier)`.
Use `atan2`, not `atan(dy/dx)`, except where the original explicitly used the
latter and its divide-by-zero behavior is part of the result.

The same handedness change applies to tangential forces, not just displayed
angles. For a BlitzMax force term `(dx - dy/spin, dy + dx/spin)`, a simulation
stored in SpriteKit coordinates needs the Y-inverted equivalent
`(dx + dy/spin, dy - dx/spin)`. The title-screen particle spirals and gameplay
black holes expose this difference clearly; copying the source signs verbatim
makes their rotation run mirrored.

Preserve sequential assignments while deriving those signs. Black Hole mutual
repulsion first replaces source `ddx`, then computes source `ddy` using that
new value. In scene coordinates its close-range pair becomes
`dx = -dx + dy*0.25`, followed by `dy = -dy + dx*0.25`; calculating both from
the old vector or copying the two source minus signs mirrors the orbit.

Preserve first-draw edge cases. For example, the original Snake tail computes
`ATan2(0,0)+90`, so a new zero-velocity segment is drawn at 90 degrees before
its first update.

Player-facing and projectile-facing angles need both coordinate and artwork
orientation accounted for. The source stores player facing as
`ATan2(jdmy,jdmx)-90`; after scene-Y conversion, `whiteplayer.png` points down,
so its SpriteKit rotation is `atan2(sceneDY,sceneDX)+90 degrees`. The source
draws the upward-pointing `yellowshot.png` at `ATan2(dy,dx)+90`; its SpriteKit
equivalent is `atan2(sceneDY,sceneDX)-90 degrees`. Weapon spread angles are
source-space angles too: negate them before rotating a scene-space direction.
Symmetric pairs can hide this error visually, so test the sign and insertion
order of the first positive-angle launch.

Translate the player trail as its own fixed-frame state, not a generic particle.
`UpdatePlayer` creates three entries before `UpdateAll` advances them in the
same displayed frame. Each starts at source
`player - movement*12 + (Sin(angle)*8, Cos(angle)*8)` with velocity
`-movement*1.5`, remains fixed through frame 28, then moves and fades by
`0.91/0.88/0.86` until removal at zero. Scene-Y inversion negates the cosine
offset but not the sine offset. `DrawTrail` combines a doubled 1×1 point and
the doubled particle image at alpha 0.23 under `LIGHTBLEND`; keep it in a
dedicated layer before enemies/player instead of feeding it through the other
particle styles.

The player render order is also observable: trails and ordinary particles are
behind enemies; power-ups and Triangle bonds are drawn before the player;
shots are drawn after it. The shield is an 18-vertex, 20-degree-step circle,
visible while `frames > 60 || frames % 15 > 7`, scaled by
`2.75 + frames/128`, and drawn with alpha blend before the additive player
sprite. Applying one global additive blend to the combined shield/player node
changes both its alpha and overlap.

HUD text, lives, bombs, and the fading threshold message are drawn after
pickups but before the shield, player, shots, and arena border. The arena
border is four separate hard additive two-pixel lines, uses the configured
grid RGB at full alpha, and ends at source `W-1`/`H-1`; a glowing rectangle or
a topmost HUD changes overlap pixels even when each object looks plausible in
isolation.

Projectile bounds expose a one-pixel consequence of the coordinate transform.
The source accepts `0 <= sourceY <= H-1`; with `sceneY = H-sourceY`, the exact
scene interval is `1 <= sceneY <= H`, not SpriteKit's tempting `0...H-1`.
After each half-step, a boundary violation rolls the position back by the full
velocity. A Bouncy shot then negates only the violated component; an ordinary
shot is marked for removal. Test a source shot starting at Y=1 with DY=-2: its
first half-step reaches source Y=0 without bouncing and its second reaches -1,
rolls back to 1, and reflects. This fixture catches both off-by-one errors.

Do not attach Super or Bouncy mode to the projectile object. The original
reads the two global countdowns during every shot update and again while
drawing all shots, so an in-flight projectile changes behavior and colour as
the timers start or expire. Super has precedence when both are nonzero. Each
shot runs exactly two half-steps per frame; within each half-step the order is
move, boundary, collision, active-Black-Hole deflection, minimum-speed check,
then removal or Grid push. Super ignores the collision return value but the
enemy's kill/damage side effects still happen, allowing at most one ordered
collision per half-step. Bouncy affects only boundary removal; enemy hits
still remove it and emit green impact particles.

Preserve the minimum-speed typo literally. When Black-Hole deflection lowers a
shot below half its creation speed, BlitzMax assigns normalized `dx` twice
using the same old speed and never assigns `dy`. A conventional vector
normalization changes trajectories near large holes. The Black Hole itself is
checked for direct collision before its active-only deflection, and deflection
adds `-Sgn(delta)/(26-Int(size/4))` to each source component. Source position
delta and source velocity both invert on Y, so the two sign changes cancel and
the scene formula also subtracts the sign of the scene-space delta.

Keep Snake's `rot` as a source-space heading even though positions and
velocities live in SpriteKit space. Its steering vector therefore becomes
`(cos(rot)*speed, -sin(rot)*speed)`. Boundary response still adds 90 source
degrees once for each violated axis; a corner hit adds 180, not one generic
"did bounce" turn. The Tail chain updates from the terminal link toward the
head because recursive creation adds links to the BlitzMax list while
unwinding.

Interceptor steering needs the same split representation. Keep `rot` and
`rotdir` in source-space degrees while storing velocity and position in scene
coordinates. `TurnToFace` therefore calculates its angle from `(dx, -dy)` and
the scene-facing acceleration is `(cos(rot), -sin(rot))`. `rotdir` is a count
of one-degree source turns, although the heading changes by four degrees per
frame; replacing it with conventional shortest-angle interpolation changes
both the shield window and the acceleration mode. The original also rolls back
both position axes for each violated boundary axis, so a corner can undo the
same movement twice.

Do not derive Interceptor collision from the visible SpriteKit path. BlitzMax
updates shots before `nme7.Draw`, then `Draw` caches `xrgt/yrgt/xlft/ylft` for
the next frame's shot tests. Preserve that one-draw-old geometry. Its
`PointInTri` helper is also observably incomplete: it tests only the two edges
from the center, omits the forward edge, contains an impossible Y branch, and
uses the first-edge denominator guard for the other edge. A mathematically
correct triangle rejects shots the original shield blocks. Port the legacy
predicate literally and cover it with focused tests.

The shield lines are a separate rendering transform. Source points rotate by
`rot + 270` in the Y-down coordinate system. The Interceptor sprite parent is
already at SpriteKit `-(rot + 90)`, so the child path needs a positive
90-degree local rotation; a negative rotation mirrors the shield behind the
ship. Collision remains velocity-facing and must not be substituted with this
animated three-line fan.

Triangle pairing is list-ordered state mutation, not a global nearest-neighbor
pass. Each unfrozen `le.Update` scans the current list after earlier entries
have already moved, attaches to the first unattached endpoint within squared
distance `32*32`, and immediately applies its bond force. Each endpoint owns
its own `strength` and `resist` fields. The spring adds 32 units toward the
partner beyond 150 points or away below 64, then the live global Triangle speed
caps the result before movement and the eight-point boundary bounce.

Render both endpoint views of a Triangle bond. `DrawBond` runs once for every
attached list entry, so the same two-pixel additive line is drawn twice; after
a hit, the two passes may use different colours because each computes
`(20+strength*8, 220-strength*8, 0)` from its local strength. An attached
Triangle also draws its second image at source rotation `r*4+180`, while the
first remains at `r*2`. Deduplicating the line or inheriting the parent's
rotation twice changes the visible star/bond.

Triangle destruction has three distinct paths. A projectile always emits four
strength-coloured particles first. While attached it adds `shotVelocity*5/16`
to the hit endpoint and subtracts 2.5 strength; reaching zero only detaches the
pair. An unattached endpoint then awards 150 points, shockwaves, plays the kill
sound, emits 32 more particles, and is removed. `le.Kill(False)` still takes
that last path and still plays the kill sound, unlike most point-free enemy
kills.

Bonded Black-Hole handling is different again. The first non-resistant endpoint
marks its partner resistant for every Black Hole in the list, even an inactive
one. `Spin(Cos(r*2)*16, Sin(r*2)*16)` subtracts half of that source velocity
from the partner and 0.25 from the partner's strength; after Y conversion its
scene impulse is `(-cos(r*2)*8, +sin(r*2)*8)`. If this breaks the bond, the
pulled endpoint is removed directly and the Black Hole grows—there are no kill
particles, score, shockwave, or killed sound. Do not route this case through a
generic destruction helper.

Max2D does not always transform geometry around the center one might infer
from the call site. `DrawTarget` rotates each `DrawLine(x-sz,y-sz,x+sz,y+sz)`
difference vector around the shared first endpoint. Replacing it with centered
spokes halves the visual bounds and changes the shape. `OriginalTargetRule`
captures this driver-level behavior.

## Power-up lifecycle and collection

Keep the numeric kind mapping literal. `Rand(0,1)` directly selects source
kinds 0/1 (Reverse/Side), and the rare branch assigns `7+Rand(0,1)`
(Super/Bouncy). Mapping a nonzero Boolean to the first enum case silently
reverses both pairs. The later shot-speed, cannon, life, and bomb biases run in
source order and consume random values only when their preceding condition is
true. Sample a spawned power-up's X and top-left source Y before converting Y
to the scene, then draw constructor rotation, direction, and magnitude in that
order. Symmetric Y bounds preserve the distribution but not seeded positions.
Keep construction separate from `MakePowerUp`: the latter adds the two-frame
freeze and Grid push, while direct `pu.Create` calls (including the attract and
isolated fixtures) do neither.

Collection is the first operation in `pu.Update`, before its freeze test. A
new score-threshold pickup has `move=2`; if the player overlaps it immediately,
the original applies the power-up on all three visits (freeze 2, freeze 1, and
the first moving update) before final removal. Do not let SpriteKit physics
contacts remove it asynchronously. Store the dying flag across frozen frames,
apply the effect immediately, skip Black-Hole handling when dying, but still
run movement, the random player-attraction draw, aging, speed limiting, and
end-of-update removal after the freeze reaches zero.

The 2000-point cap fallback calls `IncScore` before creating the pickup text,
so any extra-life, bomb, or power-up threshold events and their sounds precede
the collection message and collection sound. The message is a `score` entry,
not an `SKLabelNode`: it starts with life 50, uses the ordinary vector-score
scale/colour animation, and is drawn behind trails and entities. Its stored
source position is `(x-mlen*6,y-8)`; Super and Bouncy intentionally use
`mlen=15`, not their actual string lengths. A newly collected shield is also
visible in that same draw frame even though the normal player-shield update ran
earlier in the gameplay frame.

After life 200, kinds 2...8 can merge with another such pickup inside the
source squared radius; after life 300 they first apply equal-and-opposite
sign-only attraction. Emit eight particles and create one Butterfly generator
for every matched list entry, not once per outer update. Reverse and Side
instead expire after life 400 into a Butterfly plus eight particles. Active
Black-Hole absorption removes the pickup and grows the hole, but the method
continues through its later random call; its 15 directed particles use the
constructor rotation incremented once per moving update (`r`), not the star's
`life*6` display angle. Drawing changes the star to exact RGB `(180,80,200)`
after life 300 and independently changes the icon after life 360.

## Images and animation sheets

Reuse the original PNG bytes whenever possible. Load textures from `CGImage`
pixel dimensions rather than point-size APIs: some original assets contain
120-DPI metadata that otherwise changes their SpriteKit size.

`LoadImages` calls `AutoMidHandle(True)`, so ordinary game images are centered.
This does not change the top-left semantics of `DrawRect` or `Plot`.

For animation sheets:

- frame numbering is left-to-right, then top-to-bottom in the source image;
- SpriteKit texture rectangles count Y from the bottom, so invert the sheet row;
- retain the per-graphics-set frame dimensions (`snake`, `icons`, and similar
  sheets do not all have one universal size);
- preserve filtering deliberately; the original enables filtered/mipmapped
  images, while pixel fonts and source-rasterized geometry need hard pixels;
- beware linear sampling across adjacent subtexture frames. If visible frame
  bleeding occurs, crop a `CGImage` frame rather than relying on an atlas rect.

Do not palette-tint white source art unless the original calls `SetColor` for
that draw. Keep texture color multiplication, node alpha, and blend mode as
three separate decisions.

When switching graphics sets at runtime, refresh the texture and natural pixel
size of every sprite, including nested child sprites such as Triangle's twin.
Changing only the texture can leave a child at the previous set's dimensions.

## Blend and alpha semantics

Max2D `LIGHTBLEND` is additive. Use SpriteKit `.add`, not the default alpha
blend. This matters even for small stars because normal alpha blend darkens the
destination before adding the source.

Render state persists between functions. `ge.Draw` never calls `SetBlend`, so
generator fills and outlines inherit `LIGHTBLEND` from the preceding particle
pass. Make this dependency explicit in SpriteKit rather than choosing `.alpha`
because the generator's fill has a fractional alpha.

SpriteKit can effectively apply node alpha once during premultiplication and
again during additive composition. On paths where capture evidence proves this
behavior, use `sqrt(sourceAlpha)` (`OriginalBlendRule`) so the resulting light
matches Max2D. This is validated for dense meshes, wide particle lines, and
stars. Do not apply it globally: it was measured and rejected for several
filled grid styles and the style-3 particle texture bloom.

Raw OpenGL calls have their own state. In the original:

- `glColor3f` sets RGB and leaves the effective draw alpha at 1 for the audited
  paths;
- Max2D alpha can carry into raw GL when no later color call resets it;
- repeated additive draws are part of the output and must not be merged unless
  the blend result remains identical.

This last point also applies to `DrawPoly`. Alternating filled Grid styles
14–17 draw every cell separately. Combining many cells into one compound
`SKShapeNode` loses repeated additive fills where deformed cells overlap.
Style 17 additionally changes alpha after every polygon, so its source loop
must run from top to bottom; in scene coordinates that means descending rows.
Keep those per-cell nodes separate unless a replacement renderer explicitly
preserves drawcall-level accumulation.

SpriteKit cannot reproduce OpenGL per-vertex color interpolation exactly with
a single `SKShapeNode`. The port uses bounded color buckets for the RGB-split,
stretched, and sine paths. The continuous stretch colour/width functions use
64 buckets; 16 levels produced measurable banding and larger reference errors.
Increase bucket counts only when captures improve. Raster policy is likewise
selector-specific: disabling `SKShapeNode` antialiasing improves the closed
`DrawLine` cell outlines of Grid style 11, but slightly worsens the two
diagonal lines of style 12, so do not apply it to every grid path.

The RGB-split spiral is sensitive to vertex emission order even when the final
line topology looks the same. After scene-Y conversion it starts at the visual
top-left, walks clockwise, repeats the bottom-right corner before the leftward
side, and only then shrinks `xmax`. Preserve that duplicate vertex because it
also advances the six-degree colour phase. The red path checks X displacement
on horizontal sides and Y displacement on vertical sides; a generic
"either-axis moved" check produces incorrect `(-4,+4)` offsets at corners.
The Moiré style uses six constant-color subdivisions per triangle as a bounded
Gouraud approximation; 12 subdivisions rendered slower and compared slightly
worse. Its source `b` phase index must be recovered as `rows-1-sceneRow`, and
after Y inversion its source bottom-right triangle remains at the scene cell's
bottom-right corner. Flipping it to the top-right corner is a double inversion
and was the dominant Grid-18 error.

## Grid simulation and draw order

The grid updates in place. Iteration order is therefore observable. Preserve
the original top-to-bottom source traversal even though scene Y is inverted;
reversing the loop changes the lattice asymmetry.

Preserve state changes in call order, not merely the same total count. The Get
Ready loop explicitly calls `UpdateGrid`, then `UpdateAll` calls it again. It
therefore performs two grid updates per displayed frame, with the ring pull
occurring before both updates on the source frame.

Every grid selector has distinct topology, bounds, alpha, and state leakage.
Avoid a single generalized renderer until all selectors have been audited.
Direct GL line paths, Max2D lines, filled quads, texture particles, and
per-vertex gradients need separate treatment.

Mathematical multiples can still have source loop boundaries. Point-grid
styles 0 and 1 draw the larger row/column marks from index four onward; index
zero is not highlighted even though `0 Mod 4 = 0`.

Particle motion also has two deliberate boundary variants. Gameplay calls
`Update` against `PLAYFIELDW/H`, while attract/menu paths call `UpdateWide`
against `SCREENW/H`. Keep both entry points. After converting the simulation
to scene-Y coordinates, negate every source emission angle—including generic
test/helper overloads—before deriving velocity. Preserve the source's final
doubling of both velocity components and its cyclic slot replacement.

Do not confuse the original default of 2048 particles with its configurable
maximum of 50,000. A renderer may allocate visual nodes lazily, but it must
scan all active simulation slots in source index order and grow to the actual
active count. For particle style 3, keep all line nodes before the later bloom
image pass when that pool grows.

Firework branch order is random state. In style 1's vertical-edge branch the
source samples Y before choosing the left/right side. Active Black Holes add a
separate recipe every 60 rotations: eight type-7 particles at
`center + (Sin(r)*size*1.15, Cos(r)*size*1.15)` plus a three-pixel 45-degree
spoke, directed by `r+spoke`. Invert both cosine Y terms at the scene boundary.

## Renderer reuse and allocation rules

Performance work must preserve draw order and repeated additive coverage. The
current SpriteKit implementation follows these reuse boundaries:

- `OriginalGraphics` caches common textures, graphics-set textures and source
  images, missing-image lookups, and frame subtextures. Resource lookup and
  `CGImage` decoding must not return to the per-frame path.
- `OriginalHUDRenderer` owns two persistent icon sprites and eight persistent
  vector-text shape slots. Rebuild a text path only when its text or layout
  changes; color, alpha, and visibility may still change every presentation.
- `OriginalScreenRenderer` uses one ordered pool of shape and sprite nodes.
  Reuse a node only when its type matches the next source draw, replace a type
  mismatch in place, reset all mutable render state, and hide the unused tail.
  This retains painter order without calling `removeAllChildren()` each frame.
- `GridRenderer` reuses a style-stable ordered node pool and hides its unused
  tail. Clearing the pool is reserved for a Grid-style switch, because different
  selectors have incompatible topology and render state.
- `ParticleRenderer` has separate, lazy, grow-only line-shape and texture-sprite
  pools. It scans every active particle slot in source order, assigns one node
  per active particle per required layer, and hides only the unused tail. It
  incrementally prewarms at most 16 entries per pool per rendered frame toward
  `min(capacity, 768)`; demand beyond that still grows the pool immediately.

The SpriteKit particle change is pooling, not true batching: style 0/1 still
uses one `SKShapeNode` per visible particle, style 2 one `SKSpriteNode`, and
style 3 one of each. Every line node keeps a unit path and changes position,
scale, and rotation instead of rebuilding its path. A compound-path batch was
tested and rejected because overlapping additive lines must accumulate once
per source draw. Style 3 also requires the complete line layer before the
complete bloom-sprite layer; interleaving line and bloom nodes changes overlap
pixels.

## Randomness and numeric conversions

Use the archived BRL.Random algorithm for deterministic source parity. Swift's
standard RNG does not produce the same sequence. Also reproduce the source's
inclusive integer ranges and its implicit Float-to-Int truncation points.

Use that generator in the live game too, not only in screenshot fixtures. A
capture can look correct while subsequent live waves drift if the scheduler,
corner expansion, entity constructors, update branches, power-up selection or
particle emission use Swift's `RandomNumberGenerator` distribution helpers.
Those helpers consume a different number of underlying state words even when
the requested numeric range is identical. Route source `Rand`/`Rnd` sites to
the archived implementations explicitly and seed the live stream from
milliseconds-since-boot, matching `SeedRnd(MilliSecs())`.

Random-call order is part of behavior. The original capture state creates all
10,001 stars before spawning the inspected entity; consuming only the visible
301 star values changes every later randomized entity transform.

Preserve call order inside constructors too. Generator creation calls
`SafeXY` before assigning `r = Rand(0,359)`. Reversing those two operations
uses the intended position sample as the rotation and moves every deterministic
generator fixture to a different quadrant.

Constructor order is not uniform across enemy types. Pinwheel and Green Square
fix `r=90` and draw only direction/magnitude; most kinds draw
rotation/direction/magnitude; Interceptor draws direction/magnitude/rotation.
Snake recursively creates 24 tail links plus the terminal link. Every link
draws an otherwise unused rotation, and each positive length divisible by
three draws a direction-flip value. A flat Swift tail array must still consume
those calls in the recursive source order.

Do not freeze mutable BlitzMax globals into an entity at construction time.
Enemy speed globals increase each minute and immediately affect enemies that
already exist, so the Swift update reads the current shared session speed each
frame. This also applies to projectile-avoidance caps derived from that speed.

Audit positional calls against each exact signature. `ge.Birth` ends the Snake
call with `...,24,5,1`; for `nme6.Create` that `1` is the inert `rr` argument,
not the later `close` flag. Generator-born Snake heads therefore use the normal
160-point `SafeXY` rule while the other generator children use the close
40-point rule.

Remove Swift-only random fields even when their values are never read: they
still shift the shared stream. Conversely, retain source calls whose numeric
effect is zero. Diamond's `Rand(-0.2,0.2)` arguments implicitly truncate to
`Int(0), Int(0)`; both calls return zero but advance BRL.Random whenever the
preceding `Rand(0,1)` branch succeeds.

Destruction order can also change the shared random stream. Ordinary enemies
award score before sound, Cube children, particles, shockwave, and removal;
score thresholds may create a power-up immediately. Generator final particles
precede sound and score, while a finished Black Hole removes itself and emits
its last particles before awarding score and playing its final sound. Preserve
these type-specific sequences instead of routing all entities through one
generic destruction order. Cubie also calls the degenerate integer range
`Rand(-30,-30)` before its random Y offset for each child; the fixed X result
still consumes generator state.

Temporary score text is gameplay state too. The original retains each entry
for 30 frames, draws at `(sourceX-life, sourceY-16)`, scales it by
`1+life/12`, and clamps the colour component `75+life*10` to 255. Keep this as
a fixed-step vector-font effect rather than a timed platform label; otherwise
pausing, death frames, camera scrolling, and deterministic captures drift.

Sample spawn coordinates in the source's top-left coordinate system, in X-then-Y
call order, and only then convert `sceneY = playfieldHeight - sourceY`.
Sampling an equivalent bottom-left range has the same distribution but maps a
given seeded value to the opposite point. Directional rotations need the same
handedness treatment: after Y inversion, an Interceptor drawn at source
`rot+90` uses SpriteKit `-(rot+90)`.

BlitzMax locals are zero-initialized, including locals that are accidentally
never assigned. In `ge.Draw`, Triangle and Butterfly fill alpha uses
`0.1 - sc / 256` even though `sc` is never set, so the effective alpha is the
constant `0.1`; do not "repair" it to the health formula used by other kinds.

## Timing and state-order traps

The gameplay loop is fixed at 50 Hz (`20 ms`). A display may refresh at 60 Hz,
but gameplay, spawn counters, upgrade durations, colour phases, and particle
lifetimes must advance only through `OriginalTimingRule.fixedStep`. Bound the
accumulator after a stall so resuming the app cannot simulate an unbounded
burst of historical frames.

Read setup routines through their final call order, not isolated assignments.
`ResetGame` assigns `powerupscore = POWERUP` (`2500`) and then immediately calls
`ResetMultiplier`, which rounds the next threshold to `5000` at score zero.
Therefore the effective first in-game power-up threshold is `5000`, followed
by `POWERUP * multiplier²` increments. Porting the earlier assignment alone
silently spawns the first power-up twice as early.

`DrawMessage` is also state-order-sensitive. It decrements `messtime` during
`DrawAll`, after gameplay updates, rather than in `UpdateAll`. At remaining
frame 90 it rebuilds the string from the then-current `powerupscore`; its RGB
is `(messtime, 165 + messtime / 2, messtime)`, and it inherits the lower-HUD
alpha selected from the player's Y position. The countdown continues through
the blocking death, Get Ready, and Game Over draw loops, but stops while an
options menu or pause loop owns presentation. Keep it separate from weapon and
shield timers, which do not advance in those transition loops.

At the end of Get Ready, the source clears the old message and calls
`ResetMultiplier` only after the final ring frame has been drawn. Resetting one
frame earlier shortens the new message. The source call is
`DrawString(text, SCREENW / 2 - Len(text) * 7, SCREENH - 26, 2.8)`; the shared
vector-font conversion still flips Y, while SpriteKit's two-pixel shape stroke
needs the documented one-pixel raster offset in both axes to cover the same
logical pixels as Max2D's OpenGL line.

Keep deterministic pure rules outside SpriteKit where possible. Test boundary
conditions and historical integer conversions directly rather than relying
only on screenshots.

## Timing, state, and rendering phases

The original loop targets 50 Hz. Model source frames explicitly and do not
derive authoritative gameplay timing from a variable display refresh rate.

For smoother 60-Hz presentation, retain the previous and current state at each
20-ms fixed step and render with
`alpha = clamp(accumulator / fixedStep, 0...1)`. Interpolate positions linearly
and rotations over the shortest angular delta. The current implementation does
this for live scene nodes, camera/parallax stars, Grid points, and particle
position and velocity; both SpriteKit and the optional Metal snapshots consume
the same alpha.

Presentation state is never gameplay state. Restore every node to its current
authoritative position and rotation before reading input, running collision or
fixed-step logic, changing presentation ownership, or taking another snapshot.
Newly created nodes use their current state as both endpoints, and removed nodes
are ignored. This keeps the 50-Hz source behavior deterministic while allowing
the display callback to run at 60 Hz.

Distinguish state before and after `Flip`. Several reference images are the
front buffer from immediately before a source transition. Capture helpers must
select the same phase, counter value, and update/draw ordering.

Attract screens do not share one generic update order. Each page has its own
particle emission, color cycling, display effects, and delayed starts. Menus
also retain their 50-Hz cursor/color phase and their capture-time mouse
position; notably, the Joypad page uses the raw `(0,0)` capture mouse position.

Post-game Scores is not the same transition as the cyclic attract Scores page.
After 750 frames it returns to Title, whereas the cyclic page proceeds to
Friends. A zero score skips Scores entirely. Ending a live game with a positive
score still runs the normal qualification/name-entry path after gameplay state,
particles, and Grid deformation have been cleared.

The cheat pause is a local loop entered when P is observed down. Releasing P
after entry does not leave that loop; O is still required. O releases one
complete 50-Hz iteration and the next iteration enters the pause loop again
only if P remains down. Advance simulation and renderer-owned Grid animation
phase together. Do not add a pause overlay—the last rendered gameplay frame
remains visible.

## Fonts and menus

There are two independent font systems:

- game screens and HUD use the custom vector data in `vectorfont.bmx`;
- Dual Stick configuration uses BRL Max2D's archived 8×16 `blitzfont.bin`.

Normal vector strokes match OpenGL more closely with antialiasing disabled,
butt caps, and miter joins. The title deliberately overdraws many animated
copies; its stable SpriteKit approximation currently keeps smooth strokes and
its unshifted subpixel origins. The title's static credits also keep smooth
strokes, but use the Max2D line pixel center: `(x+0.5,y+0.5)` while still in
top-left source coordinates, equivalent to `(x+0.5,y-0.5)` in scene space.

Classic `Rect(...,0)` menu outlines are hard, pixel-centered line loops. Do
not use SpriteKit's default antialiased centered rectangle without applying the
source raster conversion. Preserve fixed source coordinates and historical UI
typos such as the displayed `180` value for a stored scale of `128`.

Small screen-specific quirks are part of the contract. The Friends page uses
colour-trail slot 6 for both Super Shots and the preceding entry, and the
high-score name underline is a hard additive two-pixel `DrawLine`, not a
translucent filled rectangle.

## Audio, input, and persistence

Keep gameplay audio cues mapped by source call site. Tracker modules were
converted losslessly for Apple playback; retain the original module files as
the authority and record any conversion commands/checksums.

Translate platform input into one shared input snapshot. Preserve configurable
source key/button semantics; do not hard-code Space/Escape as the only BOMB or
OPTION paths. iOS touch controls are a platform equivalent layered over the
same shared actions.

High-score input has its own legacy rules. Direct typing accepts the source
key-code interval 48...90, lowercases A...Z unless Shift is held, and advances
the selected slot. Movement Y cycles ASCII, movement X selects a slot, fire Y
toggles case, and the configured mouse or Dual-Analog/Joypad BOMB completes the
entry. The eight character slots are global in the source: retain the last name
for the next record, but reset the local selection to slot zero.

The name editor's local `bombtime` starts at 20 and is shared by controller
case toggle, character cycling, position movement, held Up/Down, and controller
BOMB completion. Axis movement can act once immediately, then repeats after
8 or 15 frames even if it never returns to neutral; neutral input only clears
the corresponding ignore flag. Decrement the cooldown before testing a held
controller BOMB. A generic one-action-until-neutral latch is observably wrong.

Qualification and validity are separate. An invalid score that exceeds the
tenth-place score skips insertion and displays as unranked, but the original
has already started high-score music. Preserve that audio branch rather than
collapsing all unranked results into the ordinary intro-music path.

Legacy configuration, color, and high-score files have observable ordering,
defaults, and checksum behavior. Treat their codecs as compatibility formats,
not as opportunities for schema cleanup.

## Verification workflow

Use three levels of evidence:

1. focused unit tests for deterministic rules;
2. deterministic fixed-state captures against the original renderer;
3. manual playthroughs on macOS and real iPhone/iPad hardware.

For a fixed-landscape SpriteKit app, drive physical UI tests with normalized
application coordinates, but derive menu-row Y positions after the 4:3
aspect-fit transform. A row that is centered at source Y 464 on a 768-point
scene lands near normalized screen Y 0.62 on the tested 2868×1320 device;
rounding that to 0.60 selected no hit frame. After Home/activate, wait for the
interface-orientation transition before taking evidence screenshots. XCUITest
may store the physical PNG pixel matrix in portrait order even though its image
orientation metadata and the running interface are landscape, so do not reject
the layout from raw width/height alone.

The repeatable macOS interaction sequence and its data-isolated Debug
high-score hook are documented in `docs/RUNTIME-SMOKE.md`.

Relevant commands:

```sh
sh scripts/capture-screens.sh /private/tmp/GridWarsSwiftCatalog
sh scripts/compare-captures.sh \
  docs/captures/original /private/tmp/GridWarsSwiftCatalog
```

Generate original references with `scripts/capture-original.sh` and a BlitzMax
toolchain. Two runs should have identical SHA-256 hashes before treating a
screen as deterministic.

Normalized mean absolute difference is a prioritization tool, not proof of
correctness. Always inspect the image and the source. A lower score can hide a
wrong state, while a tiny regression can result from fixing a semantically
wrong common rule. Retain a change only after checking every affected capture
category.

Broad rendering switches are risky. During this rewrite, global pixel shifts,
global line-antialias changes, wider lines, and universal alpha compensation
all regressed valid selectors. Prefer a source-specific rule with a focused
test and a catalog comparison.

The optional Metal compositor follows the same rule. It is a macOS-only,
default-off `MTKView`/`SKRenderer` host for Grid style 1 and particle style 1;
iOS remains on the ordinary SpriteKit host. Its pass sequence is Metal Grid,
SpriteKit stars/low effects/trails, Metal-or-SpriteKit particles, then the
SpriteKit foreground. It uses `bgra8Unorm`, grow-only triple-buffered instance
buffers, and automatic whole-frame or per-effect SpriteKit fallbacks. Gameplay,
collisions, audio, and input are not Metal responsibilities.

The current shader file is bundled as a text resource. The renderer first uses
a default library only if both functions are present, otherwise it reads
`GridWarsEffects.metal` and compiles that source at runtime. Do not describe the
file as a compiled Sources-build-phase member or maintain a second embedded
shader string unless the project integration actually changes.

The final Release A/B was a single, vsync-limited run of the identical static
Grid-1 plus 2,048-particle fixture. SpriteKit/Metal p95 present intervals were
`17.6055/17.3597 ms`, CPU samples averaged `1.9069/1.6826 ms` per frame, and
GPU spans averaged `0.6752/0.5713 ms`. This suggests modest average CPU/GPU
savings but no material p95 frame-pacing win; GPU p95 was slightly worse at
`1.2332/1.2986 ms`. Grid captures are extremely close; Metal particle lines
have harder raster coverage and currently compare slightly worse with the
original. Keep the prototype off and treat it as measurement infrastructure,
not a completed renderer migration. Exact switches, capture commands,
measurements, fallback behavior, and remaining gates are in
`docs/METAL-PROTOTYPE.md`.

## Checklist for another rewrite

- Archive the exact source, assets, compiler references, and deterministic
  original captures first.
- Build a source-to-feature matrix before writing abstractions.
- Implement the BlitzMax RNG and numeric conversion rules early.
- Choose one internal coordinate system and centralize every conversion.
- Load image pixels without DPI-dependent sizing; verify every sheet layout.
- Audit blend, alpha, transform, line width, and color state per draw path.
- Preserve update order, random-call order, and pre/post-`Flip` phase.
- Add focused capture scenarios before tuning visuals.
- Commit after each verified milestone and record rejected experiments.
- Do not claim 1:1 completion until the full catalog, deterministic rerun, unit
  tests, both platform builds, and manual device playthroughs are complete.
