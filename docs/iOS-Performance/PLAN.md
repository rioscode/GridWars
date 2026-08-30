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
- [x] Three current-release measurements on the same physical iPhone.
- [x] Representative one-millisecond Time Profiler samples and a separate
      30-second Allocations trace.
- [x] Phase 2 typed projectile/Green Square state, source-equivalent avoidance
      gate, and typed Black-Hole state in the projectile hot path.
- [x] Three Phase-2 physical-device Release traces and focused capture
      verification.
- [ ] Final post-Black-Hole follow-up CPU/allocation trace with the device
      unlocked.

The three wired iPhone 17 Pro Max runs measure only 13.99–16.79 presentation
updates per second. Median display spacing is about 66.7 ms, projectile work
alone takes about 16.2–16.4 ms per fixed step, and almost every display update
must catch up three or four fixed steps. The allocation trace records 1.22 GiB
and 21.27 million heap allocations in 30.852 seconds. Full evidence is in
`MEASUREMENTS-2026-08-30.md`. All runs remained at the same `Fair` thermal
state; USB profiling did not return the device to `Nominal` after idle cooling.

Phase 2 reduces projectile p50 from 16.2–16.4 ms to 5.1–5.6 ms, or
65.7–68.3 percent. The first run sustains 59.99 Hz; two immediately following
runs measure 53.25 and 49.69 Hz while projectile CPU remains stable. Green
Square allocation paths disappear completely. The first allocation trace then
exposed a separate 230.28-MB Black-Hole string-bridging path, which is now also
typed but still needs a final unlocked-device trace. Full evidence is in
`MEASUREMENTS-PHASE2-2026-08-30.md`.

## Observed scaling risks

1. Phase 2 removes repeated Green Square and Black-Hole dictionary bridging
   from the projectile path. Remaining projectile collision work still scales
   with every candidate pair in source order, but now measures 5.1–5.6 ms p50
   rather than 16.2–16.4 ms.
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

### Phase 2: typed projectile and Green Square state

- [x] Load projectile velocity once per half-step and pass it into collision and
  Black-Hole handling instead of reading and boxing dictionary values again.
- [x] Store projectile and Green Square live velocity in typed Swift state.
- [x] Add a source-equivalent predicted-danger distance gate before Green Square
  velocity mutation while preserving projectile-list order.
- [x] Store active/size state for live Black Holes in the same typed boundary
  after the allocation trace exposed repeated key bridging.
- [x] Repeat three physical-device Game Performance traces and the focused
  projectile captures.
- [ ] Repeat the final CPU/allocation trace after the Black-Hole follow-up.

### Phase 3: Grid and GPU work

- Measure `GridSimulation.push()` separately from `GridRenderer` path creation.
- Add a source-ordered batch API for projectile Grid impulses if simulation is
  significant.
- Remove per-frame bitmap allocation and texture creation from Particle Grid
  styles.
- Compare 50-Hz Grid presentation, SpriteKit sprite/mesh approaches, and a
  narrowly scoped iOS Metal Grid pass. Do not adopt Metal without updating the
  architecture decision and passing the capture boundary.

### Phase 4: particle presentation

- Compare the current `SKShapeNode` line with a shared-texture
  `SKSpriteNode` strip while retaining individual colour, alpha, additive
  overlap, line width, pixel alignment, and style-3 layer order.
- Retire excessive hidden pool nodes after large capacity/burst reductions.
- Consider an instanced Metal particle pass only if the SpriteKit result is
  still outside the frame budget and visual parity can be demonstrated.

### Phase 5: entity state and interpolation

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
