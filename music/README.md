# Apple audio conversions

The original GridWars 5.4 music is preserved in `Theme0.it`, `Theme1.it`, and
`Theme2.it`. AVFoundation does not decode Impulse Tracker modules, so the Swift
targets bundle lossless ALAC conversions with matching base names:

- `Theme0.m4a`: intro/attract music, 30.82 seconds
- `Theme1.m4a`: gameplay music, 261.22 seconds
- `Theme2.m4a`: high-score music, 38.50 seconds

They were rendered without gain, tempo, pitch, channel, or sample edits using
libopenmpt 0.8.9 at 44.1 kHz stereo/16-bit, then encoded losslessly:

```sh
openmpt123 --batch --quiet --samplerate 44100 --channels 2 --no-float \
  --output /tmp/Theme0.wav --force Theme0.it
ffmpeg -i /tmp/Theme0.wav -c:a alac Theme0.m4a
```

Repeat the same two commands for Theme1 and Theme2. Runtime looping and volume
are handled by `OriginalAudioEngine`.
