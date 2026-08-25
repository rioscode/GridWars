# Original/Swift Capture Review

This is the manual acceptance record for the deterministic GridWars 5.4
rendering catalog. Numeric image differences are useful for locating a
regression, but they cannot by themselves establish visual fidelity.

## Accepted catalog

The review on 2026-08-25 used all 136 fixed 1024×768 states in
`docs/captures/original/` and a fresh catalog produced by
`scripts/capture-screens.sh` from commit `d4a0f5b`.

- The normalized SHA-256 catalog digest of the original PNG hashes is
  `d96acd1cfad2cf775010b1e6c2e96251daa57aebc5519066e9f89a0c3bcedf23`.
- The corresponding Swift digest is
  `8481f1cef4be91facec220d2dc3620789e2b3ffecbf84e1eeed2aff81af951cf`.
- Two independently generated complete Swift catalogs have that same digest.
- `scripts/compare-captures.sh` found all 136 pairs at 1024×768. The largest
  normalized mean absolute difference is `0.0308827` (`grid-18`); every
  non-Grid state is below `0.015`.

Generate the paired contact sheets with:

```sh
sh scripts/review-captures.sh \
  docs/captures/original /private/tmp/GridWarsSwiftCatalog \
  /private/tmp/GridWarsCaptureReview
```

The command creates 16 pages of nine labeled Original/Swift pairs. The review
covered every page and then repeated the five largest or most representative
differences (`grid-08`, `grid-11`, `grid-16`, `grid-18`, and `title`) at their
full 2048×768 side-by-side size.

## Review result

No pair has a missing or additional gameplay object, wrong state, displaced
layout, mirrored motion, incorrect frame choice, text mismatch, or wrong draw
order. The attract screens, transitions, menus, HUD, camera, graphics sets,
entities, generators, motion/lifecycle states, power-ups, projectiles, all 21
Grid selectors, and all four particle paths are presentation-equivalent to the
BlitzMax references.

The PNGs are deliberately not required to be byte-identical across renderers.
The remaining pixels differ in these known implementation boundaries:

- BlitzMax's raw OpenGL Grid paths interpolate color and alpha per vertex.
  SpriteKit has no equivalent public per-vertex color path, so selectors 8,
  11, 16, and 18 use bounded tessellation or source-specific hard rasterization.
  Their source geometry, traversal, deformation, blend mode, and color phase
  match; coverage and gradients differ slightly.
- The multiply-overdrawn vector title exposes OpenGL versus SpriteKit stroke
  joins, caps, and additive premultiplication. Its glyph construction, draw
  count, animation phase, layout, and colors match.
- Normal texture sampling, line coverage, and additive bloom can differ by a
  subpixel where Core Graphics/SpriteKit and Max2D/OpenGL choose different
  pixel centers. Source PNG bytes, frame rectangles, natural sizes, and blend
  semantics remain unchanged.

These are rasterizer differences, not simplified gameplay or missing visual
features. `docs/SWIFT-REWRITE.md` records the implementation rules and rejected
global corrections so a future port can reproduce the same result without
repeating the audit.
