# Test plan: Music tracks

Full assertions live in `docs/features/02-music-tracks/ATTACK-PLAN.md`; this table tracks status.

| Spec # | Test suite | Layer | File | Fixture | Status |
|--------|-----------|-------|------|---------|--------|
| 7 | `ExternalAudioTrackDataTests` defaults, round trip, legacy nil, effective volume | unit T1 | `AppShowTests/Project/ExternalAudioTrackDataTests.swift` | none | green (5) |
| 3 | `ExternalAudioTrackMathTests` end, move clamp, trim start/end | unit T1 | `AppShowTests/Editor/ExternalAudioTrackMathTests.swift` | none | green (4) |
| 4 | `HistoryChangeRulesTests` audio track labels | unit T1 | `AppShowTests/Editor/HistoryChangeRulesTests.swift` | none | green (2) |
| 0 | `AudioMixTests` addAudioTracks segment overlap, external tracks, trackID params | T2 | `AppShowTests/Compositor/AudioMixTests.swift` | generated tones | green for P0 rows; external rows pending P7 |
| 0 | `AudioFixturesTests` mp3 decode | T2 | `AppShowTests/Support/AudioFixturesTests.swift` | one ≤10 KB mp3 | green |
| 1 | `ExternalAudioImporterTests` copy, dedupe, reject, formats | T2 | `AppShowTests/Project/ExternalAudioImporterTests.swift` | generated tones | green (5) |
| 1, 7 | `EditorStateExternalAudioTests` placement at playhead, missing file dropped | T2 @MainActor | `AppShowTests/Editor/EditorStateExternalAudioTests.swift` | generated movie + tones | green (4) |
| 2 | `AudioWaveformDownsamplerTests`, `ExternalAudioWaveformStoreTests` | T1 / T2 | `AppShowTests/Editor/...` | generated tones | green (4 + 4) |
| 4, 5 | `ExternalAudioScheduleTests` fades, schedule segments, gap restart | unit T1 | `AppShowTests/Editor/ExternalAudioScheduleTests.swift` | none | red |
| 5 | `ExternalAudioPreviewEngineTests` | gated T2 | `AppShowTests/Editor/ExternalAudioPreviewEngineTests.swift` | tones | red |
| 6 | `ExternalAudioRemapTests`, `InstructionBuilderTests` needsCompositor, `ExportPipelineTests` music mixed | T1 / T2 / gated | `AppShowTests/Compositor/...` | generated | red |
| 6 | `EditorStateExportConfigTests` muted omitted | T2 @MainActor | `AppShowTests/Editor/EditorStateExportConfigTests.swift` | generated | red |

## Manual checks

Track row appearance and drag feel, waveform rendering, audible sync between a click track and on-screen clicks over a long recording, exported file audition. Recorded in `planning/milestones/03-music-tracks/VERIFY.md`.
