# Feature 02 — Music / external audio tracks: spike

Written 2026-09-03 against the working tree (upstream `v0.14.7` plus milestone 00). Every path is relative to the repo root; line numbers were read from the files on this date. No code was changed for this spike.

## Goal

The user adds one or more audio files (mp3, m4a/aac, wav, aiff, flac) to an open project. Each file becomes a track on the timeline (sidebar label "Audio", like Screen / Zoom / Spotlight) with one region that can be moved and trimmed with the same drag handles the system and mic regions use. Per track: volume, mute, fade in, fade out. The music plays in the preview in sync with the screen video, is mixed into the export, and survives save / reopen because the file lives inside the `.frm` bundle.

## What exists today

| Capability | Type / function | Where | Notes |
|---|---|---|---|
| Audio track identity | `enum AudioTrackType { case system, mic }` | `AppShow/Editor/EditorTypes.swift:106-108` | Closed enum; every audio API is keyed on it. External tracks need their own identity (a `UUID`), not a new case. |
| Region model | `struct AudioRegionData { id, startSeconds, endSeconds }` | `AppShow/Project/ProjectMetadata.swift:71-75` | Timeline-only; no notion of an offset inside a source file. |
| Per-track audio settings | `struct AudioSettingsData` (volumes, mutes, noise reduction) | `ProjectMetadata.swift:61-69`, lenient decoder `:583-594` | Two hard-coded tracks. |
| Persisted editor state | `struct EditorStateData` | `ProjectMetadata.swift:463-495` (`systemAudioRegions`/`micAudioRegions` at `:486-487`) | Optionals for post-v1 fields; empty arrays are written as `nil` (`AppShow/Editor/EditorState+Persistence.swift:119-120`). |
| Editor stored state | `EditorState.systemAudioRegions/micAudioRegions`, volumes, mutes | `AppShow/Editor/EditorState.swift:16-17`, `:93-98`; defaults created in `setup()` `:248-253`; restored `:313-318`, `:335-345` | `hasSystemAudio/hasMicAudio` `:127-128`; `effective*Volume` `:130-131`. |
| Region editing | `regions(for:)`, `setRegions`, `updateRegionStart`, `updateRegionEnd`, `moveRegion`, `addRegion`, `removeRegion` | `AppShow/Editor/EditorState+AudioRegions.swift:6-90` | Clamps against neighbours and `duration`; identical algorithm duplicated for camera / video / spotlight (seam S6 in `docs/architecture/07-testability.md`). |
| Region → player sync | `syncAudioRegionsToPlayer()`, `syncAudioVolumes()` | `EditorState+AudioRegions.swift:92-115` | Copies regions as `(CMTime, CMTime)` tuples onto the controller. |
| Waveform | `@MainActor @Observable final class AudioWaveformGenerator` | `AppShow/Editor/AudioWaveformGenerator.swift:6-31`; `extractSamples` `:33-113`; `downsample` `:115-156` | `AVAssetReader` → 16-bit LPCM → peak per bucket, normalised to 1.0. Reads the **whole file into `[Int16]` first** (`:78-108`) before bucketing. `downsample` is `private` (seam S7). |
| Waveform hosting | two `@State` generators, `.task` at open | `AppShow/Editor/EditorView.swift:6-7`, `:90-99`, `:134-155`, `regenerateMicWaveform` `:157-165` | Samples are passed into `TimelineView` as plain `[Float]`. |
| Timeline track drawing | `audioTrackContent(trackType:samples:width:)`, `audioLoadingContent`, `audioRegionCanvas`, `audioRegionView`, `audioRegionWaveform`, `buildWaveformPath` | `AppShow/Editor/TimelineView+AudioTrack.swift:4-56`, `:58-93`, `:95-121`, `:123-204`, `:206-236`, `:238-293` | Waveform maps `samples` across the **full timeline width**; regions clip it. Drag gesture `:161-188`, edge threshold 8 px or 20 % of width; right-click **removes** the region (`:157-160`). |
| Drag math | `effectiveAudioRegion`, `commitAudioDrag`; state `audioDragOffset/Type/RegionId` | `TimelineView+AudioTrack.swift:295-324`; `AppShow/Editor/TimelineView.swift:56-58`; `enum RegionDragType` `AppShow/Editor/ZoomRegion.swift:110-112` | Live preview of the drag without touching `EditorState`; commit on release. |
| Sidebar labels and row layout | `trackSidebar(label:icon:)`; rows "Screen / Camera / System / Mic / Zoom / Spotlight" | `AppShow/Editor/TimelineView+Shared.swift:5-13`; `TimelineView.swift:75-102` (visibility, `visibleTrackCount`, `timelineHeight`), `:106-144` (sidebar), `:151-218` (content) | Row height `Track.height = 36` + 10 spacing (`AppShow/UI/Constants.swift:32-41`). Rows animate in/out with `.trackTransition`. |
| Region popover pattern | `SpotlightRegionEditPopover`; wiring with `popoverSpotlightRegionId`, `.popover(isPresented:arrowEdge:)`, `RightClickOverlay` | `AppShow/Editor/SpotlightRegionEditPopover.swift:3-90`; `AppShow/Editor/TimelineView+SpotlightTrack.swift:57-118` | Local `@State` copies, `onChange` → callback, `OutlineButtonStyle` Remove button. `RegionEditPopover.swift` is the zoom variant (`:3-140`). |
| Properties panel | `audioSection`, `systemAudioSection`, `micAudioSection` | `AppShow/Editor/PropertiesPanel+AudioTab.swift:4-80`; tab switch `AppShow/Editor/PropertiesPanel.swift:74-78` | `ToggleRow` mute + `SliderRow` 0…2 volume + `.onChange { syncAudioVolumes() }`. |
| Audio tab gating | sidebar `disabled` | `AppShow/Editor/EditorView+Sidebar.swift:9-12` | Tab is disabled when there is no recorded audio and no cursor data — must change so music can be added to a silent recording. |
| Preview playback | `SyncedPlayerController`: `AVPlayer` for screen / webcam / system audio; mic through `AVAudioEngine` + `AVAudioPlayerNode` | `AppShow/Editor/SyncedPlayerController.swift:10-31`, init `:33-62` (screen muted when aux audio exists `:47-50`), `setupMicEngine` `:64-90`, `swapMicAudioFile` `:92-116`, drift ratios `:129-171`, 60 Hz observer `:173-189`, gap skip `:191-207`, region muting `:209-223`, `play/pause/seek` `:225-256`, volumes `:258-267`, `teardown` `:269-286`, `scheduleMicPlayback` `:288-304`, `syncAuxPlayers` `:306-313` | Mic path is the template for file-offset playback: `scheduleSegment(file, startingFrame:frameCount:at: nil)` from a frame computed from the screen time. `EditorState+Playback.swift:5-43` is a thin passthrough. |
| Other AV usage | `ClickSoundPlayer` (AVAudioEngine), click-sound preview (`AVAudioPlayer`) | `AppShow/Editor/ClickSoundPlayer.swift:6-18`; `AppShow/Editor/PropertiesPanel+EffectsTab.swift:114` | Confirms a second `AVAudioEngine` per concern is an accepted pattern. |
| Export audio sources | `struct AudioSource { url, regions: [CMTimeRange], volume }`; assembly | `AppShow/Compositor/VideoCompositor.swift:9-13`, `:86-114` | Click track is inserted **before** `addAudioTracks` (`:101-114` vs `:177`). |
| Composition insertion | `addAudioTracks(to:sources:videoTrimRange:videoSegments:)` | `AppShow/Compositor/VideoCompositor+Audio.swift:11-51` | One composition track per source; per video segment (`:26-38`) or per trim (`:39-49`) it inserts the **same** source time range at the remapped composition time (source time == timeline time for recorded audio). |
| Volume mix | `buildAudioMix(for:sources:)` | `VideoCompositor+Audio.swift:53-77` | Returns `nil` when every volume is 1.0; pairs `composition.tracks(withMediaType: .audio)[i]` with `sources[i]` **by index** (`:66-73`). With click sounds on, the click track is index 0 and the pairing is shifted by one — pin with a characterization test before extending. No ramps anywhere. |
| Mix consumption | `AVAssetReaderAudioMixOutput(audioTracks:audioSettings: nil)` + `audioMix`, AAC writer | `AppShow/Compositor/VideoCompositor+ParallelExport.swift:448-462`, `:493-497`; `AppShow/Compositor/VideoCompositor+ManualExport.swift:92-98`, `:137`; passthrough `VideoCompositor.swift:231-250`; `EncodingSettings.aacAudioSettings` `AppShow/Utilities/EncodingSettings.swift:102-109` | The mix output decodes every track to PCM and sums them, so sample-rate and channel differences are handled by AVFoundation; output is always 48 kHz stereo AAC. |
| Passthrough decision | `checkNeedsCompositor` | `AppShow/Compositor/VideoCompositor+InstructionBuilder.swift:6-43` | `clickSoundURL != nil` forces the compositor (`:42`); external audio must do the same. |
| Preprocessing | `processMicrophoneAudio` (RNNoise, AAC 48 kHz), `generateClickSound` | `AppShow/Compositor/VideoCompositor+AudioPreprocessing.swift:6-29`, `:31-79`; `AppShow/Utilities/RNNoiseProcessor.swift:177-183` | Not needed for music; shows the "temp file, defer-delete" pattern. |
| Region remapping under cuts | `remapAllRegions`, `VideoSegment`, `VideoSegmentInfo` | `AppShow/Compositor/VideoCompositor+RegionRemapping.swift:6-63`; `VideoCompositor+Audio.swift:6-9` | Visual regions only; audio is remapped inline in `addAudioTracks`. Tested in `AppShowTests/Compositor/RegionRemappingTests.swift`. |
| Export config | `systemAudioRegions/micAudioRegions: [CMTimeRange]?`, volumes, `processedMicAudioURL` | `AppShow/Compositor/ExportConfiguration.swift:10-11`, `:45-46`, `:51`; built in `AppShow/Editor/EditorState+Export.swift:41-52`, `:149-150`, `:184-187` | Mute becomes volume 0 before the compositor sees it. |
| Bundle files | fixed-name computed URLs; `create` moves media; `open`; `saveEditorState` | `AppShow/Project/AppShowProject.swift:12-47`, `:64-126`, `:128-142`, `:144-152` | No generic "extra media file" support. Layout documented in `docs/project-format.md:7-17`. |
| Media-in-bundle precedent | `setBackgroundImage(from:)` copies to `background-image.<ext>`, style stores the **file name**; restore by name | `AppShow/Editor/EditorState+Background.swift:5-22`, `:33-38`; `EditorState.swift:202-205`; `EditorState+Persistence.swift:257-260` | The pattern to copy: bundle-relative file name in JSON, URL resolved against `project.bundleURL`. |
| Snapshot / restore / observe | `createSnapshot` (audio `:60-78`, `:118-120`), `restoreFromSnapshot` (audio `:200-205`, `:219-226`, sync diff `:275-289`), `observeChanges` (audio `:400-409`) | `AppShow/Editor/EditorState+Persistence.swift` | Every new property must appear in all three (checklist `docs/architecture/06-conventions-checklist.md` §"Adding a new editor property"). |
| History labels | audio settings rule; `regions(\.systemAudioRegions …)` | `AppShow/Editor/History+ChangeRules.swift:196-233`, `:235-246`; helper `History.regions` `AppShow/Editor/History.swift:145-161` | Pure functions of two snapshots (T1). |
| File picker | `NSOpenPanel` with `allowedContentTypes`, `begin`, hop to main | `AppShow/Editor/PropertiesPanel+Background.swift:128-141` (also `+CameraTab.swift:271`, `AppShow/UI/SettingsView.swift:125,143`) | Copy verbatim for audio. |
| Fades (any kind) | `SpotlightRegionData.fadeDuration` | `ProjectMetadata.swift:84` | Visual only. There is **no audio fade** in preview or export. |
| Test target | `AppShowTests` is a `PBXFileSystemSynchronizedRootGroup` | `AppShow.xcodeproj/project.pbxproj:517-523` | New test files need no project edit. The app group is a classic `PBXGroup` (`:579`, 246 `PBXBuildFile` entries): **every new production file needs a `PBXFileReference` + `PBXBuildFile` + group entry**. |

### Format support (macOS 15, AVFoundation)

`AVURLAsset` decodes MP3, AAC (`.m4a`, `.aac`), Apple Lossless, LPCM (`.wav`, `.aiff`, `.caf`) and FLAC natively; Ogg/Opus and WMA are not decodable. Both export writers read through `AVAssetReaderAudioMixOutput` with `audioSettings: nil`, which decodes and resamples every input to one PCM stream before the AAC encoder, so **no conversion step is needed** for the composited paths. The only path that would not re-encode is passthrough (`VideoCompositor.swift:231-250`); an MP3 track inside an `AVAssetExportPresetPassthrough` export would be written as-is (or the mix ignored), so music must force the compositor path. The recorded tracks are ALAC in `.m4a` (`AppShow/Recording/AudioTrackWriter.swift:37`), which shows mixed codecs in one composition already work.

## Gaps

1. No data type for "an audio file with an offset into the file"; `AudioRegionData` has no `fileIn`/`fileOut`, no volume, no fades.
2. `AudioTrackType` is a closed two-case enum; the timeline, editor extension and controller all switch on it.
3. `AppShowProject` knows only fixed file names; no helper for an arbitrary bundle-relative media file.
4. No fade support in the mix (`setVolumeRamp` never used) nor in preview.
5. `buildAudioMix` pairs tracks and sources by index and returns `nil` when all volumes are 1.0; adding tracks with ramps needs explicit `trackID` pairing.
6. `checkNeedsCompositor` does not know about extra audio; passthrough would bypass the mix.
7. `AudioWaveformGenerator` holds a whole file's samples in memory; fine for a 10-minute ALAC recording, not for a 60-minute MP3 (≈ 700 MB of `Int16`).
8. `EditorView` owns exactly two waveform generators; N tracks need a keyed store.
9. The Audio tab is disabled for projects without recorded audio (`EditorView+Sidebar.swift:11`).
10. The 60 Hz observer mutes/unmutes by region but has no per-tick gain computation (needed for fades).
11. No test fixtures exist yet (`AppShowTests/` has four suites and no `Fixtures/` or `Support/` folder), so the first phase must create the audio fixture helper.

## Recommended data model

New file `AppShow/Project/ExternalAudioTrackData.swift` (keeps the upstream `ProjectMetadata.swift` diff to one field):

```swift
struct ExternalAudioTrackData: Codable, Sendable, Identifiable, Equatable {
  var id: UUID = UUID()
  var fileName: String
  var displayName: String
  var sourceDurationSeconds: Double
  var timelineStartSeconds: Double
  var fileInSeconds: Double = 0
  var fileOutSeconds: Double
  var volume: Float = 1.0
  var muted: Bool = false
  var fadeInSeconds: Double = 0
  var fadeOutSeconds: Double = 0
  var timelineEndSeconds: Double { timelineStartSeconds + (fileOutSeconds - fileInSeconds) }
  var effectiveVolume: Float { muted ? 0 : volume }
}
```

- `fileName` is bundle-relative (`audio-<hash8>.<ext>`), resolved as `project.bundleURL.appendingPathComponent(fileName)`, mirroring `.image(filename)`.
- One file = one track = one region. Overlap between tracks is allowed because each track is its own row.
- Lenient decoding in `extension ExternalAudioTrackData { init(from:) }` with `decodeOrDefault` for `volume`, `muted`, `fadeIn`, `fadeOut`, `fileInSeconds` (`AppShow/Utilities/LenientCodable.swift`).
- `EditorStateData.externalAudioTracks: [ExternalAudioTrackData]?` appended at `ProjectMetadata.swift:494`; `createSnapshot` writes `nil` when empty; `restoreFromSnapshot` and `setup()` read it; `observeChanges` lists it. Old `project.json` files decode to `nil` → `[]`. `ProjectMetadata` needs no new flag; on open, tracks whose file is missing are dropped with a `logger.warning`.
- Waveform cache is not part of the JSON. Optional sidecar `audio-<hash8>.waveform.json` (`[Float]`, 200 values) written next to the media file; absent or stale → regenerate.
- `EditorState.externalAudioTracks: [ExternalAudioTrackData] = []` stored next to `micAudioRegions` (`EditorState.swift:17`); all behaviour in a new `AppShow/Editor/EditorState+ExternalAudio.swift`.
- Pure geometry in `enum ExternalAudioTrackMath` (`AppShow/Editor/ExternalAudioTrackMath.swift`, T1): `move(track, newStart, duration)`, `trimStart(track, newTimelineStart)` (moves `fileIn` and `timelineStart` together so audio stays anchored), `trimEnd(track, newTimelineEnd)` (moves `fileOut`, clamped to `sourceDuration`), `clamped(to duration)`. Trimming past the file's own length is impossible by construction; extending the region past the recording end is clamped (owner question 2).

## Import flow

1. Entry points: "Add Audio File…" button in the Audio tab (`OutlineButtonStyle(size: .medium, fullWidth: true)`), later drag-and-drop onto the timeline. `NSOpenPanel` with `allowedContentTypes: [.mp3, .mpeg4Audio, .wav, .aiff, UTType("org.xiph.flac")]`, `allowsMultipleSelection = true`, pattern from `PropertiesPanel+Background.swift:128-141`.
2. `EditorState.importExternalAudio(from url: URL) async` → `ExternalAudioImporter.import(sourceURL:into bundleURL:)` (new `AppShow/Project/ExternalAudioImporter.swift`, `nonisolated`, T2):
   - validate with `AVURLAsset.loadTracks(withMediaType: .audio)` non-empty and `load(.duration)`; reject otherwise with `CaptureError.recordingFailed("…")` (the only app error type).
   - hash the file (SHA-256, `CryptoKit`) → `audio-<first 8 hex>.<lowercased ext>`; if that file already exists in the bundle, reuse it (dedupe). Never delete media during a session; orphans referenced by `history.json` must survive undo (see risks).
   - `copyItem` into the bundle. Return `(fileName, displayName, durationSeconds)`.
3. Back on the main actor: build `ExternalAudioTrackData` placed at the playhead (`timelineStart = CMTimeGetSeconds(currentTime)`, `fileOut = min(sourceDuration, duration − timelineStart)`), append, `scheduleSave()`, push a history snapshot immediately (gesture-style, like `EditorView+Preview.swift:158`).
4. Waveform: `ExternalAudioWaveformStore` (`@MainActor @Observable`, `[UUID: [Float]]` + progress) starts a `Task.detached(priority: .userInitiated)` per track, following `AudioWaveformGenerator.generate` (`:14-31`) but with a streaming downsampler that keeps only one peak per bucket (no whole-file `[Int16]`), then writes the sidecar cache. Reads the cache first on project open.

## Preview playback design

Keep `AVPlayer` for the recorded media and add a dedicated `@MainActor final class ExternalAudioPreviewEngine` (`AppShow/Editor/ExternalAudioPreviewEngine.swift`) owning one `AVAudioEngine` and one `AVAudioPlayerNode` + `AVAudioFile` per track, connected to `mainMixerNode` with each file's `processingFormat` (exactly `setupMicEngine`, `:74-90`). `SyncedPlayerController` owns it and calls:

| Hook | Where | Call |
|---|---|---|
| `play()` | `SyncedPlayerController.swift:225-235` | `external.start(at: seconds(currentTime))` |
| `pause()` | `:237-244` | `external.stop()` |
| `seek(to:)` | `:246-256` | `external.stop()`; if `isPlaying`, `start(at:)` |
| gap skip in preview mode | `:191-207` (after `scheduleMicPlayback(from:)`) | `external.start(at: next.start)` |
| 60 Hz observer | `:173-189` | `external.tick(at: seconds(time))` |
| `teardown()` | `:269-286` | `external.teardown()` |
| tracks changed | new `setExternalAudioTracks(_:)` mirroring `syncAudioRegionsToPlayer` | reload files, restart if playing |

- Scheduling math is a pure `enum ExternalAudioSchedule` (T1): for timeline time `t`, a track is audible when `timelineStart ≤ t < timelineEnd`; `startFrame = (fileIn + (t − timelineStart)) × sampleRate`, `frameCount = (fileOut − fileIn − (t − timelineStart)) × sampleRate`; a track that starts later is scheduled with `at: AVAudioTime(sampleTime: delayFrames, atRate:)` relative to the node's render time so the engine starts it on time without a timer.
- `tick(at:)` sets `node.volume = effectiveVolume × fadeGain(t)`, linear ramps over `fadeIn` after `timelineStart` and `fadeOut` before `timelineEnd`; 16 ms steps are inaudible for fades ≥ 100 ms.
- Rate: external audio has no drift ratio (it was not recorded against the shared clock), so it always plays at 1.0; screen playback is also always 1.0 (`screenPlayer.play()`), so no varispeed node is needed. If variable-rate scrubbing is ever added, insert `AVAudioUnitVarispeed` per node.
- Scrub: the timeline `onScrub` already pauses then seeks (`EditorView.swift:148-151`), so scrubbing is silent for music exactly as it is for the mic.
- `screenPlayer.isMuted = true` must also hold when external tracks exist (today only when recorded audio exists, `:47-50`); screen recordings carry no audio track, so this is belt and braces.

## Export mixing design

- `ExportConfiguration.externalAudioTracks: [ExternalAudioExportTrack] = []` where `struct ExternalAudioExportTrack: Sendable { url, timelineRange: CMTimeRange, fileStart: CMTime, volume: Float, fadeIn: CMTime, fadeOut: CMTime }`, built in `EditorState+Export.swift` with `effectiveVolume`, skipping tracks with volume 0.
- New `AppShow/Compositor/VideoCompositor+ExternalAudio.swift`:
  - `static func insertions(for track:, videoTrimRange:, videoSegments: [VideoSegmentInfo]?) -> [ExternalAudioInsertion]` (pure, T1). Per segment (or per trim): `overlap = [max(trackStart, segStart), min(trackEnd, segEnd)]`; `compositionStart = seg.compositionStart + (overlapStart − segStart)`; `fileRange = [fileStart + (overlapStart − trackStart), + overlap.duration]`. This is the one place where timeline time and file time differ from the recorded-audio case in `addAudioTracks` (`+Audio.swift:26-49`).
  - `static func volumeRamps(for track:, insertions:) -> [(CMTimeRange, Float, Float)]` (pure, T1): fade-in over `[trackStart, trackStart + fadeIn]`, fade-out over `[trackEnd − fadeOut, trackEnd]`, each intersected with every insertion and mapped to composition time, so a fade split by a cut still ramps continuously across the surviving part.
  - `static func addExternalAudioTracks(to composition:, tracks:, …) async throws -> [(CMPersistentTrackID, ExternalAudioExportTrack, [ExternalAudioInsertion])]` (T2): `addMutableTrack(withMediaType: .audio)`, `insertTimeRange(fileRange, of: audioTrack, at: compositionStart)`, returning the real `trackID`.
  - `static func externalMixParameters(...) -> [AVMutableAudioMixInputParameters]`: `setVolume(volume, at: .zero)` then `setVolumeRamp(fromStartVolume:toEndVolume:timeRange:)` per ramp.
- `VideoCompositor.export` (`VideoCompositor.swift:177-183`) appends these parameters to the mix; when `buildAudioMix` returns `nil` (all recorded volumes 1.0) a mix is created anyway if external parameters exist. Parameters are keyed by `trackID`, sidestepping the index pairing; a characterization test pins today's pairing first.
- `checkNeedsCompositor` gains `|| !config.externalAudioTracks.isEmpty` (`+InstructionBuilder.swift:33-42`) so the AAC re-encode path is always used with music. GIF export has no audio and ignores the tracks.
- Trims and cuts: with no cuts `videoTrimRange = trimStart…trimEnd` and a single "segment"; with cuts `videoSegments` come from `VideoCompositor.swift:46-57`. Feature 01 (lossless cut) produces the same `VideoSegment` list, so music remap composes with it for free.

## UI design

- Timeline: one row per external track, sidebar `trackSidebar(label: "Audio", icon: "music.note")` appended after "Mic" in both the sidebar (`TimelineView.swift:125-129`) and content (`:182-199`) stacks; `visibleTrackCount += externalAudioTracks.count`. Region chip reuses `Track.background`, `Track.borderColor`, `Track.borderRadius`, and the waveform fill from `audioRegionView` (`+AudioTrack.swift:137-153`), but the waveform maps the file's samples over `[fileIn, fileOut]` onto the region width (new `externalAudioWaveform`, reusing `buildWaveformPath`). Chip shows `displayName` when wider than 50 px (as the spotlight chip does at `+SpotlightTrack.swift:68-71`).
- Drag: new state trio `externalDragOffset/Type/TrackId` in `TimelineView.swift` beside `:56-58`; same edge threshold and cursors; commit through `EditorState` methods that call `ExternalAudioTrackMath`. Left edge = trim (audio stays anchored), right edge = trim end, body = move. Empty row hint is not needed (a row exists only when a file exists).
- Right-click on the chip opens `ExternalAudioRegionEditPopover` (new, pattern `SpotlightRegionEditPopover`): `SectionHeader(title: displayName)`, `ToggleRow` Mute, `SliderRow` Volume 0…2, `SliderRow` Fade In / Fade Out 0…5 s step 0.1, `Divider`, Remove (`OutlineButtonStyle`). This diverges from system/mic where right-click removes; a file track has properties worth a popover.
- Properties panel, Audio tab: new `PropertiesPanel+MusicSection.swift` with `musicSection` listed in `PropertiesPanel.swift:74-78` after `audioSection`: `SectionHeader(icon: "music.note", title: "Music")`, one compact row per track (name, mute, volume), and the "Add Audio File…" button. Sidebar gating at `EditorView+Sidebar.swift:11` drops the "no recorded audio" condition for `.audio`.
- Design tokens only (`AppShowColors`, `FontSize`, `Track`, `Layout`), `let _ = colorScheme` in every new view, no stock button styles.

## Risks

| Risk | Why | Mitigation |
|---|---|---|
| **Preview sync drift between `AVPlayer` (screen) and `AVAudioEngine` (music)** | Two independent clocks; the mic path already accepts this, but a 3-minute music bed under a 20-minute recording makes a 30–60 ms drift audible against on-screen events | Resync on every `play`/`seek`/gap skip; once per second compare `node.playerTime(forNodeTime:)`-derived timeline time with `screenPlayer.currentTime()` and reschedule when the delta exceeds 40 ms; later, anchor the node start to the player item's `timebase` host time (`CMSyncConvertTime`) for sub-frame alignment |
| Long files and memory | `AudioWaveformGenerator` buffers the whole file (`:78-108`); a 60-minute MP3 decodes to ~700 MB | Streaming per-buffer peak downsampler for external tracks; cache sidecar; never reuse the upstream generator for music |
| Bundle growth and orphaned media | A 100 MB WAV is copied into the `.frm`; removing a track cannot delete the file because a history snapshot (persisted in `history.json`) may still reference it | Dedupe by hash; never delete during a session; add an explicit "Clean unused media" action later that scans current state **and** history |
| `buildAudioMix` index pairing | Adding tracks and ramps on top of index pairing would silently mis-assign volumes when click sounds are on | Characterization test first; key external parameters by `trackID`; consider fixing upstream pairing in the same phase and recording it in `planning/upstream-sync.md` |
| Passthrough export | `AVAssetExportPresetPassthrough` neither re-encodes MP3 nor reliably applies a mix | Force the compositor when tracks exist |
| Timeline height | Every track adds 46 px; `timelineHeight` drives `fixedSize` (`EditorView.swift:67-68`) | Accept for v1; lane packing later if the owner wants many tracks |
| pbxproj churn | Each new production file is a hand-edited `PBXFileReference`/`PBXBuildFile` pair (classic group) | Keep new files to the list in the attack plan; add them in one commit per phase |
| Fixture generation | AVFoundation cannot encode MP3, so an MP3 decode test cannot synthesise its input at run time | Generate WAV/CAF/M4A sine waves at test time; commit one tiny synthesised MP3 (≤ 10 KB) for the decode test |
| User file licensing | Whether the user may use a given song is not the app's concern; no rights checks, no watermarking | Document only |

## Questions for the owner

1. Multiple files: one timeline row per file (assumed) or a single "Audio" row with lanes?
2. May a track hang past the end of the recording (clipped at export) or is it clamped to the recording length (assumed clamped)?
3. Placement on import: at the playhead (assumed) or at 0:00?
4. Fade shape: linear (assumed) or equal-power?
5. Should music auto-duck under the microphone? Out of scope for v1 unless wanted.
6. Loop a short file to fill the recording? Assumed no.
7. Should the Audio tab be enabled for recordings with no audio so music can be added (assumed yes; needs the sidebar gating change)?
8. Orphan media policy: keep forever (assumed) or clean on close?
9. Warn above a file size (e.g. 200 MB)?
