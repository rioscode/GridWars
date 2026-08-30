# Physical iPhone Phase-2 Measurements — 2026-08-30

## Result

Typed projectile and Green Square velocity state removes the measured CPU
bottleneck. Projectile processing falls from roughly 16.2 ms to 5.1–5.6 ms
per fixed step, a 65.7–68.3-percent reduction. One run sustains 59.99 display
updates per second and the fixed-step accumulator normally consumes one step
or less per display update.

The three back-to-back recordings do not yet satisfy final acceptance. The
second and third runs fall to 53.25 and 49.69 updates per second even though
projectile CPU remains near 5.6 ms. The next limiting work is presentation and
Grid rendering/allocation rather than Green Square avoidance.

## Environment

- Comparison source: commit `59145e9` and
  `MEASUREMENTS-2026-08-30.md`
- Build: signed `GridWars-iOS` Release, Swift whole-module optimization
- Device: iPhone 17 Pro Max (`iPhone18,2`), iOS 26.6.1 (`23G83`)
- Connection: wired USB
- Scenario: `--ios-performance-benchmark`
- Load: 500 projectiles, 80 mixed enemies plus three Black Holes, deforming
  point Grid, and 2,048 style-1 particles
- Instruments: Xcode 26.6 / Instruments 16.0 (`17F113`)
- Capture: three 35-second Game Performance recordings retaining a 30-second
  window, plus one 30-second Allocations recording

Raw traces are retained locally below
`.build/ios-performance/2026-08-30-phase2-release/` and are intentionally not
committed.

## Frame pacing

Metrics use points-of-interest timestamps after a five-second warm-up.

| Metric | Run 1 | Run 2 | Run 3 |
| --- | ---: | ---: | ---: |
| Mean presentation rate | 59.99 Hz | 53.25 Hz | 49.69 Hz |
| Display interval p50 | 16.668 ms | 18.697 ms | 19.892 ms |
| Display interval p95 | 16.680 ms | 19.709 ms | 21.527 ms |
| Display intervals >=33 ms | 0/1,914 | 2/1,673 | 30/1,556 |
| Fixed steps/display mean | 0.83 | 0.94 | 1.01 |
| Fixed steps/display p50 | 1 | 1 | 1 |
| Fixed steps/display p95 | 1 | 2 | 2 |
| Displays with >1 fixed step | 0/1,914 | 137/1,673 | 211/1,556 |

The previous current-release measurement produced 13.99–16.79 Hz, a roughly
66.7-ms median display interval, and three to four fixed steps per display
update. The catch-up spiral is therefore removed from the first run and
greatly reduced in the later runs.

## Signpost timings

| Interval | Run 1 p50/p95 | Run 2 p50/p95 | Run 3 p50/p95 |
| --- | ---: | ---: | ---: |
| Fixed Simulation | 5.195 / 6.301 ms | 5.686 / 7.004 ms | 5.607 / 6.386 ms |
| Projectiles | 5.127 / 6.212 ms | 5.611 / 6.910 ms | 5.536 / 6.299 ms |
| Grid Render | 0.615 / 0.790 ms | 0.681 / 0.897 ms | 0.689 / 0.777 ms |
| Presentation Render | 1.113 / 1.388 ms | 1.225 / 1.571 ms | 1.244 / 1.390 ms |

Against the previous 16.159–16.409-ms projectile medians, these runs reduce
projectile CPU by 65.7–68.3 percent. The implementation preserves the original
two-half-step order but loads velocity once, passes it through collision and
Black-Hole handling, and gates Green Square avoidance with the source-equivalent
predicted-danger radius before reading or mutating Square velocity.

## Allocations and follow-up

The first Phase-2 allocation recording reports 2.72 GiB and 29,731,230 heap
allocations over approximately 30 seconds, including 10.92 MiB and 62,280
allocations still persistent. The absolute total is higher than the slow
pre-fix trace because presentation now runs roughly three to four times as
often; `renderPresentation` and `renderGrid` account for 740.07 MB and
692.06 MB respectively.

Most importantly, an Instruments call-tree filter finds no allocation path
through `runGreenSquare`. The previous 224.32-MB `NSNumber` boxing chain has
been eliminated. The new projectile allocation leader was a separate
230.28-MB path in `applyBlackHoles`, caused by repeated Objective-C bridging
of the `blackHoleActive` and `blackHoleSize` string keys.

That newly exposed path was removed immediately after the trace by storing
Black-Hole active/size state on the typed live SpriteKit node while keeping
`userData` synchronized at the low-frequency compatibility boundary. The
five focused projectile captures remain unchanged after that follow-up:

| Capture | Normalized mean grayscale difference |
| --- | ---: |
| `projectile-super-pierce` | 0.00385059 |
| `projectile-bouncy-wall` | 0.00339833 |
| `projectile-bouncy-hit` | 0.00368397 |
| `projectile-super-black-hole` | 0.00349834 |
| `projectile-bouncy-black-hole` | 0.00350101 |

A final post-follow-up device allocation trace remains to be recorded with the
iPhone unlocked. Until then, the 70-percent projectile target and three-run
60-Hz acceptance boundary remain open.

## Decision

Phase 2 has removed the dominant Green Square CPU/boxing defect and restored a
60-Hz run under the deterministic stress load. Continue with one post-follow-up
CPU/allocation verification run, then prioritize the per-display Grid and
presentation allocation paths before considering broader renderer changes.
