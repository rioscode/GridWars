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
      all 143 macOS tests pass.
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
- [x] Deterministic active-enemy fixtures: `--ios-active-enemy-benchmark`
      (1x) and `--ios-active-enemy-benchmark-2x` (2x). They run live enemy
      AI, Triangle bonds, Black-Hole AI, projectiles, particles, and Grid work.
- [x] Frame-local source-ordered `EnemyFrameIndex` for the regular enemy loop,
      same-kind separation peers, and the Black-Hole list. It refreshes at
      observed layer-count mutations and keeps removed-node guards.
- [x] First valid physical-device 1x/2x Release trace pair, including a
      Time-Profiler export and direct display-swap cadence check.
- [x] Benchmark-only 2x projectile-cap override: the first trace discovered
      that the requested 1,000 shots were silently limited to 500.
- [ ] Corrected 2x trace plus three repeatable Release runs per profile.

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

1. The existing benchmark measures projectiles against 83 frozen enemies. Its
   fixed-step function updates particles, Grid, and projectiles but skips live
   enemy AI. It therefore cannot confirm or reject the reported many-enemy
   slowdown.
2. The first Phase-3 index removes the repeated complete-layer classification
   in `updateEnemies()`, repeated Black-Hole filtering, and cross-kind scans in
   separation. Same-kind separation remains quadratic and must be measured at
   1x/2x before a spatial broad phase is justified.
3. Enemy Black-Hole influence repeatedly calls `enemies(of: .blackHole)`, and
   triangle partner resolution repeatedly scans children by string ID.
   Triangle pairing can nest those scans, while bond visuals are removed and
   recreated as `SKShapeNode`/`CGPath` objects every fixed step.
4. Phase 2 removes Green Square and Black-Hole dictionary bridging from the
   projectile path, but projectile collision still checks ordered per-kind
   arrays linearly. With many enemies and many shots, work still scales roughly
   with projectile count times enemy count.
5. Most enemy kinds still read and write velocity, rotation, freeze, and
   type-specific state through `NSMutableDictionary`/`NSNumber` on every fixed
   step.
6. Presentation interpolation collects every live entity twice per fixed step
   and builds an `ObjectIdentifier` dictionary plus snapshot arrays. This grows
   linearly with enemies, projectiles, snake segments, bonds, trails, and
   effects. The Phase-2 trace already assigns 740.07 MB to presentation.
7. Each surviving projectile half-step calls `GridSimulation.push()`, which
   visits a 7x7 point neighborhood. Five hundred projectiles can therefore
   produce about 49,000 Grid-point checks per fixed step.
8. `GridRenderer` rebuilds paths every displayed frame. Particle Grid styles
   additionally allocate an arena-sized bitmap, create a `CGImage`, and upload
   a new `SKTexture` every frame.
9. `ParticleRenderer` pools allocations but still uses one `SKShapeNode` per
   line particle. Pool entries are grow-only and remain in SpriteKit's node
   tree after a burst.
10. The first active 1x/2x pair sustains 60 Hz, but it is not a replay of the
    reported hitch: its initial 2x shot cap was clipped to 500, it omits Snake
    tails, and it does not guarantee Triangle bonds. The full evidence and
    limits are in `MEASUREMENTS-ACTIVE-ENEMY-2026-08-30.md`.

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

The next measurement pass has a second deterministic scenario for active enemy
scaling. `--ios-active-enemy-benchmark` runs 80 active regular enemies, three
active Black Holes, and 500 moving projectiles. The `-2x` variant runs 160,
six, and 1,000 respectively; population caps are bypassed only for this
benchmark fixture. Both keep spawning, scoring, persistence, input, and audio
disabled, but run the source-order enemy, Triangle-bond, Black-Hole, projectile,
particle, and Grid paths. Aggregate `Enemy AI`, `Triangle Bonds`, and
`Black Hole AI` signposts sit inside the existing fixed-simulation lane. Do not
add per-entity signposts because their overhead would distort the result.

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

### Phase 3: active-enemy measurement and frame index

- [x] Add active-enemy 1x/2x fixtures and aggregate `Enemy AI`, `Triangle
  Bonds`, and `Black Hole AI` signposts while retaining the legacy frozen
  `--ios-performance-benchmark` for Phase-2 comparisons.
- [x] Build a source-ordered, frame-local `EnemyFrameIndex` for the regular
  enemy loop. It contains per-kind arrays and the small Black-Hole list,
  refreshes before each requested kind when the layer count changed, and keeps
  `parent != nil` guards for stale references.
- [x] Use that index for `updateEnemies`, same-kind separation peers,
  Black-Hole influence, and mutual Black-Hole deflection. It changes lookup
  cost only; it does not reorder updates or interactions.
- [x] Retain the first valid 1x/2x device traces. They show a 16.668-ms
  display-swap median, zero 100-ms hangs, and 60 displayed surfaces per steady
  second; the initial 2x trace has only 500 actual projectiles and is not a
  full double-shot comparison.
- [x] Keep the source 500-shot cap for gameplay, while allowing the opt-in
  synthetic 2x benchmark to create 1,000 shots as documented.
- [ ] Extend only after profiling: Snake-tail lookup and Triangle stable-ID
  lookup remain separate because they have different mutation/lifecycle rules.
- [ ] Add a deterministic 120-frame state digest before migrating further
  lookup paths or pooling Triangle bonds.
- [ ] Record the corrected 2x shot-overload trace, then retain three
  repeatable Release runs per profile with population counts after warm-up.

Verification: compare deterministic per-frame entity state before/after for at
least 120 fixed steps, run all enemy/triangle/Black-Hole captures, then repeat
1x/2x physical-device Release traces. Continue only if the profiler shows the
remaining dominant function.

### Phase 4: source-ordered spatial broad phase

- If projectile-versus-enemy checks remain dominant, index enemies in uniform
  cells and query only cells intersecting each collision/avoidance radius.
  Return candidates in original child order and retain the existing kind
  priority. Green Square queries use the projected danger point; Black Holes
  remain in their tiny ordered list.
- Reuse the spatial index for same-kind separation only if separation remains
  dominant after Phase 3. Update a moved enemy's cell at the same point in the
  source-ordered loop so later enemies observe the same current positions.
- Add deterministic equivalence tests between naive and indexed candidate
  selection for cell boundaries, equal positions, earlier/later moved enemies,
  Cube split, and removed nodes.

Stop condition: do not adopt the spatial path unless it materially lowers the
1x and 2x enemy-load p50/p95 while every deterministic state comparison and
focused capture remains accepted.

### Phase 5: typed live enemy state and Triangle presentation

- Move only profiler-proven hot fields first: enemy kind, velocity, rotation,
  freeze frames, stable ID, and partner ID. Keep `userData` synchronized only
  at spawn/capture and other low-frequency compatibility boundaries.
- Migrate Snake/Interceptor/Triangle-specific fields incrementally, guided by
  allocation call trees; avoid a single all-enemy rewrite.
- Pool Triangle bond nodes and mutate their endpoints, color, and visibility
  instead of removing and recreating `SKShapeNode`, `CGPath`, and dictionary
  metadata every fixed step.
- Verify all enemy lifecycle, Triangle, Snake, Interceptor, generator, and
  Black-Hole deterministic tests and captures.

### Phase 6: presentation snapshots

- Store previous/current transforms on typed live nodes or in stable indexed
  storage so the fixed step does not rebuild an `ObjectIdentifier` dictionary.
- Track only nodes that actually interpolate; keep camera, Grid, particles, and
  source layer order unchanged.
- Measure allocation bytes/rate and presentation p50/p95 before considering
  projectile sprite pooling.

### Phase 7: Grid, GPU, and particles

- Measure `GridSimulation.push()` separately from `GridRenderer` path creation.
- Add a source-ordered batch API for projectile Grid impulses only if simulation
  is significant.
- Remove per-frame bitmap allocation and texture creation from Particle Grid
  styles.
- Compare SpriteKit Grid/particle representations before considering a narrowly
  scoped iOS Metal pass. Do not adopt Metal without updating the architecture
  decision and passing the full capture boundary.
- Retire excessive hidden particle-pool nodes only after node-count evidence
  shows they contribute to the remaining device cost.

## Acceptance criteria

- Three repeatable physical-iPhone Release runs with no recurring 33-ms frame
  pattern during the benchmark.
- The fixed-step accumulator normally consumes at most one 20-ms simulation
  step per display update.
- At the observed 1x live enemy load, Enemy AI plus projectile processing stays
  inside a 12-ms p95 fixed-step CPU budget; the 2x fixture must not recreate a
  recurring 33-ms pattern.
- Doubling the enemy fixture must no longer cause approximately quadratic fixed
  simulation growth.
- No hot allocation call tree may terminate in `NSDictionary` string-key
  bridging or `NSNumber` boxing for live entity state.
- macOS Debug build, iOS Simulator Debug build, and macOS tests pass.
- Deterministic gameplay tests and accepted captures show no rule, ordering,
  layer, or raster regression.
- `FIDELITY.md`, this plan, and measurement evidence are updated at each
  completed phase.
