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
   `/private/tmp/GridWars-Runtime-Smoke-<PID>/`.
8. From attract mode choose Exit Program, accept `Sure?`, and confirm that the
   macOS process terminates.

F8 is compiled only into Debug builds. Before preparing the qualifying score,
it replaces the scene's persistence store with a new process-specific
temporary directory and resets the in-memory score table. It therefore tests
the real editor, insertion, checksum, save, and presentation paths without
reading or changing the user's high scores. Release builds contain neither the
key hook nor the smoke-state preparation.

For iOS/iPadOS, repeat the normal start, twin-stick movement/aim, BOMB, OPT,
background/foreground, and persistence checks on a physical device. iOS maps
the source's application-exit request to a clean title return because mobile
applications cannot terminate themselves.
