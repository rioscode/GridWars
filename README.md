# GridWars

This repository holds the source code of GridWars, created originally by Mark Incitti in 2006. The goal of this project is to improve compatibility with embedded systems, such as the Raspberry Pi.


## Native Swift port for macOS and iOS

The repository contains a native Swift 6/SpriteKit port shared by macOS and
iPhone/iPad. The original BlitzMax source and assets remain intact and are the
authority for gameplay and presentation.

The port includes all ten enemies and generators, the 21 grid selectors, the
original particle recipes, weapons and power-ups, attract screens, menus,
graphics sets, sound effects, tracker music, high scores, legacy configuration
import, and all five controller modes. The remaining evidence work is tracked
honestly in `FIDELITY.md`.

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

For a physical device, select a development team for the `GridWars-iOS`
target's Signing & Capabilities settings first.

### Command-line verification

```sh
xcodebuild -project GridWars.xcodeproj -scheme GridWars-macOS \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO build

xcodebuild -project GridWars.xcodeproj -scheme GridWars-iOS \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/DerivedData-iOS CODE_SIGNING_ALLOWED=NO build

xcodebuild -project GridWars.xcodeproj -scheme GridWars-macOS \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData-tests CODE_SIGNING_ALLOWED=NO test
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

The instructions below apply to the original BlitzMax version.

This game uses the [BlitzMax game engine](http://www.blitzbasic.com/Products/blitzmax.php), and is written in its BASIC-resembling language. As such, to compile the game, you will need the BMX compiler for your system. There are two main implementations, the [official one](https://github.com/blitz-research/blitzmax) and [BMX-NG](http://www.bmx-ng.com/main/), which has improved ARM and cross compilation support.

The last known working compiler version is `0.138.3.53`.


### Building on Linux/Raspberry Pi

- Install the dependencies of the BMX-NG compiler: `sudo apt-get install libasound2-dev libpulse-dev libxft-dev libxxf86vm-dev`
- Get the BMX-NG compiler from here: https://github.com/bmx-ng/bmx-ng/releases
- Extract it to somewhere
- `cd` into the cloned game repository
- Build the game like this: `PATH=/path/to/BlitzMax/bin:$PATH bmk makeapp -t gui -r -w gridwars.bmx`

The `gridwars` executable will be created in the project's directory.


### Cross compiling to Raspberry Pi

At the time of writing the build system, unfortunately, doesn't respect `CC` and `CXX`, and always calls the native compiler. You'll have to do some manual hacking.

- Make sure you have a C++ cross compiler installed (eg. `arm-linux-gnueabihf-g++`)
- Copy the OpenGL/GLES libraries from the Raspberry Pi to your system. You have to copy `/opt/vc/` from the Pi (or from a Pi disk image) to the same place on your native system. If this path is not good for you, you can change it in `BlitzMax/mod/sdl.mod/sdlgraphics.mod/sdlgraphics.bmx`
- Create a new directory that will hold symlinks to the cross compilers, eg. `armcc`, and enter into it
- `for f in /usr/bin/arm-linux-gnueabihf-*; do f2=$(basename $f); ln -s $f ./${f2/arm-linux-gnueabihf-/}; done`
- Install the dependencies of the BMX-NG compiler: `sudo apt-get install libasound2-dev libpulse-dev libxft-dev libxxf86vm-dev`
- Get the BMX-NG compiler for Linux from here: https://github.com/bmx-ng/bmx-ng/releases
- Extract it to somewhere
- `cd` into the cloned game repository
- Build the game like this: `PATH=/path/to/armcc:/path/to/BlitzMax/bin:$PATH bmk makeapp -t gui -l raspberrypi -g arm -r -w -v gridwars.bmx`
- At the very end, you will get a compile error about an unexpected `-m32` flag, or undefined EGL symbols. To fix it, copy the failing `g++` command, replace `g++` with `arm-linux-gnueabihf-g++`, remove `-m32` and also append `-lEGL` to the end
