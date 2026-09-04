# TDD strategy

How this fork tests a codebase that arrived with zero tests. Companion to `docs/architecture/07-testability.md` (tiers, seams, target mechanics) and ADR 0006. Read that first; this file is the working rules.

## Red, green, refactor — rules for this codebase

1. **Test first, in `ReframedTests/` only.** Write the failing test, run `make test T=<Suite>`, see red, then write the minimum production code. If the test cannot be written without a seam, the seam must be one listed in `07-testability.md` §2 (S1–S12) or get an ADR first.
2. **One behavior per test, named as a sentence.** `@Test func trimmedRegionIsShiftedByTrimStart()`, not `testRemap1`. The name is the regression message.
3. **Pin before you change.** Before touching any upstream function, write the characterization test that captures its current output (even if the output looks wrong). Then change behavior in a second commit with the test updated. This is how we keep upstream merges reviewable.
4. **No test touches the real machine.** Forbidden inside tests: `~/.reframed`, `~/Movies`, `~/Reframed`, `/tmp/Reframed`, `UserDefaults`, the network, `LogBootstrap.configure()`, `Permissions.*`, `AVCaptureDevice.requestAccess`. Every disk write goes to `FileManager.default.temporaryDirectory/<UUID>` created and removed by the test. The host itself is redirected by the scheme to `/tmp/reframed-tests/home` and `/tmp/reframed-tests/tmp` through `ReframedPaths`, so even `ConfigService.shared` cannot reach the real config.
5. **Isolation is explicit.** Tests of `@MainActor` types are `@MainActor`. Suites that share a directory use `@Suite(.serialized)`. Fixtures shared across tests are `Sendable` value types.
6. **Deterministic or gated.** No sleeps to "let things settle"; await the real completion. Tests that take more than ~2 s (export, RNNoise, waveform on a real file) live behind `.enabled(if:)` on an env var and never run in the default `make test`.
7. **Refactor step includes `make format` and `make lint`.** Both already cover `ReframedTests/`.
8. **Swift Testing by default.** XCTest only for `measure {}` baselines. Both live in the same `ReframedTests` target.

## Which layer tests which change

| Kind of change | Test layer | How | Examples |
| --- | --- | --- | --- |
| Pure logic (math, Codable, tables, remapping, formatting) | Unit, T1 | Construct values from literals; `#expect` on results; `@Test(arguments:)` for tables | `ZoomTimeline`, `remapAllRegions`, `ProjectMetadata`, `ExportPreset`, `TimeFormatting`, `SharedRecordingClock` |
| Editor state mutation | Unit on `@MainActor`, T2 | `EditorState(result: fixture)` + `await setup()`; mutate; assert on state and on `createSnapshot()`; `teardown()` in `defer` | `addVideoRegion`, `updateCameraRegionEnd`, `undo/redo`, `restoreFromSnapshot` |
| Project bundle I/O | Integration, T2 | Temp dir with dummy media; `ReframedProject.create/open/save*/rename` | Bundle layout, `project.json`, `history.json` |
| Compositing / rendering | Golden frame, T2 | Build `CompositionInstruction` in memory; allocate BGRA `CVPixelBuffer`s (`CVPixelBufferCreate`, 64×36 or 128×72); fill the screen buffer with a known color; call `FrameRenderer.renderFrame(screenBuffer:webcamBuffer:outputBuffer:compositionTime:instruction:)`; lock the output buffer and read bytes (order `B,G,R,A`) | Background color, padding, corner radius, transitions, webcam PiP position, caption presence |
| Golden comparison policy | | Prefer **property assertions** (this pixel is background, this region is non-black, left/right halves symmetric) with tolerance ±3/255. Full-frame hashes only for the HDR path, stored as SHA-256 of the output bytes under `ReframedTests/Golden/<name>.sha256`, regenerated deliberately with `TEST_RUNNER_REFRAMED_UPDATE_GOLDEN=1` | Keeps tests stable across macOS CoreGraphics revisions |
| Export | End-to-end, T2, gated | `ExportPipelineTests` runs `VideoCompositor.export` on `Fixtures/screen-2s.mov` (+ optional webcam/audio) into a temp `outputDirectory` (seam S3) with `.enabled(if: env["REFRAMED_RUN_EXPORT_TESTS"] == "1")`; asserts the file exists, `AVURLAsset` duration ≈ trim length, `naturalSize` = expected render size, track count | `make test-export`; run before every PR that touches `Compositor/` |
| Recording writers | Integration, T2 | Synthetic `CMSampleBuffer`s into `VideoTrackWriter`/`AudioTrackWriter` with a `SharedRecordingClock`; `finish()`; reopen with `AVURLAsset` | Pause offsets, first-frame PTS, buffering fix from `8c67fff` |
| Capture, permissions, windows, Sparkle, Whisper | Manual checklist, T3 | See below | Everything in `07-testability.md` T3 |

### Manual capture checklist (T3)

Run before a release and after any change under `Reframed/Recording/`, `Reframed/State/`, `Reframed/CaptureModes/`. Record results in the milestone's `VERIFY.md`.

- [ ] Entire screen, 10 s, mic on, system audio on → `.frm` opens, audio in sync at the end.
- [ ] Selected area with webcam PiP, pause/resume once → no gap or freeze at the resume point.
- [ ] Selected window, move the window during recording → border follows, cursor metadata stays aligned.
- [ ] Global shortcut stop (default ⌘⇧S) works with another app focused.
- [ ] Export MP4 (parallel), MOV ProRes, GIF from the same project; play all three.
- [ ] Reopen the project after quitting; undo history intact.

## Fixtures

As landed in milestone 01: nothing binary is committed. `ReframedTests/Support/VideoFixtures.swift` generates the movies at test time with `AVAssetWriter` (grey-ramp frame index, about 10 KB for 2 s), `AudioFixtures` generates tones with `AVAudioFile`, and `ProjectFixtures` builds the legacy document, cursor metadata, and a `RecordingResult` in a temp directory. The table below is the original spec.

Location `ReframedTests/Fixtures/`, loaded with `Bundle(for: FixtureAnchor.self).url(forResource:withExtension:subdirectory: "Fixtures")` (`FixtureAnchor` is an empty `final class` in `ReframedTests/Support/Fixtures.swift`).

| File | Content | Budget |
| --- | --- | --- |
| `screen-2s.mov` | 320×180, 30 fps, 2.0 s, H.264, frame index burned in as a solid color ramp so frame N is identifiable | ≤ 120 KB |
| `webcam-2s.mov` | 160×120, 30 fps, 2.0 s, distinct color | ≤ 60 KB |
| `mic-2s.m4a`, `system-2s.m4a` | 48 kHz AAC mono/stereo, 2.0 s, 440 Hz / 880 Hz tones (so tracks are distinguishable in a mix) | ≤ 40 KB each |
| `cursor-2s.json` | `CursorMetadataFile` v1, 120 Hz samples for 2 s, 3 clicks, one typing burst | ≤ 60 KB |
| `legacy-v1-project.json` | Hand-written `project.json` from the oldest supported format (no cursor/zoom/caption fields) | text |
| `sample.frm/` | Directory bundle assembled from the files above plus a current `project.json` and `history.json` | ≤ 300 KB |

Rules: hard limit 300 KB per file, 1 MB total for the folder; binaries are generated by `scripts/make-fixtures.swift` (AVAssetWriter, no ffmpeg dependency) and committed — never hand-edited; regenerate only when the format changes, in its own commit. No real recordings, no faces, no audio of people. `.frm` fixtures are directories; Xcode copies them as bundles because `Info.plist` declares the UTI as `com.apple.package`.

## Definition of done for a PR

- [ ] Tests written before the code; each `planning/features/<name>/TEST-PLAN.md` bullet maps to a test name.
- [ ] `make test` green locally and in CI (`.github/workflows/ci.yml`).
- [ ] `make test-export` green if anything under `Reframed/Compositor/` or `Reframed/Utilities/{EncodingSettings,RNNoiseProcessor,ClickSoundGenerator}.swift` changed.
- [ ] `make format` and `make lint` clean; `make build` has no new warnings.
- [ ] Any new seam in an upstream file is listed in `docs/architecture/07-testability.md` §2 and `planning/upstream-sync.md` "Intentional divergences".
- [ ] Manual checklist run if T3 code changed; results in `VERIFY.md`.
- [ ] No fixture over budget; no test writes outside its temp directory.

## Upstream merges (upstream has no tests)

- Tests are ours. They live only in `ReframedTests/` and `scripts/make-fixtures.swift`; upstream never creates those paths, so merges never conflict there.
- Touch upstream files only at seams (S1–S12) or via access-level widening (S7). Keep each such edit to the smallest diff and list it in `upstream-sync.md`.
- On a sync branch: `git merge upstream/main`, then `make build && make test`. A red test after a merge means upstream changed behavior; read `CHANGELOG.md`, decide whether to accept the new behavior (update the test, note it in the sync PR) or keep ours (fix the code, note the divergence).
- New upstream features arrive untested. Before building on one, add characterization tests for its pure parts (its `+Extension.swift` files are usually T1/T2) in the sync PR or the first feature PR that uses it.
- Never move or rename upstream files for testability; that is what makes `ReframedCore` extraction a future decision, not a default.

## Coverage targets

Measure with `make coverage` (`xcrun xccov view --report`). Targets are per area, not a single number, because ~40 % of the lines are AppKit/SwiftUI that we do not unit test.

| Area | Target | Rationale |
| --- | --- | --- |
| `Project/` (`ProjectMetadata`, `ReframedProject`) | 90 % lines | On-disk contract |
| `Compositor/` logic files (`+RegionRemapping`, `+InstructionBuilder`, `CompositionInstruction`, `FrameRenderer+Helpers`, `+Captions`, `ExportSettings`) | 80 % | Export correctness |
| `Compositor/` drawing (`FrameRenderer*.swift` drawing paths) | 50 % via golden frames | Diminishing returns past the main branches |
| `Editor/` pure math (`CursorSmoothing`, `ZoomTimeline`, `ZoomDetector`, `ZoomRegion`, `CursorEffects`, `CursorLoopTelemetry`, `CursorMetadataProvider`, `History*`) | 85 % | Cheap and high-value |
| `Editor/EditorState*.swift` | 50 % | Region/snapshot logic covered; playback/UI glue not |
| `Utilities/` value helpers | 80 % | |
| `Recording/` writers + clock | 60 % | Synthetic-buffer tests only |
| `State/` (`ConfigService`, `StateService` after S2) | 70 % | |
| `UI/`, `CaptureModes/`, `App/`, `Recording/` capture sources, `SessionState` | not targeted | T3; manual checklist |

Whole-target line coverage will land around 30–40 % once the above are met; do not chase the aggregate. A PR may lower coverage in an untargeted area but must not lower it in a targeted one.

## Flakiness policy

A test that fails intermittently is quarantined the same day with `.disabled("flaky: <issue>")`, an issue is opened, and it is fixed or deleted within the milestone. Retries are not a fix.
