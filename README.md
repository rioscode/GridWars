# GridWars

This repository holds the source code of GridWars, created originally by Mark
Incitti in 2006, together with a native Swift port. The goal of this project is
a faithful GridWars 5.4 reproduction for **macOS and iOS/iPadOS**; these are the
only supported targets.


## Native Swift port for macOS and iOS

The repository contains a native Swift 6/SpriteKit port shared by macOS and
iPhone/iPad. The original BlitzMax source and assets remain intact and are the
authority for gameplay and presentation.

The port includes all ten enemies and generators, the 21 grid selectors, the
original particle recipes, weapons and power-ups, attract screens, menus,
graphics sets, sound effects, tracker music, high scores, legacy configuration
import, and all five controller modes. The completed source, test, visual, and
physical-device acceptance evidence is recorded in `FIDELITY.md`.

### Requirements

- Xcode 16 or newer with the macOS SDK and an iOS Simulator runtime;
- macOS 14 or newer for the Mac target;
- iOS/iPadOS 17 or newer for the mobile target.

### Start on macOS

From the repository root, build and launch with one command:

```sh
./scripts/run-macos.sh
```

Alternatively, open `GridWars.xcodeproj`, select the `GridWars-macOS` scheme,
choose **My Mac**, and press **Run** (`Cmd-R`). Build products stay in `.build/`.

### Start on iPhone or iPad

1. Open `GridWars.xcodeproj` in Xcode.
2. Select the `GridWars-iOS` scheme.
3. Choose an iPhone/iPad Simulator and press **Run** (`Cmd-R`).

For a physical device, connect and unlock the iPhone or iPad, trust the Mac,
enable Developer Mode on the device, and select a development team for the
`GridWars-iOS` target's Signing & Capabilities settings. Then choose the device
as the run destination and press **Run**.

### Command-line verification

```sh
xcodebuild -project GridWars.xcodeproj -scheme GridWars-macOS \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO build

xcodebuild -project GridWars.xcodeproj -scheme GridWars-iOS \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/DerivedData-iOS CODE_SIGNING_ALLOWED=NO build

xcodebuild -project GridWars.xcodeproj -scheme GridWars-iOS \
  -configuration Debug -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath .build/DerivedData-ios-device \
  CODE_SIGNING_ALLOWED=NO build

xcodebuild -project GridWars.xcodeproj -scheme GridWars-macOS \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData-tests CODE_SIGNING_ALLOWED=NO test
```

With an unlocked, trusted iPhone/iPad in Developer Mode and a development team,
run the physical touch/lifecycle smoke test with:

```sh
xcodebuild -project GridWars.xcodeproj -scheme GridWars-iOS \
  -configuration Debug -destination 'id=<device-udid>' \
  -derivedDataPath .build/DerivedData-ios-physical-tests \
  -resultBundlePath .build/PhysicalSmoke.xcresult \
  DEVELOPMENT_TEAM=<your-team-id> \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
  -only-testing:GridWarsSwiftUITests/GridWarsPhysicalSmokeTests/testPhysicalTouchAndLifecycleFlow \
  test
```

### Swift port controls

- Use the configured BOMB key, mouse button, controller button, or the iOS
  **BOMB** control on the attract screen to start.
- macOS original keyboard defaults: `S`/`D` move left/right, `E`/`X` move
  up/down, arrow keys aim/fire, and `Space` uses a bomb.
- `Esc` opens Options. Choose **Settings → Controls** to select Dual Analog,
  Mouse, Keyboard, Joypad, or Hybrid and configure its bindings.
- iOS/iPadOS: drag the left stick to move and the right stick to aim/fire; tap
  **BOMB** to use a bomb and **OPT** to open Options.
- Runtime controls match the original: `F3` cycles the grid, `F4` changes the
  star count, `F5` toggles particle gravity, `F6` cycles particle style, and
  `F7` toggles debug output.
- `F1` toggles cheat mode and invalidates the current score. While enabled,
  `1`–`4` grant timed weapons, `X` adds a cannon, `Z` increases shot speed,
  `S` grants a shield, `F2` toggles god mode, holding `P` pauses, and `O`
  advances one frame.

Official language references used during the port are archived in `docs/bb/`.
`PLAN.md` records the milestones, while `FIDELITY.md` maps the BlitzMax source
to its Swift implementation and verification evidence. Reusable coordinate,
texture, blending, timing, and verification lessons are collected in
`docs/SWIFT-REWRITE.md`; the complete manual Original/Swift image audit is in
`docs/CAPTURE-REVIEW.md`, and the final interactive acceptance sequence is in
`docs/RUNTIME-SMOKE.md`.


## Build instructions

The instructions below apply only to the original BlitzMax version. They are
kept from the upstream fork (https://github.com/mmatyas/GridWars) and are not
part of this project's supported targets.

This game uses the [BlitzMax game engine](http://www.blitzbasic.com/Products/blitzmax.php), and is written in its BASIC-resembling language. As such, to compile the game, you will need the BMX compiler for your system. There are two main implementations, the [official one](https://github.com/blitz-research/blitzmax) and [BMX-NG](http://www.bmx-ng.com/main/).

The last known working compiler version is `0.138.3.53`.


### Building on Linux

- Install the dependencies of the BMX-NG compiler: `sudo apt-get install libasound2-dev libpulse-dev libxft-dev libxxf86vm-dev`
- Get the BMX-NG compiler from here: https://github.com/bmx-ng/bmx-ng/releases
- Extract it to somewhere
- `cd` into the cloned game repository
- Build the game like this: `PATH=/path/to/BlitzMax/bin:$PATH bmk makeapp -t gui -r -w gridwars.bmx`

The `gridwars` executable will be created in the project's directory.
