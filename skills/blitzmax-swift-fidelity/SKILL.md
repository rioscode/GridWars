---
name: blitzmax-swift-fidelity
description: Port or audit a BlitzMax/Max2D game to Swift/SpriteKit when the request requires behaviorally and visually evidenced 1:1 fidelity on macOS or iOS. Use for source-to-port mapping, deterministic capture comparison, RNG/raster compatibility, and Apple-platform acceptance; do not use for ordinary Swift apps or loose remakes.
---

# BlitzMax to Swift fidelity

Treat the legacy source and assets as the authority. Preserve them unless the user explicitly requests an original-source change.

When present, read `AGENTS.md`, `PLAN.md`, `FIDELITY.md`, `docs/SWIFT-REWRITE.md`, and `docs/RUNTIME-SMOKE.md` before changing the port.

## Define done before implementing

Split “1:1” into explicit acceptance surfaces:

- deterministic rules and update order;
- RNG and implicit numeric conversions;
- rendering, timing, audio, input, and persistence;
- platform equivalents such as iOS lifecycle behavior;
- hardware targets actually required for acceptance.

Do not promise universal pixel identity across Max2D/OpenGL and SpriteKit. Require documented, visually reviewed boundaries for unavoidable raster differences.

## Preflight the risky dependencies

Before substantial code work:

1. Record the starting commit, current branch, and unrelated working-tree changes.
2. Verify the available BlitzMax and Apple toolchains, GUI access, simulators, and requested devices.
3. Inspect the authoritative runtime implementations for behavior that affects output, especially `BRL.Random`, Max2D drawing, direct OpenGL paths, blend modes, and numeric conversion.
4. Design original-game execution and capture so it cannot mutate normal user configuration or scores.
5. Diagnose signing and Developer Mode early, but request authorization before device registration, provisioning changes, trust changes, or other account/device mutations.

## Maintain a source-to-evidence ledger

For each subsystem, record:

| Field | Required content |
| --- | --- |
| Original | Exact legacy files, functions, or line references |
| Swift | Target types and files |
| Rule evidence | Focused deterministic tests |
| Visual evidence | Named original and Swift captures |
| Runtime evidence | macOS, simulator, or hardware path |
| Boundary | Known platform-equivalent difference |

An item is incomplete while any required evidence cell is empty.

## Port in source order

- Preserve update order, draw order, RNG call order, integer truncation, and implicit Float/Int behavior unless evidence proves they are irrelevant.
- Put deterministic rules into platform-neutral value types. Keep SpriteKit and UI code as integration layers.
- Copy resources into the Apple target; do not repurpose the legacy asset tree.
- Convert coordinate systems at explicit boundaries. Avoid a universal pixel offset: point centers, line endpoints, sprite anchors, text metrics, and direct OpenGL paths may require different rules.
- Test one subsystem end to end before widening scope.

## Build the capture harness first

Use fixed seeds, fixed timing, fixed viewport size, and named states. Validate Retina/backing-scale handling with a known test image before trusting comparisons.

For every accepted capture:

1. Produce an isolated original image.
2. Produce the matching Swift image.
3. Repeat the run and compare hashes for determinism.
4. Inspect both a contact sheet and the full-resolution pair.
5. Use numeric image metrics to prioritize inspection, not as sole proof of fidelity.

Never include user configuration, account identifiers, signing data, device IDs, or unrelated private state in evidence.

## Use a staged verification loop

For a small change, run only the focused rule tests and representative captures. At a subsystem milestone, run the platform build and the relevant capture subset. Run the full unit/UI/capture matrix only for release-grade milestones.

For rendering experiments, state one hypothesis, vary one behavior, measure a bounded set of frames, and revert the experiment if it regresses the broader evidence.

Add macOS smoke tests and a minimal iOS UI test early. Verify aspect-fit coordinates, orientation, Safe Areas, real touch input, Home/foreground transitions, cold relaunch, and persistence. Clearly distinguish simulator evidence from physical-device evidence.

## Commit only evidenced milestones

Before a milestone commit, require:

- ledger entries updated;
- focused tests passing;
- relevant capture pairs reviewed;
- no unexplained changes to legacy sources or unrelated user work;
- commands and results recorded in the project documentation.

Prefer subsystem-sized commits over a commit for every pixel experiment.

At handoff, report what is exact, what is platform-equivalent, what remains unverified, and the shortest supported commands to build, test, and run the port.
