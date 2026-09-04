# Committed test fixtures

Everything else under `ReframedTests/` is generated at test time (`Support/VideoFixtures.swift`, `AudioFixtures.sineWave`). This folder holds the one binary that cannot be synthesised on macOS at run time because AVFoundation has no MP3 encoder.

| File | Content | Size | Used by |
| --- | --- | --- | --- |
| `sine-1s.mp3` | 440 Hz sine, −6 dBFS, mono, 48 kHz, 1.0 s, MPEG-1 Layer III CBR 64 kbps | 8,448 bytes | `AudioFixturesTests.mp3FixtureDecodesToAudioTrack`, `ExternalAudioImporterTests.importsM4aAndMp3` |

## Provenance of `sine-1s.mp3`

Produced once on 2026-09-04 from the same sine generator as `AudioFixtures.sineWave` (`AVAudioFile`, LPCM 16-bit, `sin(2π·440·n/48000) × 0.5`, 1 s, one channel) and encoded with LAME 3.100:

```
lame --quiet -b 64 -m m --cbr --noreplaygain sine-1s.wav sine-1s.mp3
```

No ID3 tags are written; the LAME/Xing header is kept so `AVURLAsset` reports the duration (≈ 1.03 s including encoder padding). A synthesised tone has no author and nothing to license. Regenerate only if the format changes, in its own commit, and keep it under the 10 KB budget from `docs/features/02-music-tracks/ATTACK-PLAN.md`.

Files are loaded with `BundledFixtures.url(_:extension:)` in `Support/Fixtures.swift`, which looks in the `Fixtures` subdirectory of the test bundle and falls back to the bundle root (the synchronized test group flattens subfolders).
