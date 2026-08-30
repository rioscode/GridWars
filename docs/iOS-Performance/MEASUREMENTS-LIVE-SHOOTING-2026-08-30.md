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

## First A/B result: URL caching was necessary, but insufficient

The first replacement build used a prewarmed, bounded `AVAudioPlayer` pool:
cached URLs, 8 `shotBorn`, 8 `shotWall`, 12 `enemyHit`, and 8
`interceptorHit` voices, with oldest-voice recycling after the per-effect and
global limits. Its live-shooting trace contains 50 display intervals with a
100.009-ms median, a 216.687-ms p95, and a 283.359-ms maximum; 36 are at or
above 33.33 ms, 32 are at or above 50 ms, and 27 are at or above 100 ms.

That is an improvement over the first 150.014-ms median, but not a release
quality result. `AudioFileOpenURL` has disappeared from the repeated firing
stack, proving that the cache removed file opening. However, Time Profiler
still shows `AVAudioPlayerCpp::prepareToPlayQueue`, AudioQueue allocation, and
AudioQueue XPC below `GameScene.createProjectileImpact` and
`GameScene.updateProjectiles`. Reusing an `AVAudioPlayer` did not eliminate
the synchronous playback-queue work itself.

The measured corrective build replaces the one-shot player pool with
reusable `AVAudioEngine` player nodes and decoded PCM buffers. It keeps the
same bounded polyphony, source rate/pan/volume, and oldest-voice overlap
policy, while preloading the firing-path samples and its initial overlapping
voices before gameplay.
During firing it only selects a prepared voice, schedules the in-memory buffer,
and starts that node on the already running audio engine.

After the measured A/B runs, a closing review hardened two unmeasured edge
conditions in the final source: all 16 available voices are now preconnected
for each firing-path effect, preventing live graph mutation after a dense
salvo exhausts a smaller warm-up pool; and black-hole loop teardown now detaches
only loop nodes, leaving the shared one-shot engine running across transitions.

This is closer to the original `sound.bmx` design: `LoadSounds` loads samples
once, and `PlaySound2` cues an already loaded sound rather than opening a file
or allocating a playback queue for every shot or hit.

## Physical PCM-player-node A/B result

The signed Release PCM-player-node build was installed on the same wired
iPhone and measured in two manually sustained-fire runs. The first retained
window is already a major improvement. The repeat contains one exact
4,975.457-ms discontinuity between `00:04.581.507` and `00:09.556.963`; it
matches the Game Performance template's `Windowed (5 seconds)` retention
mode, has no corresponding potential-hang record, and is therefore reported
separately rather than misclassified as a rendered frame. The contiguous
intervals around it are the reliable frame-pacing result.

| Build / retained run | Intervals | Median | p95 | Maximum | >= 33.33 ms | >= 50 ms | >= 100 ms | Potential hangs |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Per-event `AVAudioPlayer` baseline | 23 | 150.014 ms | 216.687 ms | 333.364 ms | 23 | 22 | 16 | n/a |
| Cached/prewarmed `AVAudioPlayer` pool | 50 | 100.009 ms | 216.687 ms | 283.359 ms | 36 | 32 | 27 | present |
| PCM player nodes, run 1 | 198 | 16.668 ms | 33.336 ms | 166.682 ms | 94 | 3 | 1 | none |
| PCM player nodes, run 2, contiguous data | 223 | 16.668 ms | 16.668 ms | 33.336 ms | 1 | 0 | 0 | none |

The validated repeat reduces the live-shot median from 150.014 ms to
16.668 ms (about 88.9 percent) while preserving real input, enemies, hits, and
audio. It does not rely on the synthetic fixture that previously hid the
problem.

The Time Profiler exports for the two PCM runs are intentionally recorded as
supporting, rather than sole, proof: the now-fast retained windows contain only
23 and 48 CPU samples respectively. Neither export samples
`AudioFileOpenURL`, `AVAudioPlayerCpp`, `prepareToPlayQueue`, AudioQueue XPC,
or the previous `OriginalAudioEngine` hot path. The frame-pacing result and
the absence of a potential-hang record are the decisive evidence; a sparse
profile cannot by itself prove that a function was never called.

Artifacts:

- `.build/ios-performance/2026-08-30-live-shooting/live-shooting-audio-engine-run2.trace`
- `.build/ios-performance/2026-08-30-live-shooting/live-shooting-audio-engine-run3.trace`
- `live-shooting-audio-engine-run2-swaps.xml` and
  `live-shooting-audio-engine-run3-swaps.xml` in the same directory

## Final hardening smoke status

The final full-16-voice/loop-lifecycle build passes macOS tests, iOS Simulator
build, signed iPhone Release build, installation, and launch smoke on the same
device. A final Instruments attach attempted immediately after that launch
timed out with `Timed out waiting for device to boot`; it produced no usable
trace and is deliberately excluded from the table. The numerical A/B evidence
therefore applies directly to the PCM-player-node mechanism, while the final
edge hardening has device launch validation rather than a third usable trace.

## Next measurement

1. Keep the PCM player-node result as the normal-game firing baseline and
   confirm subjective sound/feel after the user has played beyond the retained
   trace window. If a future release must claim the edge hardening separately,
   capture one fresh exact-version trace after reconnecting Instruments.
2. Return to the corrected active-enemy 2x trace only if it is still needed for
   the separate many-enemy claim. It must not substitute for this real-input
   firing workload.
3. If a later real trace shows a new dominant cost, address projectile
   candidate refresh and the ordered projectile-versus-enemy broad phase while
   retaining source interaction order.
4. Do not combine a collision rewrite with this audio milestone: preserving a
   clean A/B makes the causal story and future regression detection stronger.
