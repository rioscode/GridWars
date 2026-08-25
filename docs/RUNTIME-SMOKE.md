# Runtime Smoke Test

The deterministic catalog and rule tests do not replace an actual app-window
playthrough. Use this checklist on the Debug macOS build after a fidelity
milestone:

1. Start from the animated title with the configured BOMB key.
2. Observe Get Ready and live gameplay; move, aim/fire, and use a bomb.
3. Open Options during play, visit Settings and Controls, then Continue.
4. Enable cheat mode with F1 and debug frame display with F7. Press and release
   P: the displayed simulation frame must remain fixed. Press `P+O` while
   paused: it must increase by exactly one and remain paused. Release the loop
   with O while P is up.
5. Verify death cleanup, Get Ready respawn, final Game Over, and the return to
   attract presentation.
6. Change and accept a setting, finish Options, and verify `Config.txt`; restore
   the original value afterward.
7. Press F8 to enter the Debug-only high-score acceptance state. Type an
   eight-character name (or shorter), press Return, and verify the highlighted
   row plus the checksummed `hiscores.dat` written under
   `FileManager.default.temporaryDirectory/GridWars-Runtime-Smoke-<PID>/`
   (normally `$TMPDIR/GridWars-Runtime-Smoke-<PID>/` on macOS).
8. From attract mode choose Exit Program, accept `Sure?`, and confirm that the
   macOS process terminates.

F8 is compiled only into Debug builds. Before preparing the qualifying score,
it replaces the scene's persistence store with a new process-specific
temporary directory and resets the in-memory score table. It therefore tests
the real editor, insertion, checksum, save, and presentation paths without
reading or changing the user's high scores. Release builds contain neither the
key hook nor the smoke-state preparation.

## Recorded macOS acceptance

The 2026-08-25 Debug run completed the checklist. F8 inserted Medium score
`19001` with the padded name `codex   `, displayed it as the highlighted tenth
row, and wrote `Config.txt`, `Colours.txt`, and `hiscores.dat` to an isolated
process directory. The record's stored checksum was `3542`; independently
summing the bytes of its score, play time, name, and settings fields also gave
`3542`. The Scores page returned to Title after 750 frames.

With the F7 frame counter visible, pressing and releasing P froze frame 62.
Two screenshots taken 1.2 seconds apart had the same SHA-256
`7bfca71e3349be9d5092589def5158edf4eba01c49d9315de73e9b952f78d2e3`.
O with P released resumed the simulation, which had reached frame 109 at the
next capture. The Computer Use driver cannot send two simultaneous
non-modifier keys, so the held-`P+O` re-entry branch is additionally locked by
`testCheatPauseRequiresHeldPAndOSingleStepsOnlyWhilePaused`. Finally, the
attract Exit Program confirmation removed GridWars from the running-app list.

The same acceptance series changed Autofire from 0 to 1, confirmed the value
in Application Support `Config.txt`, then restored and re-verified 0. The
isolated F8 path did not read or alter the user's high-score table.

## Recorded iOS Simulator acceptance

A 2026-08-25 Debug build ran on the iPhone 17 Pro and iPad Air 11-inch (M4)
simulators with iOS/iPadOS 26.5. Both form factors displayed the full
aspect-fit arena and HUD, BOMB started Get Ready, and both virtual-stick paths were
exercised during live gameplay. On iPhone, BOMB produced the Grid shockwave,
OPT opened the original menu, and a touch on Continue returned to play. After
Home and foreground relaunch, the app presented a valid title state and its
Application Support directory contained the complete legacy files: 280 lines
in `Config.txt`, 76 in `Colours.txt`, and 150 in `hiscores.dat`. Exit Program
-> Sure? -> Yes returned to the animated title while the iOS app remained open.

The generic unsigned iPhoneOS arm64 build also succeeds, including the target's
landscape-only full-screen declaration. iOS maps the source's application-exit
request to a clean title return because mobile applications cannot terminate
themselves.

## Recorded physical iPhone acceptance

On 2026-08-25, Xcode signed, installed, and launched the Debug build on a
physical iPhone 17 Pro Max running iOS 26.6. The shared `GridWars-iOS` scheme's
UI test repeated the mobile interaction sequence with real device events:

1. launch in attract mode and tap BOMB to start;
2. wait for live gameplay and drag both the movement and aim virtual sticks;
3. tap BOMB and capture the visible Grid shockwave;
4. open OPT and activate Continue;
5. press Home, reactivate the app, and verify the foreground presentation;
6. terminate the app, cold-launch it, and verify the title presentation.

The test passed in 47.458 seconds with zero failures. Its seven retained Xcode
attachments (`01-attract` through `07-cold-relaunch`) were inspected and show
the expected attract, gameplay, shockwave, Options, resumed-gameplay,
foreground, and relaunch states. XCUITest stores the device PNG pixels in
portrait order even while the interface and game run in landscape; Xcode's
orientation metadata and the manual device screenshot show the intended
2868×1320 landscape presentation.

The reproducible device command is:

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

After the lifecycle run, a read-only CoreDevice listing found `Config.txt`,
`Colours.txt`, and `hiscores.dat` under
`Library/Application Support/GridWars` in the app data container. Copies read
back from the phone contained exactly 280, 76, and 150 lines respectively,
matching the legacy codecs and simulator evidence.
