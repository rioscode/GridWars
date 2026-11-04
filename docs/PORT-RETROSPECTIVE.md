# Retrospective: Porting Grid Wars to Swift

Status: 25 August 2026

Branch: `codex/swift-port`

Last completed porting commit: `83d7f80 Verify physical iPhone touch and lifecycle`

## Summary

The port grew from a small, playable Swift prototype into a thoroughly verified macOS/iOS version. The end result is not just compiling Swift code but a source-backed fidelity matrix, deterministic reference captures, automated tests, simulator builds, and a successful test on a physical iPhone.

Technically, the result is strong. The path there, however, was considerably more expensive and iterative than necessary. The main causes were a prototype built too early without a complete inventory, capture infrastructure that was set up late, BlitzMax/Max2D runtime internals that were consulted late, and too many full verification cycles after small changes.

In the achieved result, "1:1" means:

- Game logic, state transitions, input, persistence, and deterministic rules were traced against the original code and tested.
- Graphics and timing were compared systematically with the original.
- Remaining, technically unavoidable raster differences between OpenGL/Max2D and SpriteKit are documented and assessed as bounded platform deviations.
- For operating-system behaviour such as quitting the app, iOS uses the appropriate platform equivalent rather than a literal desktop implementation.

A blanket claim of bit-exact pixel identity on every Apple device would therefore be too strong. The more accurate statement is: the defined fidelity goal was reached, with documented limits and solid evidence.

## Sources evaluated

This retrospective is based on:

- the Git history between the pre-port state (`249bf9b6`) and `83d7f80`;
- the current project files and the documentation in `PLAN.md`, `FIDELITY.md`, `docs/CAPTURE-REVIEW.md`, `docs/RUNTIME-SMOKE.md`, and `docs/SWIFT-REWRITE.md`;
- the local Codex session log from 24 August (not part of the repository).

There is no separate session folder for 25 August. The JSONL file started on 24 August continues into 25 August and therefore covers both working days.

The evaluation deliberately contains no Apple Team ID, email address, device identifier, serial number, or other confidential account or device data.

## What was done

### Repository and working basis

- The original BlitzMax project was inventoried and its structure explained.
- The branch `codex/swift-port` was created for the port.
- `PLAN.md` and `AGENTS.md` were written; a detailed fidelity matrix and further verification reports followed later.
- The original `.bmx` files as well as `gfx/` and `sounds/` were unchanged between the starting point and the final commit. Assets were copied for the Swift target, not replaced in the original.

### Swift port

- A shared Swift 6 codebase for macOS and iOS was built with SwiftUI and SpriteKit.
- Game rules were moved into platform-neutral value types wherever possible so they can be tested deterministically without a running SpriteKit view.
- All major game systems were ported: player, shots, enemies and generators, grid variants, particles, power-ups, menus, options, high scores, audio, pause/resume logic, and persistence.
- The original resources were bundled into the Apple target.
- Launch scripts, the Xcode project, and test targets were added.

### Fidelity and references

- `FIDELITY.md` was built as a mapping from original source → Swift implementation → evidence.
- Official or source-level BlitzBasic/BlitzMax references were archived under `docs/bb/`, in particular on random numbers, Max2D, audio, and runtime semantics.
- An isolated capture harness was created for the original that does not write into the normal user state under `~/.config`.
- A deterministic catalogue of 136 original captures was produced. Matching Swift captures were generated and compared pairwise.
- Repeated captures were checked for determinism by hash; contact sheets and individual frames were also reviewed visually.

### Platform and runtime verification

- The macOS version was built and verified along a complete runtime path.
- The iOS test build passed for the simulator; iPhone and iPad presentation were checked in the simulator.
- After explicit approval, signing, device provisioning, and developer trust were set up for a physical iPhone.
- On the real device, a UI test ran with real touch events for movement, aiming, bomb, menu, resume, Home/foreground, and cold launch.
- The persistence files were checked in the app container.

### Documentation and version history

- The README contains the direct launch path: `./scripts/run-macos.sh`.
- Additional documents describe the port, capture review, runtime tests, and remaining deviations.
- As requested, the work was saved in numerous milestone commits.

## Results in numbers

| Metric | Result |
| --- | ---: |
| Porting commits | 81 |
| Files changed/added in the porting range | 1,234 |
| Net diff | 82,577 insertions, 4 deletions |
| Swift files | 18 |
| Swift code including tests | 18,008 lines |
| macOS tests at completion | 127 passing |
| Physical iPhone UI test | 1 passing, 0 failures |
| Deterministic capture cases | 136 pairs |
| Archived reference files under `docs/bb/` | 1,025 |

A large share of the file and line growth consists of archived reference documentation and original captures; it should not be read as 82,000 lines of newly written Swift logic.

## What went well

### 1. The original eventually became the real authority

The best decision was not to stop at "looks similar". `FIDELITY.md` forces every relevant feature into a verifiable chain of original source, Swift target, and evidence. This surfaced implicit rules that would easily have been lost in a free reimplementation.

### 2. A testable architecture instead of pure scene logic

Separating deterministic rules from SpriteKit made it easier to test enemy behaviour, grid selection, random sequences, state, and persistence. This was especially valuable when GUI automation was restricted or a simultaneous key press could not be automated reliably.

### 3. Deterministic image comparisons were taken seriously

The original harness, fixed states, and repeatable captures made graphics discussions measurable. It was particularly good that an image metric was never treated as the sole proof: differences were also reviewed as contact sheets and at full resolution.

### 4. Failed rendering experiments were discarded

Alternative raster and SpriteKit approaches were measured. When they worsened overall similarity, they were reverted. That is better fidelity work than keeping a change only because it looks locally plausible.

### 5. Verification did not stop at the compiler

The combination of 127 macOS tests, simulator builds, visual review, and a real iPhone test is far more reliable than a successful build alone. The hardware test revealed concrete problems that were not visible in the simulator or in unit tests.

### 6. Permission boundaries were respected

Work paused before device registration, provisioning, and developer trust, and the required approval was obtained. The technical work therefore stayed within the granted authorization.

### 7. The original and the history stayed traceable

The legacy files were not rewritten. The branch, milestone commits, verification reports, and archived references make the port auditable later.

## What went badly or was unnecessarily expensive

### 1. The first Swift version came before the complete inventory

The first playable version contained only three enemy types and five tests. At that point the task was still phrased as a general port; the later 1:1 goal raised the bar considerably. Even so, a complete system and acceptance matrix before the first larger implementation step would have been sensible. The early prototype later caused a lot of rework.

### 2. The verification architecture came too late

The capture catalogue grew step by step from smaller subsets to 67, then 87, and finally 136 cases. Early Retina captures of the original recorded only the top-left section because the 2× framebuffer was misinterpreted. The error was found and corrected, but a validated capture harness should have preceded the fine graphical work.

### 3. BlitzMax/Max2D internals were examined in depth only along the way

Details of `BRL.Random`, type conversions, Max2D rasterization, and direct OpenGL behaviour affect visible and deterministic results. Because these sources were archived and evaluated systematically only later, already ported rules and rendering decisions had to be re-checked.

### 4. The working process generated a great deal of tool and context traffic

The session ran through many context compactions; the same large context was reprocessed very frequently.

Causes included repeated full builds, large capture runs, extensive terminal output, and very small consecutive rendering experiments.

### 5. Many patches and commands had to be repeated

A rough pattern search in the logs found, among other things, 66 occurrences of `script failed`, 32 of `test failed`, 12 of `build failed`, 56 failed `apply_patch` patterns, and 231 `permission denied` patterns. These are not 397 distinct errors: repetitions, quoted output, and re-renderings may be counted more than once. As a process signal the numbers are still useful. Fragile multi-hunk patches on already modified files and inaccurate assumptions about sandbox/GUI permissions cost particular time.

### 6. Full verification matrices were run too often after small changes

A single pixel or blending experiment first needs a focused test and a few representative captures. Frequent full builds and catalogue runs lengthened the loop without delivering proportionally more insight.

### 7. Runtime and hardware risks were brought forward late

GUI locks, simulator state, signing, Developer Mode, device trust, and the tunnel to the physical device were fully resolved only late. The first hardware UI test also had two concrete weaknesses:

- After Home/foreground, a stale `XCUIApplication.state` was evaluated.
- The tap on "Continue" used a wrong relative Y position because the 4:3 playfield is shown aspect-fit in the device window.

Both were corrected. An early minimal XCUITest would have exposed this class of problem sooner. The rotated pixel matrix stored in device screenshots would also have been noticed earlier through immediate visual inspection.

### 8. The commit history is finer-grained than ideal for review

The 81 commits reflect the explicit request for a save per milestone. Some near-pixel experiments would nevertheless have been better bundled locally and committed as one technical milestone only after the evidence passed. That would have made the later review history calmer.

## What could concretely be done better

### Phase 0: Acceptance contract and preflight

Before implementation:

1. Record the starting commit, branch, and any unrelated working-tree changes.
2. Define the original sources and assets as an immutable reference.
3. Break "1:1" down into verifiable categories: rules, timing, graphics, audio, input, persistence, and platform-specific equivalents.
4. Check Xcode, Swift, BlitzMax, GUI access, simulators, and optionally physical devices early.
5. Only diagnose signing and Developer Mode; continue to change them only after explicit approval.

### Phase 1: Complete source and reference inventory

- Capture all subsystems, enemies, generators, grid functions, menus, and storage formats.
- Read the relevant runtime sources on RNG, numeric conversion, Max2D, OpenGL, and audio before porting.
- For every subsystem, enter the original path, target type, and planned evidence in `FIDELITY.md` up front.

### Phase 2: Harness before fine work

- Build the original harness in isolation and without user data.
- Validate Retina/framebuffer scaling with a known test image.
- Make seed, timing, window size, and input deterministic.
- Fix the complete capture catalogue early and reproduce it identically twice.

### Phase 3: Subsystem-by-subsystem port

For each functional work package:

1. Read the original code and runtime semantics.
2. Implement platform-neutral rules.
3. Write small, focused unit tests.
4. Add the SpriteKit integration.
5. Compare only the relevant captures.
6. Update the ledger and create a commit that is understandable in domain terms.

The original's ordering and implicit conversions should be preserved explicitly; "cleaner" reorderings can change random sequences and images.

### Phase 4: Rendering with hypotheses instead of global offsets

- Perform coordinate transformations at clear system boundaries.
- Treat pixel centres, line endpoints, blend modes, and text metrics separately.
- Change only one variable per experiment.
- Check representative individual frames first; run the full 136-case catalogue only at milestones.
- Revert regressions consistently and document accepted platform limits.

### Phase 5: Stage platform tests early

- Establish a macOS smoke test and a minimal iOS XCUITest early.
- Then check iPhone and iPad simulators.
- As soon as authorized and available, run a short physical touch/lifecycle test, not only at the end of the project.
- Check screenshots immediately for orientation, safe areas, and aspect-fit.

### Phase 6: Final audit

- Run the complete unit/UI test matrix.
- Compare original and Swift captures in full.
- Verify persistence on macOS, the simulator, and a physical device.
- Explicitly document open ledger rows and known limits.
- Only then create the final commit.

## Recommended milestone package

Every larger commit should carry a small, uniform evidence package:

- affected original source locations;
- affected Swift files;
- focused test commands and results;
- relevant original/Swift captures;
- updated `FIDELITY.md` rows;
- known deviations or deliberately chosen platform equivalents.

This reduces repetition and makes reviews possible without reading the complete session history.

## Derived skill

A narrow, reusable skill was created from the recurring problems:

- `skills/blitzmax-swift-fidelity/SKILL.md`

It is deliberately not a general "program better" skill. It applies only to source-faithful BlitzMax/Max2D ports to Swift/SpriteKit or corresponding audits. In particular, it encodes:

- an acceptance matrix and preflight before implementation;
- early review of legacy runtime semantics;
- isolated deterministic captures;
- a staged rather than constantly complete test strategy;
- specific rules for coordinates, rasterization, and random-call order;
- early simulator and hardware tests;
- clean permission boundaries and redacted evidence.

The default path `.agents/skills/` was read-only in this runtime. The validatable skill source therefore lives in the regular repository directory `skills/`. For automatic personal discovery, this folder can later be copied to `~/.codex/skills/blitzmax-swift-fidelity/`.

## Remaining risks and limits

- OpenGL/Max2D and SpriteKit do not rasterize certain lines, points, sprites, and text pixel-identically in every case. The known differences are bounded and documented.
- A physical iPhone was tested successfully; a physical iPad was not part of the final evidence. The iPad check was done in the simulator.
- After the final commit, the working tree contained a change to `GridWars.xcodeproj/project.pbxproj` that does not belong to this retrospective. It was neither modified nor assessed here. Xcode project files therefore remain an area where deterministic generation, or at least a separate normalization check, would be worthwhile.

## Conclusion

The project ended with an unusually thoroughly verified port and good technical documentation. The combination of an unchanged original, a source-to-evidence ledger, deterministic captures, and a real hardware test is especially valuable.

The biggest lever for improvement is not more implementation but a better order: first acceptance and runtime semantics, then the harness, then a subsystem-by-subsystem port with focused evidence, and the full matrix last. This is exactly the order captured in the new skill.
