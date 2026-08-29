# iOS Performance Plan

## Goal

Keep the authoritative 50-Hz GridWars 5.4 simulation and the accepted visual
output while sustaining smooth 60-Hz presentation on a physical iPhone during
heavy projectile, Grid, enemy, and particle load.

The immutable starting point is commit `aac3d9c`, tagged
`pre-ios-performance-optimization`.

## Current implementation status (2026-08-30)

- [x] Deterministic dynamic benchmark mode and points-of-interest signposts.
- [x] Optional SpriteKit FPS, node, draw, and quad statistics.
- [x] Phase 1 collision candidates classified once per projectile update and
      refreshed after synchronous enemy-tree count changes.
- [x] macOS Debug and Release builds, generic iOS Simulator Debug build, and
      all 141 macOS tests pass.
- [x] Five projectile-focused reference captures remain inside the accepted
      visual boundary (`0.00339833...0.00385059` normalized mean grayscale
      difference from the original).
- [ ] Three Release measurements on the same physical iPhone.
- [ ] Measured Phase 1 before/after CPU and allocation comparison.

The benchmark launches successfully in Release, but no device performance
number is recorded yet. LaunchServices selected an older registered macOS app
during the first Instruments attempt, so that trace is not valid evidence for
this phase. The physical-iPhone runs are the next measurement checkpoint.

## Observed scaling risks

1. `GameScene.updateProjectiles()` advances as many as 500 projectiles twice per
   fixed step. Each half-step currently rebuilds filtered enemy arrays for each
   enemy kind, scans generators and Snake nodes, and filters Black Holes again
   for deflection. In the stable worst case this can exceed 10,000 complete
   enemy-list traversals and temporary arrays per fixed step.
2. Each surviving projectile half-step calls `GridSimulation.push()`, which
   visits a 7x7 point neighborhood. Five hundred projectiles can therefore
   produce about 49,000 Grid-point checks per fixed step.
3. `GridRenderer` rebuilds paths every displayed frame. Particle Grid styles
   additionally allocate an arena-sized bitmap, create a `CGImage`, and upload
   a new `SKTexture` every frame.
4. `ParticleRenderer` pools allocations but still uses one `SKShapeNode` per
   line particle. Pool entries are grow-only and remain in SpriteKit's node
   tree after a burst.
5. Presentation interpolation collects every live entity into scratch arrays
   and an `ObjectIdentifier` dictionary on each fixed step. This scales with
   projectile and enemy count.

The existing `--effects-benchmark` is intentionally static and cannot validate
these simulation costs.

## Measurement scenario

Add a deterministic `--ios-performance-benchmark` launch mode that runs the
normal SpriteKit presentation with:

- 500 persistent moving projectiles;
- a dense, stable enemy mix;
- a deforming 16-point-spaced Grid;
- 2,048 active style-1 particles;
- no persistence, input, spawning, scoring progression, or audio noise.

Add points-of-interest signposts around display update, the fixed simulation,
projectile processing, Grid rendering, and presentation rendering. Optional
SpriteKit FPS/node/draw/quad statistics may be enabled with
`--performance-stats`.

Record three 30-second Release runs on the same physical iPhone from a cool
thermal state. Capture Game Performance, Time Profiler, and Allocations data.
Record p50/p95 display intervals, repeated 33-ms frames, main-thread CPU time,
allocation rate, node count, and draw count.

## Optimization order

### Phase 1: projectile collision candidates

- Classify the current enemy children once and reuse ordered per-kind arrays
  across projectile half-steps.
- Rebuild only after synchronous enemy-tree mutation.
- Ignore removed nodes and include newly spawned Cube children before the next
  half-step.
- Preserve the original kind priority, list order, Super piercing, Green Square
  avoidance, Snake-tail behavior, Interceptor shield behavior, and Black-Hole
  deflection order.

Verification: focused projectile tests, the full macOS test suite, both app
builds, and the complete capture catalog where available.

### Phase 2: Grid work

- Measure `GridSimulation.push()` separately from `GridRenderer` path creation.
- Add a source-ordered batch API for projectile Grid impulses if simulation is
  significant.
- Remove per-frame bitmap allocation and texture creation from Particle Grid
  styles.
- Compare 50-Hz Grid presentation, SpriteKit sprite/mesh approaches, and a
  narrowly scoped iOS Metal Grid pass. Do not adopt Metal without updating the
  architecture decision and passing the capture boundary.

### Phase 3: particle presentation

- Compare the current `SKShapeNode` line with a shared-texture
  `SKSpriteNode` strip while retaining individual colour, alpha, additive
  overlap, line width, pixel alignment, and style-3 layer order.
- Retire excessive hidden pool nodes after large capacity/burst reductions.
- Consider an instanced Metal particle pass only if the SpriteKit result is
  still outside the frame budget and visual parity can be demonstrated.

### Phase 4: entity state and interpolation

- Move projectile velocity and previous/current transforms out of
  `NSMutableDictionary` into compact Swift value state.
- Pool projectile sprites as presentation objects.
- Replace the per-step global interpolation dictionary with typed snapshots.

## Acceptance criteria

- Three repeatable physical-iPhone Release runs with no recurring 33-ms frame
  pattern during the benchmark.
- The fixed-step accumulator normally consumes at most one 20-ms simulation
  step per display update.
- Phase 1 materially lowers `updateProjectiles()` CPU time and allocation rate;
  target at least a 70-percent reduction in the dense benchmark.
- macOS Debug build, iOS Simulator Debug build, and macOS tests pass.
- Deterministic gameplay tests and accepted captures show no rule, ordering,
  layer, or raster regression.
- `FIDELITY.md`, this plan, and measurement evidence are updated at each
  completed phase.
