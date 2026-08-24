# GridWars

This repository holds the source code of GridWars, created originally by Mark Incitti in 2006. The goal of this project is to improve compatibility with embedded systems, such as the Respberry Pi.


## Native Swift port for macOS and iOS

The repository now also contains a native Swift 6 and SpriteKit port. It keeps
the original BlitzMax source intact and provides shared gameplay code for a
macOS application and an iPhone/iPad application.

The playable first milestone includes:

- neon grid and star-field rendering;
- keyboard/mouse controls on macOS and twin virtual sticks on iOS;
- three enemy behaviours, projectiles, collisions, and particle effects;
- score, multiplier, lives, bombs, power-ups, game over, and restart;
- selected original graphics and sounds;
- deterministic unit tests for scoring, lives, bombs, and spawn pacing.

Open `GridWars.xcodeproj` in Xcode and select either `GridWars-macOS` or
`GridWars-iOS`. The command-line builds are:

```sh
xcodebuild -project GridWars.xcodeproj -scheme GridWars-macOS \
  -configuration Debug -derivedDataPath .build/DerivedData build

xcodebuild -project GridWars.xcodeproj -scheme GridWars-iOS \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/DerivedData build

xcodebuild -project GridWars.xcodeproj -scheme GridWars-macOS \
  -configuration Debug -derivedDataPath .build/DerivedData test
```

Running on a physical iPhone or iPad requires selecting your development team
for the `GridWars-iOS` target in Xcode.

### Swift port controls

- macOS: WASD moves, mouse or arrow keys aim/fire, Space or right-click uses a
  bomb, and R restarts after game over.
- iOS/iPadOS: drag on the left half to move, drag on the right half to aim and
  fire, and tap the BOMB button to use a bomb.

See `PLAN.md` for the implemented milestone and the remaining fidelity work.


## Build intructions

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
