# AGENTS.md

## Scope

These instructions apply to the entire repository. The repository contains the
original BlitzMax game and a native Apple-platform port. Preserve the original
`.bmx` files and assets unless a task explicitly asks to modify them.

## Port direction

- Implement new Apple-platform work in `GridWarsSwift/` and
  `GridWarsSwiftTests/`.
- Use SwiftUI for application lifecycle and SpriteKit for the game loop.
- Keep gameplay sources shared between macOS and iOS; isolate platform-specific
  input or UI with small conditional sections where necessary.
- Treat `gridwars.bmx`, `control.bmx`, and `gridparttrail.bmx` as the behavioural
  reference. Prefer reproducing observed rules over mechanically translating
  globals or rendering calls.
- The active goal is a complete GridWars 5.4 reproduction. Implement only
  systems evidenced by the original source or assets, but do not omit an
  original feature because the existing port is simpler.
- Use `FIDELITY.md` as the requirement and evidence matrix. An item is complete
  only when its original source reference, Swift implementation, and
  verification evidence are all recorded.

## Swift style

- Build with Swift 6 strict concurrency enabled.
- Use explicit access control for reusable gameplay types.
- Keep SpriteKit mutation on the main actor.
- Prefer value types for deterministic rules and reference types for live
  SpriteKit entities.
- Avoid force unwraps in gameplay code.
- Name constants after their gameplay purpose rather than their original
  abbreviated BlitzMax variable.
- Put platform-neutral rules in files that can be unit tested without loading
  SpriteKit views.

## Assets

- Reuse files from `gfx/` and `sounds/` when their license and format allow it.
- Do not overwrite original assets. Copy only the resources needed by the Swift
  targets into `GridWarsSwift/Resources/`.
- Preserve case-sensitive resource names.

## Build and verification

Run focused checks after each relevant change:

```sh
xcodebuild -project GridWars.xcodeproj -scheme GridWars-macOS \
  -configuration Debug -derivedDataPath .build/DerivedData build

xcodebuild -project GridWars.xcodeproj -scheme GridWars-iOS \
  -configuration Debug -sdk iphonesimulator \
  -derivedDataPath .build/DerivedData build

xcodebuild -project GridWars.xcodeproj -scheme GridWars-macOS \
  -configuration Debug -derivedDataPath .build/DerivedData test
```

- Use a specific available simulator destination if Xcode requests one.
- Keep generated build products under `.build/`; do not commit them.
- A gameplay change is complete only when the relevant build succeeds and its
  deterministic rules have tests where practical.

## Git hygiene

- Use `codex/` as the default branch prefix.
- Do not commit `.build`, `DerivedData`, user-specific Xcode state, or generated
  binaries.
- Keep changes scoped to the port. Mention unrelated issues instead of fixing
  them opportunistically.

## Planning reference

Read `PLAN.md` and `FIDELITY.md` before changing the port's scope or
architecture. Update them when a milestone, supported platform, requirement,
or verification result changes materially.
