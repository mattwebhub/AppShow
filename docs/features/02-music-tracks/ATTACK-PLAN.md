# Feature 02 — Music / external audio tracks: attack plan

Read `SPIKE.md` first. Rules: `planning/tdd-strategy.md` (failing test first, `make test T=<Suite>` red, minimal change, green, `make format`, `make lint`). Tiers are T1/T2/T3 from `docs/architecture/07-testability.md` §1. Tests use Swift Testing, `@testable import Reframed`, and live under `ReframedTests/` mirroring `Reframed/`. `ReframedTests` is a synchronized group, so test files need no project edit; every new production file listed below needs a `PBXFileReference`, a `PBXBuildFile`, and a group entry in `Reframed.xcodeproj/project.pbxproj` (classic `PBXGroup`, see `SPIKE.md` "Test target").

Sizes: S ≈ half a day, M ≈ one to two days, L ≈ three or more days.

## Fixture strategy (no committed binaries except one)

`ReframedTests/Support/AudioFixtures.swift`:

```swift
enum AudioFixtures {
  enum Container { case wav, caf, m4a }
  static func sineWave(seconds: Double = 2, frequency: Double = 440, sampleRate: Double = 48_000,
                       channels: AVAudioChannelCount = 1, container: Container = .wav, in dir: URL) throws -> URL
  static func temporaryDirectory() throws -> URL
}
```

- Fills one `AVAudioPCMBuffer` with `sin(2π·f·n/sr)` at −6 dBFS and writes it with `AVAudioFile(forWriting:settings:)`: LPCM 16-bit for `.wav`/`.caf`, `kAudioFormatMPEG4AAC` for `.m4a`. A 2 s mono WAV is 192 KB on disk but lives only in the per-test temp directory (`FileManager.default.temporaryDirectory/<UUID>`), removed in `defer`.
- A synthesised tone has no author, so there is nothing to license (CC0 in spirit). Different frequencies (440 / 880 Hz) make tracks distinguishable in a mix by peak position in an FFT-free check: read the mixed output back with `AVAssetReader`, compute RMS over a window, assert non-silence where music should be and silence where it should not.
- MP3: AVFoundation has no MP3 encoder, so one committed `ReframedTests/Fixtures/sine-1s.mp3` (mono, 64 kbps, ≤ 10 KB, produced once offline from the same generator; provenance noted in `scripts/make-fixtures.swift`) is used only by the "decodes MP3" test. Well under the 300 KB budget in `planning/tdd-strategy.md`.
- Screen movie: phases that need `EditorState.setup()` (duration from `AVURLAsset`) also need `ReframedTests/Fixtures/screen-2s.mov` from milestone 01's `scripts/make-fixtures.swift`. Until it exists, `AudioFixtures.blankMovie(seconds: 2, in:)` writes a 64×36 H.264 movie with `AVAssetWriter` at run time (a few KB, < 1 s).

## Phases

### Phase 0 — Pins and fixtures (S)

Failing tests first:

| Test | File | Assertion | Tier |
|---|---|---|---|
| `sineWaveFixtureHasExpectedDurationAndSampleRate()` | `ReframedTests/Support/AudioFixturesTests.swift` | `AVAudioFile(forReading:)` length / sampleRate == 2.0 ± 0.01; `.m4a` variant decodes | T2 |
| `mp3FixtureDecodesToAudioTrack()` | same | `AVURLAsset.loadTracks(.audio)` non-empty, duration ≈ 1.0 | T2 |
| `audioMixPairsTracksWithSourcesByIndex()` | `ReframedTests/Compositor/AudioMixTests.swift` | Composition with three audio tracks from two `AudioSource`s (volumes 0.5, 0.25) + one extra track inserted first, as `VideoCompositor.swift:101-114` does: `buildAudioMix` returns parameters whose `trackID`s are the first two tracks (characterization of today's pairing, `+Audio.swift:66-73`) | T2 |
| `audioMixIsNilWhenAllVolumesAreUnity()` | same | pins `+Audio.swift:60-61` | T2 |
| `addAudioTracksInsertsOnlyRegionOverlapWithSegments()` | same | Two segments `[0,1]→0`, `[1.5,2]→1`, one region `[0.5,2]` → composition track has ranges `[0.5,1]@0.5` and `[1.5,2]@1` (`+Audio.swift:26-38`) | T2 |

Production: none (fixtures and support code only). Manual check: `make test T=AudioMixTests` green; no file written outside the temp directory.

### Phase 1 — Model and persistence round trip (S)

| Test | File | Assertion | Tier |
|---|---|---|---|
| `decodesTrackWithoutOptionalFieldsUsingDefaults()` | `ReframedTests/Project/ExternalAudioTrackDataTests.swift` | JSON with only `id, fileName, displayName, sourceDurationSeconds, timelineStartSeconds, fileOutSeconds` → `fileIn 0`, `volume 1`, `muted false`, fades 0 | T1 |
| `roundTripsThroughEditorStateData()` | same | Encode `EditorStateData` with `.iso8601`/`.sortedKeys` (as `ReframedProject.saveEditorState`, `:144-152`), decode, `externalAudioTracks` equal | T1 |
| `legacyEditorStateWithoutExternalAudioDecodesToNil()` | same | A snapshot JSON lacking the key decodes; field is `nil` | T1 |
| `timelineEndIsStartPlusTrimmedLength()` | `ReframedTests/Editor/ExternalAudioTrackMathTests.swift` | `start 3, fileIn 1, fileOut 4` → end 6 | T1 |
| `moveClampsWithinRecording()` | same | duration 10, length 4, newStart 8 → start 6; newStart −1 → 0 | T1 |
| `trimStartShiftsFileInAndKeepsAudioAnchored()` | same | newTimelineStart 4 on `start 3, fileIn 1` → `start 4, fileIn 2`; cannot pass `end − 0.05` | T1 |
| `trimEndClampsToSourceDurationAndRecording()` | same | `fileOut ≤ sourceDuration`; `end ≤ duration`; `fileOut ≥ fileIn + 0.05` | T1 |
| `describesExternalAudioTrackAddedRemovedAdjusted()` | `ReframedTests/Editor/HistoryChangeRulesTests.swift` | `History.describeChanges` yields "Audio track added" / "removed" / "adjusted"; volume/mute/fade diffs yield "Audio track volume set to 80%", "Audio track muted", "Audio track fade in set to 1.0s" | T1 |

Production (per `docs/architecture/06-conventions-checklist.md` §"Adding a new editor property"):

- New `Reframed/Project/ExternalAudioTrackData.swift` (struct + lenient `init(from:)` extension).
- `Reframed/Project/ProjectMetadata.swift`: one field `externalAudioTracks: [ExternalAudioTrackData]?` on `EditorStateData` (`:494`).
- New `Reframed/Editor/ExternalAudioTrackMath.swift` (`enum ExternalAudioTrackMath`, pure).
- `Reframed/Editor/EditorState.swift`: stored `var externalAudioTracks: [ExternalAudioTrackData] = []` after `:17`; restore in `setup()` next to `:316-318` (drop entries whose file is missing, `logger.warning`).
- `Reframed/Editor/EditorState+Persistence.swift`: emit in `createSnapshot` (`nil` when empty, `:119-120`), apply in `restoreFromSnapshot` (`:200-205`, and call the controller sync when changed, `:284-289`), observe (`:400-409`).
- `Reframed/Editor/History+ChangeRules.swift`: `regions(\.externalAudioTracks, …)` plus a rule for volume/mute/fade text.

Manual check: open an old `.frm`; it loads; undo history labels unchanged.

### Phase 2 — Import into the bundle (M)

| Test | File | Assertion | Tier |
|---|---|---|---|
| `copiesFileIntoBundleWithAudioPrefixAndHash()` | `ReframedTests/Project/ExternalAudioImporterTests.swift` | Temp `x.frm` dir; import a WAV → `audio-<8 hex>.wav` exists; returned `fileName` matches `^audio-[0-9a-f]{8}\.wav$`; `durationSeconds ≈ 2.0` | T2 |
| `secondImportOfIdenticalFileReusesExistingCopy()` | same | Same bytes under another name → same `fileName`, one file in bundle | T2 |
| `rejectsFileWithoutAudioTrack()` | same | A `.txt` renamed `.wav` → throws `CaptureError` | T2 |
| `importsM4aAndMp3()` | same | both succeed; extension preserved lowercase | T2 |
| `newTrackIsPlacedAtPlayheadAndClampedToRecording()` | `ReframedTests/Editor/EditorStateExternalAudioTests.swift` (`@MainActor`) | `EditorState(project:)` on a temp bundle with `screen-2s.mov`; `await setup()`; seek 1.5 s; import 2 s WAV → `timelineStart 1.5`, `fileOut 0.5`; `teardown()` in `defer` | T2 |
| `openingProjectDropsTrackWhoseFileIsMissing()` | same | Save state referencing `audio-deadbeef.wav` that does not exist → after `setup()`, `externalAudioTracks.isEmpty` | T2 |

Production: new `Reframed/Project/ExternalAudioImporter.swift` (`enum`, `nonisolated static func import(sourceURL:into:) async throws -> ImportedExternalAudio`); `Reframed/Project/ReframedProject.swift`: `func externalAudioURL(fileName:) -> URL` next to `:44-47`; new `Reframed/Editor/EditorState+ExternalAudio.swift` with `importExternalAudio(from:)`, `removeExternalAudioTrack(id:)`, `moveExternalAudioTrack(id:newStart:)`, `trimExternalAudioTrackStart/End`, `setExternalAudioTrackVolume/Muted/FadeIn/FadeOut`, `syncExternalAudioToPlayer()` (no-op until Phase 6). Manual check: add an MP3 from Finder; `project.json` lists it; the file is inside the `.frm`.

### Phase 3 — Waveform (S)

| Test | File | Assertion | Tier |
|---|---|---|---|
| `streamingDownsamplerKeepsOnePeakPerBucketAcrossBuffers()` | `ReframedTests/Editor/AudioWaveformDownsamplerTests.swift` | Feed 3 chunks of known `Int16` values into `AudioWaveformDownsampler(totalFrames:count:)`; `finish()` returns `count` values, peak-normalised to 1.0, bucket boundaries independent of chunking | T1 |
| `generatesTwoHundredSamplesForSineFixture()` | `ReframedTests/Editor/ExternalAudioWaveformStoreTests.swift` (`@MainActor`) | `await store.generate(for: trackId, url:)`; `samples[trackId]?.count == 200`; all in `0...1`; sidecar `audio-<hash8>.waveform.json` written next to the file | T2 |
| `loadsSidecarInsteadOfDecodingWhenPresent()` | same | Pre-write a sidecar with 200 zeros → store returns it without touching the audio | T2 |

Production: new `Reframed/Editor/AudioWaveformDownsampler.swift` (pure struct), new `Reframed/Editor/ExternalAudioWaveformStore.swift` (`@MainActor @Observable`, `Task.detached` per track as in `AudioWaveformGenerator.swift:25-27`). No change to `AudioWaveformGenerator`. Manual check: waveform appears on the new row within a second for a 3-minute MP3; memory in Activity Monitor does not spike.

### Phase 4 — Timeline track and region editing (M)

Tests: the drag arithmetic is already covered by `ExternalAudioTrackMathTests` (Phase 1). Add one T1 test for the waveform window mapping: `externalWaveformWindowMapsFileRangeOntoRegionWidth()` in `ReframedTests/Editor/ExternalAudioWaveformWindowTests.swift` — given 200 samples, `fileIn 1`, `fileOut 2`, `sourceDuration 4` → the drawn slice is samples 50…100 stretched to the region width (extract the mapping into a pure `ExternalAudioWaveformWindow.slice(samples:fileIn:fileOut:sourceDuration:) -> [Float]`). Views are T3.

Production: new `Reframed/Editor/TimelineView+ExternalAudioTrack.swift` (`externalAudioTrackContent(track:samples:width:)`, `externalAudioRegionView`, `externalAudioWaveform`, `effectiveExternalTrack`, `commitExternalDrag`) reusing `buildWaveformPath` (`+AudioTrack.swift:238-293`); new `Reframed/Editor/ExternalAudioRegionEditPopover.swift`; new `Reframed/Editor/ExternalAudioWaveformWindow.swift`; `Reframed/Editor/TimelineView.swift`: three `@State` vars beside `:56-58`, `popoverExternalTrackId`, the row in `visibleTrackCount` (`:89-97`), sidebar rows after `:129`, content rows after `:199`, a new `externalAudioSamples: [UUID: [Float]]` input; `Reframed/Editor/EditorView.swift`: owns the store (`@State`), starts generation after `setup()` (`:90-99`) and on track changes, passes samples into `timeline` (`:134-155`). Manual check: drag body / edges with the same cursors as the Mic row; right-click opens the popover; Remove deletes the row with the track transition animation.

### Phase 5 — Properties: volume, mute, fades (S)

| Test | File | Assertion | Tier |
|---|---|---|---|
| `effectiveVolumeIsZeroWhenMuted()` | `ExternalAudioTrackDataTests.swift` | `muted true, volume 1.5` → 0 | T1 |
| `fadeGainRampsLinearlyInsideTrackAndIsOneElsewhere()` | `ReframedTests/Editor/ExternalAudioScheduleTests.swift` | `fadeIn 1, fadeOut 2` on `[10, 20]`: gain(10) 0, gain(10.5) 0.5, gain(15) 1, gain(19) 0.5, gain(20) 0; gain(9.9) 0 (outside) | T1 |
| `fadesAreClampedToHalfTheTrackLength()` | same | length 1, fades 5 → each 0.5 | T1 |

Production: new `Reframed/Editor/ExternalAudioSchedule.swift` (`enum ExternalAudioSchedule` with `gain(track:at:)`, used by Phase 6); new `Reframed/Editor/PropertiesPanel+MusicSection.swift` (`musicSection`: header, per-track rows with `ToggleRow` / `SliderRow` 0…2, fade sliders 0…5 step 0.1, Remove, and "Add Audio File…" via `NSOpenPanel`); `Reframed/Editor/PropertiesPanel.swift:74-78` lists `musicSection`; `Reframed/Editor/EditorView+Sidebar.swift:11` stops disabling the Audio tab for silent recordings; `Reframed/Editor/EditorView.swift:18-26` includes track count in `timelineTrackSignature`. Manual check: mute hides nothing on the timeline but silences; undo labels read correctly in the history popover.

### Phase 6 — Preview playback in sync (L)

| Test | File | Assertion | Tier |
|---|---|---|---|
| `scheduleReturnsNilBeforeTrackStartAndAfterEnd()` | `ExternalAudioScheduleTests.swift` | `segment(track:at: 9.9)` nil for `[10,20]`; `at: 20` nil | T1 |
| `scheduleOffsetsIntoFileByElapsedTime()` | same | `fileIn 1, start 10, at 12, sr 48000` → `startFrame 144000`, `frameCount == (fileOut − 3) × 48000` | T1 |
| `scheduleForFutureTrackReturnsDelayFrames()` | same | `at 8` for `[10,20]` → `delayFrames 96000`, `startFrame fileIn × sr` | T1 |
| `engineStartsAndStopsWithoutOutputDevice()` | `ReframedTests/Editor/ExternalAudioPreviewEngineTests.swift` (`@MainActor`, `.enabled(if: env["REFRAMED_RUN_AUDIO_ENGINE_TESTS"] == "1")`) | `setTracks`, `start(at:)`, `tick`, `stop`, `teardown` do not throw or crash; node volume after `tick(at:)` equals `gain × volume` | T2 (gated) |

Production: new `Reframed/Editor/ExternalAudioPreviewEngine.swift`; `Reframed/Editor/SyncedPlayerController.swift`: stored `let externalAudio = ExternalAudioPreviewEngine()` and the seven hooks from `SPIKE.md` "Preview playback design" (`:47-50`, `:173-189`, `:191-207`, `:225-235`, `:237-244`, `:246-256`, `:269-286`) plus `setExternalAudioTracks(_:)`; `EditorState+ExternalAudio.syncExternalAudioToPlayer()` now forwards tracks; `restoreFromSnapshot` calls it when tracks differ. Manual check (T3): play from 0, from inside a track, from after it; scrub across a fade; toggle preview mode with two video regions and confirm the music jumps with the video; leave a 10-minute recording playing with music and compare a clap in the video against the beat at the end (< 40 ms).

### Phase 7 — Export mixing (M)

| Test | File | Assertion | Tier |
|---|---|---|---|
| `insertionWithoutCutsIsClippedToTrimAndOffsetIntoFile()` | `ReframedTests/Compositor/ExternalAudioRemapTests.swift` | trim `[5,10]`, track `[3,8]`, `fileIn 1` → one insertion `composition [0,3]`, `file [3,6]` | T1 |
| `insertionEntirelyOutsideTrimIsDropped()` | same | track `[12,15]` → `[]` | T1 |
| `insertionsFollowVideoSegmentsAndKeepFileContinuity()` | same | segments `[0,2]→0`, `[5,7]→2`; track `[1,6]`, `fileIn 0` → `comp [1,2] file [0,1]` and `comp [2,3] file [4,5]` | T1 |
| `fadeRampsAreMappedIntoCompositionTimeAndSplitByCuts()` | same | track `[1,6]`, `fadeIn 2` with the segments above → ramp `[1,2]` 0→0.5 and `[2,3]` 0.5→1.0 (continuous across the cut) | T1 |
| `addExternalAudioTracksCreatesOneCompositionTrackPerTrack()` | `AudioMixTests.swift` | Two WAV fixtures → two new audio tracks with the expected `segments` ranges and distinct `trackID`s | T2 |
| `mixParametersUseTrackIDsAndRamps()` | same | Parameters count == tracks; `getVolumeRamp(for:)` at `.zero` reports the fade-in ramp | T2 |
| `needsCompositorWhenExternalTracksExist()` | `ReframedTests/Compositor/InstructionBuilderTests.swift` | Default config + one track → `checkNeedsCompositor == true` | T1 |
| `exportMixesMusicIntoTrimmedOutput()` | `ReframedTests/Compositor/ExportPipelineTests.swift` (`.enabled(if: env["REFRAMED_RUN_EXPORT_TESTS"] == "1")`, needs seam S3 `outputDirectory`) | 2 s movie, 880 Hz track at `[0.5, 1.5]`, trim `[0,2]` → output has one audio track; RMS over `[0.6,1.4]` > −20 dBFS, over `[0,0.4]` < −60 dBFS | T2 (gated) |

Production: new `Reframed/Compositor/ExternalAudioExportTrack.swift` (Sendable struct + `ExternalAudioInsertion`), new `Reframed/Compositor/VideoCompositor+ExternalAudio.swift`; `Reframed/Compositor/ExportConfiguration.swift`: `externalAudioTracks: [ExternalAudioExportTrack] = []`; `Reframed/Editor/EditorState+Export.swift`: build the array (`effectiveVolume`, skip 0) and pass it (`:143-208`); `Reframed/Compositor/VideoCompositor.swift:177-183`: call `addExternalAudioTracks` after `addAudioTracks`, merge parameters into the mix (create a mix when `buildAudioMix` is `nil`); `Reframed/Compositor/VideoCompositor+InstructionBuilder.swift:33-42`: one more `||`. Manual check: export MP4 in `.parallel` and `.normal`; play in QuickTime; music level and fades match the preview; ProRes MOV also fine; GIF unaffected.

### Phase 8 — Cuts, trims, and feature 01 interplay (S)

| Test | File | Assertion | Tier |
|---|---|---|---|
| `trackBeforeTrimStartIsDroppedEvenWithFades()` | `ExternalAudioRemapTests.swift` | no insertion, no ramps | T1 |
| `fadeOutSurvivesWhenLastSegmentCutsTheTrackEnd()` | same | track `[0,10]`, `fadeOut 2`, segments `[0,4]→0`, `[7,9]→4` → fade-out ramp becomes `[5,6]` 1→0.5 (the `[9,10]` part is gone) | T1 |
| `exportConfigCarriesTracksWithMuteAsZeroVolume()` | `ReframedTests/Editor/EditorStateExportConfigTests.swift` (`@MainActor`) | muted track is omitted; `fileStart == fileIn`; `timelineRange` matches | T2 |
| `previewGapSkipRestartsMusicAtNextRegion()` | `ExternalAudioScheduleTests.swift` | Pure helper `nextAudibleTime(after:in videoRegions:)` returns `next.start` (mirrors `SyncedPlayerController.swift:194-203`) | T1 |

Production: only what the tests demand (edge-case fixes in `VideoCompositor+ExternalAudio.swift`); when feature 01 lands, its keep-slices feed the same `VideoSegmentInfo` list, so no further change. Manual check: two cuts, one music track across both; export and preview agree.

## Parallelism and order

| Phase | Depends on | Can run beside |
|---|---|---|
| 0 | — | 1 |
| 1 | 0 (fixtures only for the math tests: none) | 0 |
| 2 | 1 | 3, 5, 7-math |
| 3 | 1 | 2, 5, 6-math, 7-math |
| 4 | 1, 3 | 5, 6, 7 |
| 5 | 1 | 2, 3, 4 |
| 6 | 1, 5 (`ExternalAudioSchedule`) | 4, 7 |
| 7 | 1 | 4, 5, 6 |
| 8 | 7 | — |

Two developers: A takes 1 → 2 → 4 → 6; B takes 0 → 3 → 5 → 7 → 8. Pure-math files (`ExternalAudioTrackMath`, `ExternalAudioSchedule`, `VideoCompositor+ExternalAudio` insertions/ramps) are the T1 core and should be green before any view or engine code is written.

## New files summary

| Folder | Production files | Test files |
|---|---|---|
| `Reframed/Project/` | `ExternalAudioTrackData.swift`, `ExternalAudioImporter.swift` | `ReframedTests/Project/ExternalAudioTrackDataTests.swift`, `ExternalAudioImporterTests.swift` |
| `Reframed/Editor/` | `ExternalAudioTrackMath.swift`, `EditorState+ExternalAudio.swift`, `AudioWaveformDownsampler.swift`, `ExternalAudioWaveformStore.swift`, `ExternalAudioWaveformWindow.swift`, `TimelineView+ExternalAudioTrack.swift`, `ExternalAudioRegionEditPopover.swift`, `PropertiesPanel+MusicSection.swift`, `ExternalAudioSchedule.swift`, `ExternalAudioPreviewEngine.swift` | `ReframedTests/Editor/ExternalAudioTrackMathTests.swift`, `HistoryChangeRulesTests.swift`, `EditorStateExternalAudioTests.swift`, `AudioWaveformDownsamplerTests.swift`, `ExternalAudioWaveformStoreTests.swift`, `ExternalAudioWaveformWindowTests.swift`, `ExternalAudioScheduleTests.swift`, `ExternalAudioPreviewEngineTests.swift`, `EditorStateExportConfigTests.swift` |
| `Reframed/Compositor/` | `ExternalAudioExportTrack.swift`, `VideoCompositor+ExternalAudio.swift` | `ReframedTests/Compositor/AudioMixTests.swift`, `ExternalAudioRemapTests.swift`, `InstructionBuilderTests.swift`, `ExportPipelineTests.swift` |
| `ReframedTests/Support/` | — | `AudioFixtures.swift`, `AudioFixturesTests.swift` |

Upstream files touched (smallest possible diffs, each listed in `planning/upstream-sync.md`): `ProjectMetadata.swift`, `ReframedProject.swift`, `EditorState.swift`, `EditorState+Persistence.swift`, `History+ChangeRules.swift`, `TimelineView.swift`, `EditorView.swift`, `EditorView+Sidebar.swift`, `PropertiesPanel.swift`, `SyncedPlayerController.swift`, `EditorState+Export.swift`, `ExportConfiguration.swift`, `VideoCompositor.swift`, `VideoCompositor+InstructionBuilder.swift`, `project.pbxproj`.

## Definition of done

- [ ] Every table row above exists as a named `@Test` and was red before its production change.
- [ ] `make test` green; `make test-export` (once it exists) green with `REFRAMED_RUN_EXPORT_TESTS=1`; the gated engine test passes on a developer Mac.
- [ ] `make format`, `make lint`, `make build` with zero warnings.
- [ ] An old `.frm` without `externalAudioTracks` opens unchanged; a project saved with music reopens with the track, waveform, and settings intact; undo/redo of add / move / trim / remove each produce one readable history entry.
- [ ] Preview and export agree on position, trim, volume, and fades, with and without video cuts, in `.parallel` and `.normal` modes; GIF export still works.
- [ ] No test writes outside its temp directory; the only committed binary is `sine-1s.mp3` (≤ 10 KB).
- [ ] `docs/project-format.md` and `docs/editor.md` gain a paragraph on `audio-<hash8>.<ext>` files and the Audio track; `planning/upstream-sync.md` lists every touched upstream file.
- [ ] Owner questions 1, 2, 7 from `SPIKE.md` answered or the stated assumptions confirmed.
