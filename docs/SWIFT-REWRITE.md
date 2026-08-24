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

## Transforms and angles

BlitzMax angles are expressed in degrees. SpriteKit rotations use radians.
Remember that the scene-Y inversion changes the apparent rotation direction.
Use `atan2`, not `atan(dy/dx)`, except where the original explicitly used the
latter and its divide-by-zero behavior is part of the result.

The same handedness change applies to tangential forces, not just displayed
angles. For a BlitzMax force term `(dx - dy/spin, dy + dx/spin)`, a simulation
stored in SpriteKit coordinates needs the Y-inverted equivalent
`(dx + dy/spin, dy - dx/spin)`. The title-screen particle spirals and gameplay
black holes expose this difference clearly; copying the source signs verbatim
makes their rotation run mirrored.

Preserve first-draw edge cases. For example, the original Snake tail computes
`ATan2(0,0)+90`, so a new zero-velocity segment is drawn at 90 degrees before
its first update.

Max2D does not always transform geometry around the center one might infer
from the call site. `DrawTarget` rotates each `DrawLine(x-sz,y-sz,x+sz,y+sz)`
difference vector around the shared first endpoint. Replacing it with centered
spokes halves the visual bounds and changes the shape. `OriginalTargetRule`
captures this driver-level behavior.

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

## Blend and alpha semantics

Max2D `LIGHTBLEND` is additive. Use SpriteKit `.add`, not the default alpha
blend. This matters even for small stars because normal alpha blend darkens the
destination before adding the source.

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
stretched, and sine paths. Increase bucket counts only when captures improve.
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

## Randomness and numeric conversions

Use the archived BRL.Random algorithm for deterministic source parity. Swift's
standard RNG does not produce the same sequence. Also reproduce the source's
inclusive integer ranges and its implicit Float-to-Int truncation points.

Random-call order is part of behavior. The original capture state creates all
10,001 stars before spawning the inspected entity; consuming only the visible
301 star values changes every later randomized entity transform.

Keep deterministic pure rules outside SpriteKit where possible. Test boundary
conditions and historical integer conversions directly rather than relying
only on screenshots.

## Timing, state, and rendering phases

The original loop targets 50 Hz. Model source frames explicitly and do not
derive authoritative gameplay timing from a variable display refresh rate.

Distinguish state before and after `Flip`. Several reference images are the
front buffer from immediately before a source transition. Capture helpers must
select the same phase, counter value, and update/draw ordering.

Attract screens do not share one generic update order. Each page has its own
particle emission, color cycling, display effects, and delayed starts. Menus
also retain their 50-Hz cursor/color phase and their capture-time mouse
position; notably, the Joypad page uses the raw `(0,0)` capture mouse position.

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

## Audio, input, and persistence

Keep gameplay audio cues mapped by source call site. Tracker modules were
converted losslessly for Apple playback; retain the original module files as
the authority and record any conversion commands/checksums.

Translate platform input into one shared input snapshot. Preserve configurable
source key/button semantics; do not hard-code Space/Escape as the only BOMB or
OPTION paths. iOS touch controls are a platform equivalent layered over the
same shared actions.

Legacy configuration, color, and high-score files have observable ordering,
defaults, and checksum behavior. Treat their codecs as compatibility formats,
not as opportunities for schema cleanup.

## Verification workflow

Use three levels of evidence:

1. focused unit tests for deterministic rules;
2. deterministic fixed-state captures against the original renderer;
3. manual playthroughs on macOS and real iPhone/iPad hardware.

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
