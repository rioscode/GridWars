# Point-Grid renderer A/B and `GridSimulation.push` — 2026-10-09

## Status

The pooled-sprite point Grid from `MEASUREMENTS-CROWDED-GRID-2026-08-30.md` was
never accepted. It was an uncommitted candidate awaiting an A/B. This note
records that A/B. **The candidate is rejected on cost and is no longer the
iOS default.** The `SKShapeNode` representation stays the only default on both
platforms.

A second, independent change in this pass — clamping the `GridSimulation.push`
neighbourhood — is accepted. It is proven behaviour-identical and strictly
performs less work.

## How the A/B was made reproducible without a device

The crowded-grid A/B protocol required a physical iPhone and Instruments attach,
which had already timed out three times. The measurement was therefore moved
into the existing deterministic benchmark, which is not platform gated:

```sh
xcrun xctrace record --template 'Time Profiler' --time-limit 12s \
  --output .build/grid-sprite-ab/shape-bench.trace --no-prompt \
  --launch -- "$APP" --ios-performance-benchmark

xcrun xctrace record --template 'Time Profiler' --time-limit 12s \
  --output .build/grid-sprite-ab/sprite-bench.trace --no-prompt \
  --launch -- "$APP" --ios-performance-benchmark --grid-sprite-points
```

`--ios-performance-benchmark` sets `GridStyle.pointsCycling`, so it exercises
exactly the point Grid path. The default 1,024 x 768 arena at 16-point spacing
produces the documented 4,496 rectangles per displayed frame. Raw artifacts are
under `.build/grid-sprite-ab/`.

> **2026-11-04:** the sprite path, the `--grid-sprite-points` switch and
> `GridPointQuadPlan` were removed from the shipped renderer after review. To
> repeat this comparison, check out commit `889fbea`.

At measurement time two renderer-selection switches existed, and neither
changed gameplay:

| Switch | Effect |
| --- | --- |
| `--grid-sprite-points` | Opt in to the pooled-sprite point Grid. Off by default on every platform. |
| `--grid-shape-points` | Removed. It only existed to disable the sprite default. |

## Result 1: the sprite Grid is a cost regression

Main-thread Time Profiler weight over one 12-second Release run, attributed to
the first application frame below each leaf:

| Path | `renderGrid` inclusive | `addPointGrid` / `addSpritePointGrid` + sprite claim |
| --- | ---: | ---: |
| `SKShapeNode` (default) | 111 ms | 49 ms + 53 ms (`addShape`) |
| Pooled sprites | 514 ms | 37 ms + 450 ms (`addPointSprite`) |

Total main-thread time was 11,385 ms and 11,634 ms respectively, so the sprite
path costs about 4.6x more Grid time and about 2% of the whole frame budget.

The reason is structural. The sprite path replaces one vector node per pass with
4,496 individual `SKSpriteNode` objects. Even after removing the per-frame
`texture`, `size`, `anchorPoint`, `blendMode`, `zPosition` and `isHidden` writes
and skipping a sprite whose computed rectangle is unchanged, SpriteKit still
traverses and sorts 4,496 nodes every displayed frame. `benchmark` uses the
cycling colour, which changes every frame and therefore defeats the colour skip.

This also weakens the 2026-08-30 attribution. On macOS the same 4,496-rectangle
`SKShapeNode` path is only 1.0% of main-thread time, not the 28% + 23% seen in
the iPhone crowded trace. Either the iPhone attribution was dominated by a
different workload, or iOS `SKCShapeNode::addRenderOps` behaves materially
differently from macOS. That difference is unresolved and is recorded as an open
question below.

## Result 2: the sprite Grid is slightly more faithful

The raster question from the earlier note is answered. Normalized mean
grayscale difference against the original capture:

| Capture | `SKShapeNode` | Pooled sprites | shape vs sprite |
| --- | ---: | ---: | ---: |
| `grid-00` | `0.00281094` | `0.00268455` | `0.000155149` |
| `grid-01` | `0.00205562` | `0.00201274` | `0.0000893173` |

All 19 other `grid-*` styles are byte-identical between the two paths, because
only the two non-particle point styles take the sprite branch. Fidelity was
never the reason to reject the sprite path.

## Result 3: `GridSimulation.push` neighbourhood clamp (accepted)

`GridSimulation.push` was 766 ms of 11,385 ms, or 6.7% of main-thread time. The
original loop walks a full `2 * radiusInPoints + 1` square and then rejects
every point whose origin is 50 or more scene units from the centre. The clamp
intersects the square with a conservative bounding box of that open disc
before iterating and leaves the per-point distance test in place, so it visits
the identical set of points in the identical order and skips only the rejected
corners.

> **2026-11-04 correction:** the first version of the clamp assumed every
> origin was exactly `index * spacing` and used strict `±1` bounds. That
> dropped boundary points for offset render windows and, through rounding,
> for spacings other than 16. The clamp now measures from the lattice's first
> origin and widens each bound by one index.
> `testGridPushMatchesSourceForNonPowerOfTwoSpacingAndOffsetLattice` fails
> against the old clamp and passes against the fixed one.

| Function | Before | After |
| --- | ---: | ---: |
| `GridSimulation.push(at:radiusInPoints:amount:)` | 766 ms | 685 ms |
| Total main thread | 11,385 ms | 11,353 ms |

The self-time drop is 10.6%. The total change is inside run-to-run noise and is
not claimed as a frame-rate win. It is kept because it is strictly less work and
is proven equivalent:

* `testGridPushVisitsExactlyTheOriginalSquareNeighbourhood` runs a transcription of
  the original square loop in the test target and compares the complete
  `points` array after every push, over nine centres including the origin,
  negative, off-arena and fractional positions, across three passes that deform
  the lattice in between so the displacement gate is exercised.
* `grid-00`, `grid-01`, `grid-02`, `grid-08`, `grid-16` and `grid-20` captures
  are byte-identical before and after the change.

## New deterministic tests

* `testGridPushVisitsExactlyTheOriginalSquareNeighbourhood`
* `testGridPushMatchesSourceForNonPowerOfTwoSpacingAndOffsetLattice` (added
  2026-11-04)

The `GridPointQuadPlan` and `interpolatedPosition` tests added with this pass
were removed on 2026-11-04 together with the sprite path, which was their only
consumer.

Test count went from 143 to 148 in this pass and is 145 after the 2026-11-04
cleanup, all passing. macOS Debug and Release, the iOS
Simulator Debug build, and a generic iOS device Release build all succeed.

## Measured hot spots after this pass

Same 12-second `--ios-performance-benchmark` Release run, self time attributed
to the first application frame:

| Function | Weight | Share |
| --- | ---: | ---: |
| `GameScene.checkProjectileCollisions` | 2,151 ms | 19.0% |
| `GridSimulation.push` | 685 ms | 6.0% |
| `GameScene.updateProjectiles` | 575 ms | 5.1% |
| `ParticleRenderer.configureShapeLine` | 231 ms | 2.0% |
| `GridSimulation.update` | 162 ms | 1.4% |
| `GameScene.applyBlackHoles` | 124 ms | 1.1% |
| `GridSimulation.updatePoint` | 112 ms | 1.0% |
| `GridSimulation.beginPresentationStep` | 111 ms | 1.0% |
| unresolved runtime/system | 6,099 ms | 53.7% |

`checkProjectileCollisions` is now the dominant application cost by a wide
margin and it is exactly the Phase-4 target: every projectile tests every
candidate of every kind, so the cost scales with projectiles x enemies. The
unresolved runtime share is consistent with `SKNode.userData` bridging and
`SKNode.position` message sends from that same loop.

## Open questions

1. Why did the iPhone crowded trace attribute 28% + 23% to the point Grid while
   the identical macOS workload attributes 1%? Re-measure on the device before
   spending more effort on Grid rendering.
2. Does the same divergence apply to `ParticleRenderer.configureShapeLine`,
   which uses one `SKShapeNode` per line particle?
3. `checkProjectileCollisions` cannot be indexed until the Green Square
   `runGreenSquare` side effect is proven to have its own distance gate, because
   that call currently runs for every non-colliding green square.

## Claims now supported

- The pooled-sprite point Grid is a measured cost regression and was removed
  from the renderer.
- The pooled-sprite point Grid is marginally more faithful than the shape path.
- The `push` clamp is behaviour-identical and performs 10.6% less self time.
- Projectile-versus-enemy collision is the largest measured application cost.

## Claims still not supported

- "The iPhone Grid renderer is the main bottleneck."
- "The game holds 60 FPS on the physical iPhone in a crowded wave."
- "A spatial broad phase will produce a specific percentage improvement."
