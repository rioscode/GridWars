# Physical iPhone Release Measurements — 2026-08-30

## Result

The deterministic heavy-load benchmark is CPU-bound and does not meet the
60-Hz acceptance target on the measured iPhone. Presentation runs at roughly
14–17 updates per second. The fixed-step accumulator consumes three to four
20-ms simulation steps per display update instead of normally consuming one.

The dominant cost is projectile processing, specifically Green Square
avoidance and the associated `NSMutableDictionary`/`NSNumber` bridging. Grid
and presentation construction are small CPU contributors in comparison. GPU
time is also above the 60-Hz budget at p95 and becomes the next constraint once
the projectile CPU path is reduced.

## Environment

- Source: commit `59145e9` (`perf: reduce projectile collision overhead`)
- Build: signed `GridWars-iOS` Release, Swift whole-module optimization
- Device: iPhone 17 Pro Max (`iPhone18,2`), iOS 26.6.1 (`23G83`)
- Connection: wired USB
- Scenario: `--ios-performance-benchmark`
- Load: 500 projectiles, 80 mixed enemies plus three Black Holes, deforming
  point Grid, and 2,048 style-1 particles
- Instruments: Xcode 26.6 / Instruments 16.0 (`17F113`)
- Capture: three 35-second Game Performance recordings retaining a 30-second
  window, plus one 30-second Allocations recording
- Thermal state: `Fair` throughout all three runs. Two minutes of idle cooling
  still returned `Fair` while USB profiling/charging was active; no run crossed
  into `Serious` or `Critical`.

Raw traces are retained locally below
`.build/ios-performance/2026-08-30-device-release/` and are intentionally not
committed.

## Frame pacing

Metrics use points-of-interest timestamps after a five-second warm-up.
Display interval is the time between consecutive `Display Update` begins.
Main-thread CPU is estimated from the trace's one-millisecond samples grouped
by display interval.

| Metric | Run 1 | Run 2 | Run 3 |
| --- | ---: | ---: | ---: |
| Mean presentation rate | 15.08 Hz | 13.99 Hz | 16.79 Hz |
| Display interval p50 | 66.670 ms | 66.686 ms | 66.276 ms |
| Display interval p95 | 83.352 ms | 100.015 ms | 83.347 ms |
| Display intervals >=33 ms | 461/461 | 428/428 | 497/517 |
| Fixed steps/display mean | 3.31 | 3.55 | 2.97 |
| Fixed steps/display p50 | 3 | 4 | 3 |
| Fixed steps/display p95 | 4 | 5 | 4 |
| Displays with >1 fixed step | 461/461 | 428/428 | 496/517 |
| Main-thread CPU/display p50 | 55.0 ms | 58.5 ms | 53.0 ms |
| Main-thread CPU/display p95 | 74.0 ms | 92.65 ms | 70.0 ms |

Recurring 33-ms frames are therefore not an isolated hitch pattern: almost
every presented update is slower than 33 ms, and the median is approximately
66.7 ms.

## Signpost and GPU timings

| Interval | Run 1 p50/p95 | Run 2 p50/p95 | Run 3 p50/p95 |
| --- | ---: | ---: | ---: |
| Fixed Simulation | 16.255 / 17.829 ms | 16.484 / 18.887 ms | 16.234 / 17.533 ms |
| Projectiles | 16.179 / 17.748 ms | 16.409 / 18.806 ms | 16.159 / 17.454 ms |
| Grid Render | 0.721 / 0.806 ms | 0.715 / 0.828 ms | 0.726 / 0.796 ms |
| Presentation Render | 1.294 / 1.451 ms | 1.283 / 1.512 ms | 1.305 / 1.423 ms |
| GPU frame span | 16.137 / 30.110 ms | 15.420 / 30.770 ms | 14.654 / 30.664 ms |

Projectile processing consumes effectively the complete fixed simulation
budget. Because each late presentation causes three or four fixed steps, that
single cost expands into roughly 49–67 ms of CPU work before presentation.

The representative Run-1 Time Profiler stream attributes 91.71% of sampled
main-thread time to `updateProjectiles()`, 70.57% to
`checkProjectileCollisions(_:candidates:)`, and 47.07% to
`runGreenSquare(_:awayFrom:)`. `renderGrid()` accounts for 1.17% and
`renderPresentation()` for 2.32%.

## Allocations

The 30.852-second Allocations recording reports:

- 1.22 GiB total heap allocation, approximately 40.49 MiB/s;
- 21,273,467 total heap allocations, approximately 689,535 allocations/s;
- 21,210,762 transient heap allocations;
- 11.18 MiB and 62,705 allocations still persistent at the end.

The inclusive allocation call tree assigns 408.70 MB to
`updateProjectiles()`, 274.83 MB to projectile collision checking, and
224.32 MB to Green Square avoidance. The heaviest Green Square stack terminates
in `NSPlaceholderNumber.initWithDouble`, confirming that per-projectile
`NSMutableDictionary` writes box new number objects. The three inclusive paths
represent approximately 33.0%, 22.2%, and 18.1% of all recorded allocation
bytes respectively.

## Decision

Phase 1 removed repeated enemy-list classification, but it is not sufficient
to restore smooth presentation. A pre-Phase-1 percentage cannot be claimed
because the immutable baseline predates the deterministic benchmark harness.

The next implementation phase should:

1. load projectile velocity once per half-step and pass it directly through
   collision and Black-Hole handling;
2. move projectile and Green Square live velocity out of
   `NSMutableDictionary`/`NSNumber` storage into typed Swift state;
3. retain the original projectile-list order while avoiding work for Green
   Square/projectile pairs whose predicted danger vector cannot be inside the
   source's 100-unit avoidance radius;
4. rerun the same three traces and the focused projectile captures before
   changing Grid or particle rendering.

After the CPU path is reduced, investigate the 30.1–30.8-ms GPU p95. The
current evidence does not support prioritizing CPU-side Grid rendering first.
