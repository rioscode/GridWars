# iOS Performance: Next Steps

Status: 2026-08-30, real shooting hitch reproduced and the PCM-player-node
mechanism fixed it in two physical A/B traces; final edge hardening passed
device launch smoke, while further enemy/collision work remains conditional on
a new real-device profile

This document is the long-form notebook for the next optimization phase. It is
intentionally more detailed than `PLAN.md` so the reasoning does not have to be
reconstructed from Git and Instruments traces.

## One-sentence summary

Phase 2 fixed the measured projectile-state bottleneck, but the existing stress
benchmark freezes all enemies and never executes live enemy AI; the reported
lag with many real enemies therefore points to an unmeasured scaling path that
must be instrumented before the next optimization.

## Current state

- The immutable pre-optimization checkpoint is commit `aac3d9c`, tagged
  `pre-ios-performance-optimization`.
- Phase 1 classifies projectile collision candidates once per update instead
  of repeatedly filtering the enemy tree for every projectile half-step.
- Phase 2 keeps projectile and Green Square velocity in typed Swift state,
  gates Green Square avoidance with a source-equivalent distance test, and
  keeps Black-Hole size/active state out of the projectile dictionary hot path.
- Projectile p50 fell from about 16.2–16.4 ms to 5.1–5.6 ms per fixed step, a
  65.7–68.3-percent reduction.
- One deterministic Release run reached 59.99 Hz without 33-ms frames. Two
  immediately following runs reached 53.25 and 49.69 Hz while projectile CPU
  stayed near 5.6 ms.
- The five focused projectile captures remained exactly at the accepted
  `0.00339833...0.00385059` normalized differences.
- All 143 macOS tests and the required macOS/iOS builds pass.
- A user-visible many-enemy gameplay state still lags on the physical iPhone.

## Phase-3 implementation checkpoint

The blind spot is now executable rather than merely documented.

- `--ios-performance-benchmark` stays unchanged as the frozen Phase-1/2
  projectile comparison fixture.
- `--ios-active-enemy-benchmark` starts 80 active mixed enemies, three active
  Black Holes, and 500 moving projectiles.
- `--ios-active-enemy-benchmark-2x` scales the same deterministic fixture to
  160 active enemies, six Black Holes, and 1,000 projectiles. The fixture alone
  bypasses normal population caps so its scale is not silently clipped.
- The active path preserves the relevant source order: particle/Grid work,
  Black-Hole player pull, Triangle-player collision, regular enemy AI,
  Triangle bonds, Black-Hole AI, projectiles, then Interceptor shield cache.
- Instruments now receives one aggregate lane each for `Enemy AI`, `Triangle
  Bonds`, and `Black Hole AI`; no per-enemy signposts were added.
- `EnemyFrameIndex` classifies the mixed SpriteKit enemy layer once per
  `updateEnemies` call in existing child order. Its per-kind arrays now serve
  regular updates, same-kind separation, enemy Black-Hole influence, and
  Black-Hole mutual deflection. The index refreshes before each requested kind
  if layer count changed, while stale cached nodes still require a live parent.

This is deliberately a first lookup-cost change, not a spatial rewrite. Snake
tails, Triangle stable-ID lookup, Triangle bond pooling, presentation snapshots,
and projectile spatial queries remain separate measurable steps.

## First physical active-enemy result

Two valid 10-second wired Release traces are now retained. Both have a
16.668-ms display-swap median, 60 displayed surfaces in every steady second,
and no 100-ms Instruments hang. The first conclusion is therefore negative but
valuable: this fixture does not reproduce the user-visible crowded-wave lag.

| Observation | 1x | Initial 2x | What it means |
| --- | ---: | ---: | --- |
| Display Update median | 4.968 ms | 5.079 ms | No display-side overload in this fixture. |
| Fixed Simulation median | 3.089 ms | 3.316 ms | The full measured subset stays far below 20 ms. |
| Enemy AI median | 0.213 ms | 0.625 ms | Active enemy work scales, but is not yet dominant. |
| Projectile median | 2.711 ms | 2.495 ms | Not a valid 2x shot comparison: both traces have 500 actual shots. |

The trace audit caught a benchmark correctness defect before it could become a
presentation claim: `--ios-active-enemy-benchmark-2x` requested 1,000 shots,
but the normal source cap in `spawnProjectile` limited it to 500. The cap stays
500 in real gameplay. Only the explicit synthetic 2x benchmark now raises it;
the corresponding iPhone trace still needs to be recorded.

The Time Profiler changes the next narrative beat. In this fixture,
`updateProjectiles`/`checkProjectileCollisions` and Grid/presentation work
outweigh active enemy AI. That does not disprove an enemy-specific hitch: the
fixture does not create Snake tail chains, guaranteed Triangle bonds, real
kills, score/effect churn, or a normal `simulateFrame()` replay. Those are now
the evidence-based requirements for the next benchmark rather than vague
future ideas.

## Live shooting finally reproduces the user report

The normal game was attached on the same wired iPhone while sustained user
firing was reproduced. Its retained display-surface window is unambiguously
bad: 23 intervals have a 150.014-ms median, a 216.687-ms p95, and a
333.364-ms maximum; all 23 are slower than 33.33 ms and 16 are slower than
100 ms. This is the first device artifact that matches the reported feeling.

The call stacks change the optimization order. `AudioFileOpenURL`,
`AVAudioPlayer.init(contentsOf:)`, `prepareToPlay`, AudioQueue allocation, and
AudioQueue XPC calls all appear on the main thread below real projectile
impacts and enemy kills. The port had constructed a new player for every
one-shot effect, re-resolved its resource URL, and pruned its player array in
the same game frame. The original instead loads sound samples in `LoadSounds`
and uses `CueSound` in `PlaySound2`.

The first audio pool was intentionally constrained and fidelity-oriented: it
prewarmed overlapping voices for shot birth, wall hits, enemy hits, and
interceptor hits; retained source rate/pan/volume; and recycled its oldest
voice only at a bounded limit. Its A/B result was useful precisely because it
was not good enough: file-opening stacks vanished, but 50 live display
intervals still had a 100.009-ms median (p95 216.687 ms, maximum 283.359 ms).
`AVAudioPlayerCpp::prepareToPlayQueue`, AudioQueue allocation, and XPC
remained below projectile impacts.

The follow-up now uses decoded PCM buffers and preconnected
`AVAudioEngine`/`AVAudioPlayerNode` voices. That preserves the same polyphony,
source rate, pan, volume, and oldest-voice policy without muting, debouncing,
or reordering effects. It removes the remaining `AVAudioPlayer` queue
mechanism from the hot path. All 16 bounded voices are preconnected for each
of the four firing-path effects, so a dense salvo cannot mutate the live audio
graph after exhausting a smaller warm-up pool. Black-hole loop teardown now
detaches only loop nodes and does not stop this shared one-shot engine. The
two measured PCM runs precede this final hardening but validate the same
decoded-buffer/player-node mechanism. The final signed build installed and
launched successfully on the same wired iPhone; its immediate third Instruments
attach timed out waiting for the device to boot, so no unusable trace is being
presented as fresh evidence.

One intentionally deferred audio-fidelity guardrail remains: at the global
128-voice safety cap, an effect with no existing local voice can be skipped
instead of borrowing an idle voice from another effect. It was not observed in
the real firing trace and does not explain the hitch. Treat it as a separate
mixing/pool-lifecycle test task rather than quietly changing its behavior in
this performance milestone.

The decisive repeat contains 223 contiguous display intervals with a 16.668-ms
median, 16.668-ms p95, 33.336-ms maximum, one 33-ms interval, and no 50-ms or
100-ms interval. The Game Performance template also produces an exact
4,975.457-ms gap in the retained record; it has no potential-hang event and is
consistent with its `Windowed (5 seconds)` capture behavior, so it is preserved
in the raw artifact but excluded from the frame-pacing summary. The first PCM
run independently reaches a 16.668-ms median and has no potential hang, even
though its retained interval mix is less steady. The prior 150.014-ms median
was therefore not merely a warmer-device or fixture effect.

This changes the priority with evidence: do not immediately rewrite collision
or rendering after a performance win just because those systems look expensive
in source. Preserve the clean audio A/B. Only a fresh real-device trace that
shows a dominant residual cost authorizes the next change.

## The benchmark blind spot

The most important new finding is not yet another slow function. It is a gap in
what the benchmark exercises.

The benchmark creates 80 mixed enemies plus three Black Holes, but gives every
enemy `1_000_000` freeze frames. More importantly, its fixed-step function runs
particle simulation, color cycling, Grid simulation, and projectiles, then
increments the frame. It does not call `updateEnemies()`, Triangle bond work,
generators, or the normal player/enemy flow.

Relevant Swift locations at commit `bb94fe1`:

| Evidence | Location | Consequence |
| --- | --- | --- |
| 80 benchmark enemies are created | `GameScene.swift:1043-1061` | Enemy count exists for projectile collision load. |
| Benchmark enemies receive 1,000,000 freeze frames | `GameScene.swift:1050-1057` | They are intentionally static. |
| Benchmark fixed step calls particle, Grid, and projectile updates only | `GameScene.swift:2780-2800` | Live enemy AI is absent from measured CPU. |
| Normal gameplay runs the complete enemy and Triangle order | `GameScene.swift:2750-2778` | The user's laggy state performs much more work than the benchmark. |

The correct public explanation is: Phase 2 did what its trace promised, but
the trace did not cover the newly reported workload. This is a measurement
scope problem, not evidence that the Phase-2 result was fabricated or useless.

## Code-level scaling evidence

### Repeated full child-list classification

`updateEnemies(kinds:)` loops through every requested kind. For each kind it
filters all `enemyLayer.children` and bridges the `kind` string from
`userData`. Normal gameplay calls it once for nine non-Black-Hole kinds and
again for Black Holes.

Approximate classification work per fixed step:

`10 kind passes × all enemy-layer children`

This part is linear, but repeated ten times and allocation-prone because the
kind is stored as an Objective-C dictionary string.

Code: `GameScene.swift:4160-4169`.

### Quadratic separation broad phase

For each live enemy that has a separation rule, `applySeparation` scans the
complete enemy child array, rejects different kinds, and checks distance only
after the scan.

Approximate worst-case work:

`N moving enemies × N child scan = O(N²)`

Doubling enemies can therefore approach four times the separation comparisons.
Even a mixed wave still pays the full child scan for every participating
enemy, because kind rejection happens inside the inner loop.

Code: `GameScene.swift:4941-4970`.

### Projectile count times enemy count

Phase 1 preserves ordered arrays by enemy kind. That avoids repeated tree
classification, but each projectile still walks those arrays until it finds a
collision. Green Square avoidance also considers every Green Square in source
order.

Approximate work:

`P projectiles × E relevant enemies × 2 half-steps`

At the benchmark's 500 projectiles and 80 enemies, projectile processing is
already 5.1–5.6 ms p50 after Phase 2. A real wave with substantially more
enemies can grow this path again even though the per-pair work is cheaper.

This is why the next index should be reusable by both enemy separation and
projectile collision broad phases.

### Repeated Black-Hole lookup

Most enemy types call `applyBlackHoleInfluence`. That function calls
`enemies(of: .blackHole)`, which filters the complete child list every time,
even though live Black Holes are capped at a tiny count.

Approximate work:

`N affected enemies × N child filter`, followed by only a few real Black-Hole
checks.

Code: `GameScene.swift:4982-5038` and `5516-5520`.

### Triangle partner and pairing scans

`trianglePartner(of:)` resolves a string ID with `enemyLayer.children.first`.
That linear lookup is used from movement, pairing, bond rendering, collision,
detach, and Black-Hole interaction paths.

`pairEligibleTriangle` can then loop over every candidate and ask whether each
candidate already has a partner, triggering another child scan. With many
Triangles this can become worse than a simple quadratic loop.

Code:

- partner lookup: `GameScene.swift:4810-4815`;
- pairing: `GameScene.swift:4756-4767`;
- bond/player collision lookup: `GameScene.swift:4769-4786`.

### Triangle bond allocation churn

Every fixed step removes all `triangleBond` nodes and creates new paths,
`SKShapeNode` objects, colors, and `NSMutableDictionary` metadata for the same
logical pairs.

Code: `GameScene.swift:4713-4753`.

This is a strong allocation candidate but should be measured separately from
Triangle AI. Pooling bond nodes is safer than changing Triangle gameplay.

### Presentation snapshot scaling

At the start and end of every fixed step, presentation interpolation collects
world, player, trails, every enemy-layer child, every projectile, pickups, and
effects. It rebuilds an `ObjectIdentifier` dictionary and a snapshot array, and
later iterates those snapshots again for interpolation.

Code: `GameScene.swift:1960-2028`.

The Phase-2 allocation trace assigns 740.07 MB to presentation. Many enemies,
Snake segments, and Triangle bonds increase this work even if enemy AI itself
were free.

## Ranked hypotheses

These are hypotheses, not yet measured conclusions.

1. Projectile-versus-enemy pair growth. Confidence: high. The 500-projectile
   benchmark already spends about 5.6 ms with only 80 enemies, and the current
   broad phase is linear in enemies per projectile.
2. Same-kind separation scanning. Confidence: high. The source-equivalent
   implementation contains a direct full-list inner loop for each enemy.
3. Repeated kind/Black-Hole/partner classification and Objective-C bridging.
   Confidence: high that it wastes work; unknown share of total frame time.
4. Presentation snapshot and Triangle bond allocations. Confidence: medium to
   high, supported by the 740.07-MB presentation allocation path and visible
   per-step node creation.
5. SpriteKit node/physics/render submission overhead at high entity counts.
   Confidence: medium. Plausible, but it must be established with Instruments
   rather than inferred from node count alone.
6. Grid and particle GPU work. Confidence: already established as a later
   constraint, but it does not specifically explain why adding enemies makes
   the game worse.

## Next execution plan

### Step 1: reproduce the user's real workload

Goal: record what “many enemies” means on the actual device.

Actions:

- Add low-frequency counters for enemies by kind, Snake segments, Triangle
  bonds, projectiles, active particles, total nodes, draw count, and fixed
  steps per display update.
- Record the real gameplay state that visibly lags.
- Note the exact count at the first visible hitch, not only the worst state.
- Capture a 30-second Release Game Performance trace and a separate Allocation
  trace with the phone unlocked.

Verification:

- The retained trace contains the reported lag.
- The notes include the entity counts and thermal state for the same interval.
- We can distinguish CPU fixed-step time, render/presentation time, and GPU
  frame span.

Do not optimize before this trace unless a correctness bug blocks recording.

### Step 2: create an active-enemy benchmark

Goal: make the report reproducible without manually playing to a late wave.

Actions:

- Add deterministic 1x and 2x fixtures based on the observed real counts.
- Use active enemy AI and the normal update order.
- Disable random spawning, persistence, input, score progression, audio, and
  death while preserving movement, separation, Black Holes, Triangle logic,
  projectiles, Grid pushes, and presentation.
- Add aggregate signposts for:
  - enemy index/classification;
  - enemy AI total;
  - separation;
  - Black-Hole influence;
  - Triangle pairing and bonds;
  - projectiles;
  - presentation snapshot collection;
  - Grid simulation;
  - particle simulation.

Verification:

- Three 30-second 1x and three 30-second 2x Release traces.
- No per-entity signposts, logging, or debug overlays in timed regions.
- Benchmark state is deterministic across repeated runs.

### Step 3: add a source-ordered enemy frame index

Goal: remove repeated full-tree filtering without changing behavior.

Proposed contents:

- ordered arrays by enemy kind;
- ordered Black-Hole list;
- ordered Snake/head/tail lists where needed;
- ordered Triangle list;
- stable enemy-ID-to-node lookup;
- original child order/index for later spatial queries.

The index is built once per fixed step and refreshed only at explicit mutation
boundaries. Removed nodes remain guarded by `parent != nil`. Cube children,
generator births, Snake removal, and Black-Hole absorption must become visible
at the same source-equivalent point as today.

Expected gains:

- one classification pass instead of roughly ten;
- no repeated `enemies(of: .blackHole)` filtering;
- O(1) Triangle partner lookup;
- less string-key bridging;
- one shared foundation for projectile and separation broad phases.

Verification:

- Capture per-frame positions, velocities, rotations, parent relationships,
  Triangle partners, health, and active counts for at least 120 deterministic
  fixed steps before and after.
- Arrays must preserve child order exactly.
- Run all enemy lifecycle, Triangle, Snake, Interceptor, generator, Black-Hole,
  and projectile tests/captures.
- Re-measure before adding a spatial structure.

### Step 4: add a spatial broad phase only if the trace justifies it

Goal: avoid pair checks between entities that cannot interact.

Projectile queries:

- keep current collision kind priority;
- return candidates in original child order within each kind;
- query collision cells around the projectile position;
- query Green Squares around the projected danger point used by the original
  avoidance formula;
- keep the tiny Black-Hole array ordered and unbatched;
- refresh after Cube split before the next half-step.

Separation queries:

- use cells no smaller than the maximum relevant separation diameter;
- initialize with all current positions;
- relocate a node in the index at the same point its position changes in the
  ordered update loop;
- sort nearby candidates by original child index before applying forces;
- preserve the source rule that earlier enemies may already have moved while
  later enemies have not.

Equivalence tests:

- naive versus indexed results for randomized deterministic layouts;
- exact cell edges and corners;
- equal X or Y coordinates and zero differences;
- earlier-moved and later-unmoved nodes;
- removed nodes;
- Cube split during projectile half-steps;
- Green Square projected-danger boundary at 99.998/99.999;
- all Super/Bouncy/Black-Hole projectile scenarios.

### Step 5: migrate profiler-proven enemy state

Goal: remove remaining `NSDictionary`/`NSNumber` traffic from the live loop.

First candidates:

- kind;
- velocity;
- rotation;
- freeze frames;
- stable enemy ID;
- Triangle partner ID.

Later candidates only if measured:

- Snake heading and turn direction;
- Interceptor heading, turn remaining, last-played counter, shield geometry;
- Cube tier and Seeker mean;
- Triangle strength/resistance.

Use the same boundary as Phase 2: typed state is authoritative during live
simulation; dictionary metadata is synchronized only for low-frequency legacy
and capture compatibility. Avoid migrating all fields in one change.

### Step 6: pool Triangle bonds

Goal: preserve the exact visual while removing per-step node/path churn.

- Keep one reusable bond node per active logical pair.
- Update its two endpoints, stroke color, visibility, and layer position.
- Hide unused bond nodes instead of removing them.
- Preserve duplicate/source ordering if both endpoints intentionally emit a
  bond in the accepted renderer.

Verification captures:

- `triangle-motion`;
- `triangle-bond`;
- `triangle-hit`;
- `triangle-black-hole`;
- combined gameplay and HUD/layer-order captures.

### Step 7: replace global presentation snapshot hashing

Goal: stop rebuilding the per-step identity dictionary for every entity.

- Store previous/current transform on typed live nodes or a stable indexed
  record.
- Track only nodes that participate in interpolation.
- Preserve authoritative 50-Hz state and presentation-only interpolation.
- Keep camera-relative stars, particles, Grid interpolation, and layer order
  unchanged.

This step should follow enemy indexing because the frame index can supply
stable entity storage and ordering.

### Step 8: return to Grid/GPU/particles

Only after the active-enemy 1x/2x trace is inside the fixed-step budget:

- isolate Grid simulation pushes from Grid path creation;
- address the 692.06-MB Grid allocation path;
- remove per-frame bitmap/texture creation from particle Grid styles;
- reduce hidden particle-pool nodes if node-count evidence supports it;
- evaluate a narrowly scoped Metal pass only after SpriteKit options and full
  visual acceptance.

## Success criteria

Primary device criteria:

- Three repeatable physical-iPhone Release runs at the observed 1x workload
  without a recurring 33-ms frame pattern.
- Enemy AI plus projectile processing remains below 12 ms p95 per fixed step.
- The accumulator normally consumes no more than one 20-ms step per display
  update.
- The 2x fixture does not return to the old catch-up spiral.
- Doubling enemy count no longer produces approximately quadratic fixed-step
  growth.
- No hot allocation stack ends in dictionary string bridging or number boxing
  for live entity state.

Correctness criteria:

- Original enemy kind order and child order are unchanged.
- Earlier/later mutation visibility is unchanged.
- Cube split, Snake cascade, Black-Hole absorption, Triangle pairing/breaking,
  Interceptor shield, score/destruction order, and random-call order remain
  source-equivalent.
- All 141 tests pass, plus new index/spatial equivalence tests.
- Required macOS/iOS builds pass.
- Focused and full capture comparisons remain inside accepted boundaries.

Stop rules:

- Do not introduce spatial indexing if the frame index already removes the
  measured bottleneck.
- Do not migrate unmeasured enemy fields.
- Do not adopt Metal merely because CPU indexing work is difficult.
- Do not report 60 Hz from one run as final acceptance; require three repeatable
  runs and disclose thermal/device state.

## Risk register

| Risk | Why it matters | Mitigation |
| --- | --- | --- |
| Candidate reordering | GridWars behavior depends on kind and child order. | Store original child index and sort query results before applying interactions. |
| Stale index after mutation | Cube split/removal can change the next half-step. | Refresh at explicit mutation boundaries and keep `parent != nil` guards. |
| Static spatial snapshot | Earlier enemies move before later enemies. | Dynamically relocate nodes at the same ordered point as live movement. |
| Over-instrumentation | Per-entity signposts can become the bottleneck. | Use aggregate scopes and low-frequency counters only. |
| Thermal comparison error | Back-to-back USB runs already degraded frame rate. | Record thermal state, cool between runs, and compare identical run order. |
| Benchmark-only optimization | A synthetic win may miss real gameplay again. | Pair every benchmark result with one retained real-play trace. |
| Giant typed-state rewrite | Broad migration risks subtle source drift. | Move only call-tree-proven fields in small commits with captures. |
| Triangle pooling alters draw order | Additive overlap and duplicate bonds can change pixels. | Preserve accepted source order and compare dedicated Triangle captures. |

## Claims that are currently supported

- Phase 2 reduced measured projectile p50 by 65.7–68.3 percent.
- The Green Square allocation stack disappeared from the Phase-2 trace.
- One run sustained 59.99 Hz without 33-ms intervals.
- The current benchmark does not execute active enemy AI.
- The code contains repeated full-list scans and a quadratic separation broad
  phase.
- The user still observes lag with many live enemies on the deployed iPhone.

## Claims that are not yet supported

- “Enemy separation is definitely the largest remaining bottleneck.”
- “The game is now 60 FPS.”
- “The Black-Hole typed-state follow-up achieved a specific allocation
  reduction.”
- “SpriteKit itself is the problem.”
- “Metal is required.”
- “A spatial index will produce a specific percentage improvement.”
- “Thermal throttling fully explains runs 2 and 3.”

Use hypothesis language until the active-enemy trace exists.

## Data capture checklist

- Git commit and dirty-tree state;
- Xcode/Instruments version;
- iPhone model and iOS build;
- wired/wireless connection;
- Release configuration and signing state;
- device thermal state before and after;
- enemy counts by kind;
- Snake head/tail count;
- Triangle pair/bond count;
- Black-Hole count and size/active state;
- projectile count and upgrade state;
- active particle count;
- SpriteKit node/draw/quad counts;
- display interval p50/p95 and >=33-ms count;
- fixed steps per display p50/p95;
- Enemy AI, separation, projectile, Grid, particle, snapshot, and render
  signpost p50/p95;
- allocation bytes, count, rate, persistent bytes, and heaviest app-owned
  stacks;
- GPU frame-span p50/p95 when available;
- capture comparison results;
- test/build commands and outcomes.

## Glossary for non-specialists

- Fixed step: the authoritative game simulation advances every 20 ms, or 50
  times per second, regardless of display refresh.
- Presentation: the visual interpolation shown between fixed simulation steps.
- Catch-up spiral: a slow display frame accumulates several fixed steps, whose
  extra work delays the next display frame and creates more catch-up work.
- Hot path: code executed often enough that a small per-call cost becomes a
  large frame cost.
- Bridging: conversion between Swift values and Objective-C container values
  such as `NSNumber` and `NSDictionary`.
- Broad phase: a cheap filter that rejects entity pairs too far apart to
  interact.
- Narrow phase: the exact gameplay collision or influence test for remaining
  candidates.
- Spatial index: a map from arena regions to nearby entities.
- Source order: the exact child/kind traversal order inherited from the
  original game; changing it can change behavior.
- Pooling: reusing nodes or objects instead of destroying and recreating them
  every frame.
- p50/p95: median and 95th-percentile timing. p95 exposes recurring slow frames
  that an average can hide.
