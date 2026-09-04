# Milestone 01: test-foundation

Goal: the pure-logic layer of the inherited editor, compositor, project format, and recording clock is pinned by tests, fixtures can be generated at test time, and the seams those tests need are in place, so feature work can start red-green-refactor on real product code.

Depends on: milestone 00.

Source of the task list: `docs/architecture/07-testability.md` §5 (first fifteen tests) and `docs/features/02-music-tracks/SPIKE.md` (audio-mix pairing characterization).

## Tasks

- [ ] T1. Fixture support: `ReframedTests/Support/Fixtures.swift` (`FixtureAnchor`, temp directories, sine-wave audio generation) and `Support/VideoFixtures.swift` (2 s 320×180 movie generated with `AVAssetWriter`, frame index encoded as color), `Support/ProjectFixtures.swift` (legacy `project.json` literal, cursor metadata builder). Proof: `FixtureTests` generate and read back each fixture.
- [ ] T2. Test 1, legacy `project.json` decode. Proof: `ReframedTests/Project/ProjectMetadataTests.swift`.
- [ ] T3. Test 2, `EditorStateData` round trip through the same encoder settings `ReframedProject.saveEditorState` uses. Proof: same file.
- [ ] T4. Test 3, `History` cap, redo truncation, load clamping, JSON round trip. Proof: `ReframedTests/Editor/HistoryTests.swift`.
- [ ] T5. Test 4, `ReframedProject` bundle lifecycle on a temp directory, with seam S4 (`cleanupTemp` parameter or moved call). Proof: `ReframedTests/Project/ReframedProjectTests.swift`.
- [ ] T6. Test 6, `remapAllRegions` video-cut path (trim path already covered). Proof: `ReframedTests/Compositor/RegionRemappingTests.swift`.
- [ ] T7. Test 7, `CompositionInstruction.sourceTime(for:)` and `resolveZoomRect`. Proof: `ReframedTests/Compositor/CompositionInstructionTests.swift`.
- [ ] T8. Test 8, canvas/render size and `checkNeedsCompositor`. Proof: `ReframedTests/Compositor/InstructionBuilderTests.swift`.
- [ ] T9. Test 12, export tables and encoding settings. Proof: `ReframedTests/Compositor/ExportSettingsTests.swift`.
- [ ] T10. Test 14, golden frame on in-memory buffers. Proof: `ReframedTests/Compositor/FrameRendererGoldenTests.swift`.
- [ ] T11. Audio-mix characterization: `buildAudioMix` pairs tracks and sources by index, including the shifted pairing when a click track precedes the sources. Proof: `ReframedTests/Compositor/AudioMixTests.swift` pins today's behavior; the fix is scheduled with music tracks.
- [ ] T12. Test 9 extension (equal-time keyframes → later one) and test 10, `ZoomDetector` + `groupZoomRegions`. Proof: `ReframedTests/Editor/ZoomTimelineTests.swift`, `ZoomDetectorTests.swift`.
- [ ] T13. Test 11, `CursorSmoothing.smooth` invariants. Proof: `ReframedTests/Editor/CursorSmoothingTests.swift`.
- [ ] T14. Test 13, caption timing and `mergeShortSegments` with seam S7 (drop `private`). Proof: `ReframedTests/Compositor/CaptionTimingTests.swift`, `ReframedTests/Utilities/TranscriptionServiceTests.swift`.
- [ ] T15. Test 15, `SharedRecordingClock`. Proof: `ReframedTests/Recording/SharedRecordingClockTests.swift`.
- [ ] T16. Seams recorded in `planning/upstream-sync.md`; `docs/architecture/07-testability.md` marked with what landed. Proof: grep.
- [ ] T17. `VERIFY.md` run, branch pushed, PR opened, URL recorded.

## Out of scope

- Golden fixtures committed as binaries (everything is generated at test time).
- Export end-to-end test (env-gated, later).
- Fixing the audio-mix pairing (characterize only).
- `RegionMath` extraction (S6 phase 2) until a feature touches the region files.

## Risks

- Three parallel work streams touch the test target; each stream owns distinct files and the integration branch runs `make test` after every merge.
- Generated movie fixtures depend on `AVAssetWriter` behaving headlessly; fall back to a CVPixelBuffer-only path if H.264 encoding is unavailable on CI.
