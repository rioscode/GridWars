# Physical iPhone Live-Shooting Measurement — 2026-08-30

## Result

The real game, unlike the earlier synthetic fixtures, reproduces the reported
shooting hitch immediately. In the retained live-shooting window, 23
display-surface intervals have a 150.014-ms median and a 333.364-ms maximum.
All 23 exceed 33.33 ms, 22 exceed 50 ms, and 16 exceed 100 ms.

The captured call stacks identify a direct synchronous cause in the firing and
impact path: every one-shot effect creates a fresh `AVAudioPlayer`, resolves a
bundle URL, opens the WAV file, prepares an AudioQueue, and starts it. Those
operations occur on the main thread underneath `updateProjectiles()` for
projectile impacts and enemy destruction. This work was absent from the
benchmark fixture because it bypasses normal input and sets sound effects to
zero.

## Environment and artifact

- Device: wired iPhone 17 Pro Max (`iPhone18,2`), iOS 26.6.1 (`23G83`)
- Build under test: signed Release app from commit `bdb94f3`
- Scenario: normal user-controlled gameplay, manually reproduced sustained
  shooting while enemies were on screen
- Instruments: Game Performance with its 10-second `Windowed (5 seconds)`
  capture mode
- Raw artifact:
  `.build/ios-performance/2026-08-30-live-shooting/live-shooting-run1.trace`
- Display-surface rows are retained only from approximately 6.705 to 9.922 s;
  the statistics below therefore describe the observed shooting tail, not a
  full 35-second continuous recording.

## Frame pacing

| Metric | Result |
| --- | ---: |
| Displayed surface intervals | 23 |
| Median interval | 150.014 ms |
| p95 interval | 216.687 ms |
| Maximum interval | 333.364 ms |
| Intervals at or above 33.33 ms | 23 |
| Intervals at or above 50 ms | 22 |
| Intervals at or above 100 ms | 16 |

This is the missing reproduction: the earlier active-enemy fixture held a
16.668-ms cadence, while the real shot-and-impact path falls to roughly
6–7 displayed frames per second in this retained window.

## Direct Time Profiler evidence

Representative main-thread samples show all of the following under real
projectile work:

- `AudioFileOpenURL` → `AVAudioPlayer.init(contentsOf:)` →
  `OriginalAudioEngine.play` → `GameScene.createProjectileImpact` →
  `GameScene.updateProjectiles` → `GameScene.simulateFrame`.
- `AVAudioPlayer.prepareToPlay` allocating an AudioQueue under the same
  projectile-impact path.
- AudioQueue XPC calls to enqueue/start playback and queue disposal work after
  sound completion.
- Repeated `OriginalAudioEngine.soundURL(for:)` bundle-resource lookup and
  `pruneOneShots()` work during shooting.

Grid rendering and `GridSimulation.push` are also visible, but the live device
uses normal point Grid style 0 and particle style 0. Those paths scale with
projectile count but do not explain the immediate synchronous file/AudioQueue
work captured at each impact.

## Implemented A/B fix

The pending build replaces per-play player construction with a reusable,
polyphonic pool keyed by `OriginalSoundEffect`:

- cache each resolved sound URL;
- prewarm 8 `shotBorn`, 8 `shotWall`, 12 `enemyHit`, and 8
  `interceptorHit` voices before normal gameplay;
- choose an idle prepared player first, allocate only up to 16 voices per
  effect and the port's existing 128 total-player limit, then reuse the oldest
  voice;
- keep per-event rate, pan, volume, and overlap behavior, but execute only
  `currentTime = 0` and `play()` during the hot frame.

This matches the original `sound.bmx` architecture more closely: `LoadSounds`
loads samples once, and `PlaySound2` cues an already loaded sound rather than
opening a file for every shot or hit.

## Next measurement

1. Launch the installed audio-pool Release build after the iPhone is unlocked.
2. Repeat the same manual sustained-fire scenario and retain an identical
   Game Performance/Time Profiler trace.
3. Compare display-surface p50/p95/max and confirm that
   `AudioFileOpenURL`, `prepareToPlay`, and AudioQueue allocation have left the
   repeated projectile-impact stacks.
4. Only then address the remaining projectile candidate refresh and ordered
   projectile-versus-enemy broad-phase work; retain source interaction order
   and do not hide the real hitch behind a synthetic fixture.
