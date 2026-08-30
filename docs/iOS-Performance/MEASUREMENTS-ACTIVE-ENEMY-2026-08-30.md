# Physical iPhone Active-Enemy Measurements — 2026-08-30

## Result

The first valid active-enemy traces do **not** reproduce the reported hitch.
Both synthetic fixtures present at 60 Hz on the wired iPhone 17 Pro Max, with
no display interval at or above 20 ms and no Instruments hang above 100 ms.

They still establish a ranking: projectile collision and Grid/presentation
rendering cost materially more than active regular-enemy AI in this workload.
Doubling the active enemy population raises Enemy AI from 0.213 ms median to
0.625 ms median, without approaching the 20-ms fixed-step budget.

The initial 2x result is deliberately **not** a complete double-shot result.
The fixture requested 1,000 projectiles, but `spawnProjectile` retained the
normal 500-projectile source cap. It therefore exercised 160 regular enemies
and six Black Holes, but only 500 projectiles. A benchmark-only cap override
has been implemented for the following run; no comparison percentage is
claimed until that corrected trace exists.

## Environment

- Source: commit `ef10fee` (`perf: index active enemy updates`)
- Build: signed `GridWars-iOS` Release, whole-module optimization
- Device: iPhone 17 Pro Max (`iPhone18,2`), iOS 26.6.1 (`23G83`)
- Connection: wired USB
- Instruments: Xcode 26.6 / Instruments 16.0 (`17F113`)
- Template: Game Performance, attached to the running app
- Timed window: valid 10.000-second Instruments window per trace
- Signpost retention: the Game Performance "Windowed (5 seconds)" export
  retains approximately seconds 4–10 for display/rendering signposts and
  approximately five seconds of fixed-step samples. CPU sample totals below
  use their separate 9.991-second Time Profiler window.
- Raw artifacts: `.build/ios-performance/2026-08-30-active-enemy-release/`

The earlier `active-1x-run1.trace` is malformed and excluded. The two valid
traces are `active-1x-run2.trace` and `active-2x-run1.trace`.

## Fixture population

| Trace | Regular enemies | Active Black Holes | Requested projectiles | Actual projectiles |
| --- | ---: | ---: | ---: | ---: |
| 1x | 80 | 3 | 500 | 500 |
| 2x, initial implementation | 160 | 6 | 1,000 | 500 |

The 2x fixture intentionally bypasses normal enemy population guards. It is a
synthetic scale test, not evidence for a source-valid late-game wave.

## Signpost timings

Values are milliseconds per signpost interval in the retained signpost tail
(about six seconds; about five seconds for fixed simulation). Counts differ
when a phase is not executed in a given fixed step.

| Interval | 1x median / p95 / max | 2x median / p95 / max |
| --- | ---: | ---: |
| Display Update | 4.968 / 5.264 / 6.084 | 5.079 / 5.349 / 6.911 |
| Fixed Simulation | 3.089 / 3.234 / 3.685 | 3.316 / 3.508 / 3.685 |
| Enemy AI | 0.213 / 0.229 / 0.270 | 0.625 / 0.686 / 0.723 |
| Triangle Bonds | 0.007 / 0.011 / 0.015 | 0.054 / 0.079 / 0.091 |
| Black Hole AI | 0.041 / 0.045 / 0.050 | 0.014 / 0.024 / 0.030 |
| Projectiles | 2.711 / 2.846 / 3.297 | 2.495 / 2.629 / 2.734 |
| Presentation Render | 1.409 / 1.740 / 1.883 | 1.305 / 1.388 / 3.260 |
| Grid Render | 0.787 / 0.837 / 0.882 | 0.705 / 0.747 / 0.800 |

The apparent small decrease in the 2x projectile interval is not an
optimization result: it has the same actual shot count and remains a noisy
single-run observation.

## Frame pacing

The display-start cadence for both valid traces has a 16.668-ms median and an
approximately 16.725-ms p95. Each trace records 58 displayed surfaces in the
first second and 60 in each of seconds 1 through 9: 598 surfaces over ten
seconds. `potential-hangs` contains zero rows at its 100-ms threshold.

This directly rules out a recurring 33-ms pattern for the specific fixture;
it does not rule out the user's real crowded gameplay state.

## Time Profiler interpretation

One-millisecond samples estimate these active CPU shares:

| Metric | 1x | 2x |
| --- | ---: | ---: |
| All app CPU samples | 3.872 / 9.991 s (38.75% of one core) | 3.976 / 9.991 s (39.80%) |
| Main-thread samples | 3.729 s | 3.859 s |
| `updateProjectiles()` inclusive samples | 1.312 s | 1.215 s |
| `checkProjectileCollisions` inclusive samples | 0.759 s | 0.742 s |
| `renderPresentation` inclusive samples | 0.827 s | 0.776 s |
| `renderGrid` / `GridRenderer.addPointGrid` inclusive samples | 0.489 / 0.488 s | 0.393 / 0.391 s |
| `updateEnemies` inclusive samples | 0.134 s | 0.333 s |

Inclusive sample columns overlap and must not be summed. Their purpose here is
ranking: current active regular-enemy work is visible and scales up, but it is
not the dominant cost in this non-hitching fixture.

The Time Profiler's retained portion confirms the same direction: from second
four onward, app CPU is 38.65% of one core at 1x and 39.78% at the initial 2x;
`updateEnemies(kinds:)` grows from 76 ms to 197 ms inclusive, while
`checkProjectileCollisions` remains nearly flat at 439/443 ms. The device
remained in the Nominal thermal state during both traces.

## Benchmark fidelity limitations

- Projectiles start largely away from the regular-enemy grid, so this is not a
  hit/kill/effects replay.
- The fixture omits Snakes and their 24-tail chains, and does not guarantee
  Triangle pairs/bond visual churn.
- It runs a source-ordered subset of the normal gameplay frame, not
  `simulateFrame()` with real spawning, input, generators, pickups, trails,
  scores, effects, and deaths.
- Permanent Super/Bouncy upgrades and very high enemy health suppress normal
  lifecycle mutation.

## Next measurement decision

1. Record the corrected synthetic 2x run with 1,000 actual projectiles; keep
   it clearly labelled as an upper-bound stress profile.
2. Add a deterministic normal-frame late-game replay based on the state where
   the user sees the hitch. It must include real firing, Snake tails, paired
   Triangles, active shields, effects, and a once-per-second count digest.
3. Measure three Release runs and a separate Time Profiler plus Allocations
   trace for that replay before choosing Snake indexing, Triangle pooling, or
   a projectile spatial broad phase.
4. The current build also removes per-display `NSDictionary`/`NSNumber`
   bridging for star base coordinates and skips hidden stars. Re-measure that
   presentation change independently; do not attribute a gain before tracing
   it.
