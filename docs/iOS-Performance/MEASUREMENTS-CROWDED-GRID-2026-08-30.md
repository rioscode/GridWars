# Physical iPhone Crowded-Grid Investigation — 2026-08-30

## Status

> **Resolved 2026-08-30 by `MEASUREMENTS-GRID-SPRITE-2026-10-09.md`.** The
> pooled-sprite point Grid was measured against the `SKShapeNode` path in the
> deterministic benchmark and is a 4.6x cost regression. It is not the default
> on any platform and is only reachable with `--grid-sprite-points`. The shape
> path stays the default. Read that file before spending more effort on Grid
> rendering.

The normal live-shooting audio stall has already been removed by the PCM
player-node work. A separate trace of a crowded real wave still finds a
presentation-side renderer cost. This note records that evidence and the
strictly scoped iOS Grid experiment currently awaiting its physical A/B run.

Do not describe this candidate as a completed performance win until the same
kind of real crowded-and-firing trace has been retained for the new build.

## Baseline evidence

- Device: wired iPhone 17 Pro Max (`iPhone18,2`), iOS 26.6.1 (`23G83`).
- Build: signed Release app containing the audio-engine firing-path fix.
- Scenario: normal game in a crowded wave, recorded while idle rather than
  continuously firing. It is therefore evidence for renderer headroom loss,
  not a complete reproduction of the user's sustained-fire residual.
- Instruments: Game Performance, attached to the running process.
- Raw artifact:
  `.build/ios-performance/2026-08-30-crowded-audio-free/crowd-idle-run3.trace`.
- Retained display-surface window: 475 intervals, 17.230-ms mean,
  16.668-ms median/p95, 50.005-ms maximum, 14 intervals at or above 33.33 ms,
  two at or above 50 ms, and no potential hang at the 100-ms threshold.

The 10-second Game Performance window is largely smooth, but it does not have
comfortable CPU margin for the visual work. Of 4,227 one-millisecond Main
Thread samples, `GridRenderer.addPointGrid` is the leaf in 1,183 samples
(28.0%). `SKCShapeNode::addRenderOps` is the leaf in 976 samples (23.1%; 1,199
inclusive with its callees). These views overlap in the call tree and must not
be summed as wall time; together they establish the causal route:

`GridRenderer.addPointGrid` → `SKShapeNode.setPath` → CGPath copy/tessellation
→ `SKCShapeNode::addRenderOps`.

The normal 1,024 × 768 scene at 16-point Grid spacing creates 4,496 rectangles
per displayed frame:

| Pass | Rectangles | Geometry |
| --- | ---: | --- |
| Base Grid | 3,072 | 64 × 48, 2 × 2 pixels |
| Every fourth nonzero column | 720 | 15 × 48, 3 × 3 pixels |
| Every fourth nonzero row | 704 | 11 × 64, 3 × 3 pixels |
| Total | 4,496 | Three additive passes, including intentional overlap |

The old renderer puts each pass in one `CGMutablePath`, but rebuilds those
paths and assigns them to `SKShapeNode` every display update. The node pool
prevents `SKNode` allocation only; it does not prevent the per-frame path copy
or SpriteKit vector tessellation.

## Scoped experiment

`GridRenderer` now keeps the original `SKShapeNode` implementation as the
fallback, but uses an iOS-only, pooled sprite representation for default point
Grid styles when the calculated total is at most 5,000 rectangles. It uses a
single opaque 1 × 1 white `SKTexture` with nearest filtering, a zero anchor,
the existing exact `OriginalDrawRectRule` rectangle, additive blending, and
the exact pass order above. The original shape path remains active on macOS,
for dense spacing levels above the guard, and when the app is launched with
`--grid-shape-points`.

That launch argument is deliberately a reversible same-binary baseline for
device comparison. It changes only the renderer selection; game rules,
positions, colors, alpha, overlap order, and user settings remain unchanged.

## A/B protocol

1. Run the new signed Release build in the same default Grid setting with
   `--performance-stats` visible.
2. Let the player recreate a dense wave and hold fire for the retained trace
   window. Record Game Performance and export display-surface plus Time
   Profiler data.
3. Restart the exact same app with `--grid-shape-points` and recreate the
   closest comparable scenario. Record a second trace.
4. Retain the sprite path only when it improves or preserves the frame pacing
   and removes the proven path/tessellation share without a visible Grid
   regression. Capture a still/overlay if possible because `SKShapeNode`
   antialiasing and nearest-filtered sprites can differ subtly at pixel edges.
5. If firing remains slow after the sprite path, profile the real firing trace
   before changing particle, score, aura, collision, Snake, or Triangle code.
