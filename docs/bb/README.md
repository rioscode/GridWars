# Offline Blitz language references

This directory contains offline snapshots of official Blitz Research and
BlitzMax NG documentation used while reproducing the original Grid Wars
BlitzMax program in Swift.

The files were retrieved on **2026-08-24**. The commit IDs below pin the
contents so that language and API decisions remain reproducible even if the
upstream documentation changes.

## Included sources

| Local path | Official source | Pinned revision | Included material |
| --- | --- | --- | --- |
| `blitzmax-legacy/` | [blitz-research/blitzmax](https://github.com/blitz-research/blitzmax) | `56a9602858b6f0b5f21bb138cc94cecc63c99314` | Original BlitzMax language, tutorial, user-guide and generated module documentation, plus upstream README and license |
| `blitzmax-ng/` | [bmx-ng/bmx-ng](https://github.com/bmx-ng/bmx-ng) | `64ed3cb6e7472e59bf036bc6ef8c4db86272d96d` | Current BlitzMax NG language and generated documentation, plus upstream README |
| `blitzmax-ng/brl/` | [bmx-ng/brl.mod](https://github.com/bmx-ng/brl.mod) | `88c99aa13a531c8b18010fc786cedaca3cf57eca` | Relevant BRL modules: random, math, Max2D, audio, audio samples, FreeAudio, WAV and Ogg loaders |
| `blitzbasic/` | [blitz-research/blitz3d](https://github.com/blitz-research/blitz3d) | `6beb288cb5962393684a59a4a44ac11524894939` | Classic BlitzBasic/Blitz3D command and language help, plus upstream README and license |

Snapshot archive URLs:

- `https://codeload.github.com/blitz-research/blitzmax/tar.gz/56a9602858b6f0b5f21bb138cc94cecc63c99314`
- `https://codeload.github.com/bmx-ng/bmx-ng/tar.gz/64ed3cb6e7472e59bf036bc6ef8c4db86272d96d`
- `https://codeload.github.com/bmx-ng/brl.mod/tar.gz/88c99aa13a531c8b18010fc786cedaca3cf57eca`
- `https://codeload.github.com/blitz-research/blitz3d/tar.gz/6beb288cb5962393684a59a4a44ac11524894939`

## Porting evidence

The original `.bmx` files remain the primary behavioural specification. These
references clarify semantics that are otherwise easy to mistranslate:

- `blitzmax-ng/brl/random.mod/random.bmx` documents and implements `Rand(x)`
  as an integer in `1...x`, `Rand(x, y)` as inclusive at both ends, and
  `Rnd(x, y)` as lower-bound inclusive and upper-bound exclusive.
- `blitzmax-legacy/docs/src/Language/Data types.bbdoc` documents BlitzMax
  numeric types and conversions. This matters where the original program
  passes fractional literals to integer APIs or stores floating-point results
  in `Int` fields.
- `blitzmax-legacy/docs/src/Language/BASIC Compatibility.bbdoc` records the
  BASIC-compatible language features used by the game.
- `blitzmax-ng/brl/max2d.mod/` and the audio modules provide the API reference
  for the original drawing, image, sound and channel calls.
- `blitzbasic/_release/help/` is supplemental classic BlitzBasic material. It
  is useful for lineage and command behaviour, but the legacy BlitzMax source
  and documentation take precedence when semantics differ.

## Licensing

The snapshots retain the license and README files supplied by their upstream
repositories. Their presence here is for offline reference and traceability;
each upstream project's own license terms continue to apply.
