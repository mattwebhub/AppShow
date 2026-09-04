# 07 — Testability

> Historical analysis note: this document records the inherited v0.14.7 testability assessment and the seams chosen before the test target and AppShow identity migration landed. Paths have been updated where useful, but quoted old identifiers and pre-change hazards remain evidence of the baseline. Current commands and environment names are in `AGENTS.md`.

**Scope.** How to put the inherited codebase under test without rewriting it. Written against the working tree on 2026-09-03: upstream `v0.14.7` (`b6a1709`) plus the milestone-00 changes already applied locally (ADR 0003 ad-hoc signing through `Config.xcconfig`, ADR 0004 Sparkle automatic checks off, `make lint`, `.github/workflows/ci.yml`). There is still **no test target**: `AppShow.xcodeproj/project.pbxproj` has one `PBXNativeTarget` and `AppShow.xcodeproj/xcshareddata/xcschemes/AppShow.xcscheme` has an empty `<TestAction>`. `ci.yml` already runs `make test`, so this document is the spec for `PLAN.md` tasks T8/T9 and for ADR 0006.

Sections: 1 tiers · 2 seams · 3 test-target mechanics · 4 `make test` · 5 first fifteen tests.

---

## 1. Testability tiers

| Tier | Definition | Runs where |
| --- | --- | --- |
| **T1** | Pure logic. No host app, no permissions, no disk (or only a caller-supplied temp URL), no hardware. Constructible from literals. | Unit test, every PR, seconds |
| **T2** | Needs a fixture file, a temp directory, an in-memory `CVPixelBuffer`, or a small injection refactor (a seam from §2) before it can be tested. Still no permissions or hardware. | Unit/integration test, every PR, seconds to tens of seconds |
| **T3** | Needs ScreenCaptureKit, `AVCaptureDevice`, TCC permissions, a display, the network, Sparkle, or a live `NSWindow`. | Manual checklist (`planning/tdd-strategy.md`), never in `make test` |

`@testable import AppShow` exposes `internal` declarations only. Anything marked `private`/`fileprivate` below is T2 until its access level is widened (seam S7).

### T1 — pure logic (test now, no changes needed)

**Editor math**

| Type / function | File | Why T1 |
| --- | --- | --- |
| `CursorSmoothing.smooth(samples:speed:clicks:zoomTimeline:keystrokes:)`, `CursorMovementSpeed.tension/friction/mass/convergenceDuration` | `AppShow/Editor/CursorSmoothing.swift` | Spring integrator over `[CursorSample]`; deterministic; only `Foundation`/`CoreGraphics` |
| `ZoomTimeline.zoomRect(at:)`, `ZoomTimeline.followCursor(_:cursorPosition:)`, `ZoomKeyframe` (Codable, Equatable) | `AppShow/Editor/ZoomTimeline.swift` | Inverse-zoom interpolation with the quintic ease `t³(t(6t−15)+10)`; `NSLock` only; `@unchecked Sendable` so fixtures can be `let` globals |
| `ZoomDetector.detect(from:duration:config:)`, `ZoomDetectorConfig` | `AppShow/Editor/ZoomDetector.swift` | Click clustering into keyframes; pure over `CursorMetadataFile` |
| `groupZoomRegions(from:)` (free function), `ZoomRegion` | `AppShow/Editor/ZoomRegion.swift` | Pure array scan |
| `smoothstep(_:)` | `AppShow/Utilities/MathUtilities.swift` | One-liner used by every transition |
| `CursorEffects.computeSwayRotation/computeClickBounceScale/computeMotionBlurVelocity` | `AppShow/Editor/CursorEffects.swift` | Pure math with named constants |
| `CursorLoopTelemetry.makeLoopable(samples:duration:)` | `AppShow/Editor/CursorLoopTelemetry.swift` | Pure; GIF loop return path |
| `CursorMetadataProvider.sample(at:)/cursorType(at:)/activeClicks(at:within:)/clickEvents(from:to:)/makeSnapshot()`, `CursorMetadataSnapshot`, and the file-private `cursorBinarySearch`/`cursorSample` they wrap; `CursorMetadataFile`, `CursorSample` (custom `init(from:)` tolerating a missing `c`), `CursorClickEvent`, `KeystrokeEvent`, `SystemCursorType` | `AppShow/Editor/CursorMetadataProvider.swift`, `AppShow/Editor/CursorMetadata.swift` | Construct `CursorMetadataFile(...)` in memory; `load(from:)` is the only disk path |
| `VideoPreviewView.computeTransitionProgress(...)`, `resolveTransitionType(...)` | `AppShow/Editor/VideoPreviewView+Transitions.swift` | `static` on a view type but pure; mirror of `FrameRenderer` helpers, so a shared parametrized test can pin both |
| `History` (`@MainActor @Observable`): `pushSnapshot` (50-cap, redo truncation), `undo/redo/jumpTo`, `load(from:)` clamping, `toData()`; `HistoryEntry`/`HistoryData` Codable | `AppShow/Editor/History.swift` | Needs a `@MainActor` test, not a host |
| `History.rules`, `History.describeChanges(from:to:)`, `describeBackground`, `describeCameraBackground`, and the builders `prop/toggle/sub/subToggle/regions` | `AppShow/Editor/History+ChangeRules.swift`, `History.swift` | Pure functions of two `EditorStateData` values |
| `CanvasAspect.size(for:)`, `CameraAspect.heightToWidthRatio(webcamSize:)`, `CameraFullscreenAspect.aspectRatio(webcamSize:)`, labels | `AppShow/Editor/EditorTypes.swift` | Enums |
| `CursorStyle` (`label`, `isCentered`, raw values 0…21), `CursorRenderer.colorizedSVG(for:fillHex:strokeHex:)` | `AppShow/Editor/CursorRenderer.swift` | String substitution over embedded SVG templates. `renderSVGToImage`/`drawCursor` need `NSImage`/`CGContext` but run headless (T2 golden) |

**Compositor logic**

| Type / function | File | Why T1 |
| --- | --- | --- |
| `VideoCompositor.remapAllRegions(config:hasVideoRegions:videoSegments:effectiveTrim:scaleX:)` → `RemappedRegions`; `VideoSegment` | `AppShow/Compositor/VideoCompositor+RegionRemapping.swift` | Pure `CMTime` arithmetic over `ExportConfiguration`; exercises the private `remapRegion/remapCustomRegion/remapSpotlightRegion/remapVideoRegions/remapCaptionSegments` |
| `VideoCompositor.checkNeedsCompositor(...)`, `computeCanvasSize(...)`, `computeRenderSize(...)` | `AppShow/Compositor/VideoCompositor+InstructionBuilder.swift` | Pure decisions; `buildCompositionInstruction` is T2 (needs an `AVMutableComposition` + webcam asset) |
| `VideoCompositor.backgroundColorTuples(for:)` | `AppShow/Compositor/VideoCompositor+Background.swift` | Pure mapping from `BackgroundStyle`/`GradientPresets` |
| `CompositionInstruction.init(...)` (all-defaults constructor), `sourceTime(for:)`, `isSpotlightActive(at:)`, `effectiveSpotlightSettings(at:)`; `RegionTransitionInfo`, `CameraCustomRegion`, `VideoSegmentMapping` | `AppShow/Compositor/CompositionInstruction.swift` | In-memory value object; the `AVVideoCompositionInstructionProtocol` conformance is inert (see `00-overview.md` §"disagrees", item 4) |
| `FrameRenderer.computeRegionTransition`, `resolveActiveTransitionType`, `resolveZoomRect`, `resolveCamera`, `backgroundImageRect`, `aspectFillRect`, `shadowBlur` | `AppShow/Compositor/FrameRenderer+Helpers.swift` | Pure over `CompositionInstruction` + `CMTime` |
| `FrameRenderer.captionSegmentAt(time:in:)`, `visibleText(for:at:maxWordsPerLine:)` | `AppShow/Compositor/FrameRenderer+Captions.swift` | Pure; 1.5 s linger rule and 2-line windowing |
| `ExportSettings` and `ExportPreset.settings`, `ExportFPS.value(fallback:)/numericValue`, `ExportResolution.pixelWidth`, `ExportCodec.videoCodecType/exportPreset/isProRes`, `ExportAudioBitrate.value`, `GIFQuality.value`, `ExportFormat.fileType/fileExtension/isGIF`, `CaptionExportMode` | `AppShow/Compositor/ExportSettings.swift` | Value tables users depend on |
| `ExportConfiguration` defaults | `AppShow/Compositor/ExportConfiguration.swift` | Memberwise struct |
| `EncodingSettings.exportVideoSettings/captureVideoSettings/aacAudioSettings` | `AppShow/Utilities/EncodingSettings.swift` | Returns dictionaries; assert keys and bitrate multipliers |
| `BackgroundStyle` / `CameraBackgroundStyle` custom Codable (unknown `type` → `.none`) | `AppShow/Compositor/BackgroundStyle.swift`, `CameraBackgroundStyle.swift` | Pure Codable |
| `CameraLayout.pixelRect(screenSize:webcamSize:cameraAspect:)` | `AppShow/Compositor/CameraLayout.swift` | Pure geometry |
| `GradientPresets.all` (ids 0…86), `preset(for:)`, `GradientPreset.cgStartPoint/cgEndPoint` | `AppShow/Compositor/GradientPresets.swift` | Table; `cgColors` uses `NSColor(Color)` — headless OK |

**Project format**

| Type / function | File | Why T1 |
| --- | --- | --- |
| `ProjectMetadata`, `EditorStateData`, `CursorSettingsData`, `ZoomSettingsData`, `AnimationSettingsData`, `AudioSettingsData`, `CaptionSettingsData`, `AudioRegionData`, `CameraRegionData`, `VideoRegionData`, `SpotlightRegionData`, `CaptionSegment`, `CaptionWord`, `CodableSize`, and the lenient `init(from:)` extensions at the bottom of the file | `AppShow/Project/ProjectMetadata.swift` | JSON round trip with `JSONEncoder/Decoder` (`.iso8601` dates as in `AppShowProject`) |
| `CaptionPosition.init(from:)` (accepts legacy `"top"/"center"/other` strings) and clamping init | same | Compatibility rule for old `project.json` |
| `CaptionLayout.scaledFontSize(...)` (pure), `CaptionLayout.measureText(...)` (CoreText, headless) | same | Deterministic on one machine; use tolerances |
| `CaptionLanguage.sortedCases/whisperCode`, `CaptionFontWeight`, `CameraRegionType`, `RegionTransitionType` | same | Enums |
| `KeyedDecodingContainer.decodeOrDefault(_:_:)` | `AppShow/Utilities/LenientCodable.swift` | Pure |
| `AppShowProject.name` | `AppShow/Project/AppShowProject.swift` | Pure; the rest of the type is T2 |

**Utilities and state values**

| Type / function | File | Why T1 |
| --- | --- | --- |
| `formatDuration(seconds:)`, `formatDuration(_:)`, `formatPreciseDuration(_:)/(seconds:)`, `formatCompactTime(seconds:)`, `formatTimeRange(start:end:)`, `formatTimestamp(_:)`, `formatRelativeTime(_:)` | `AppShow/Utilities/TimeFormatting.swift` | Free functions; `formatTimestamp` takes a `Date` (locale-independent format string) |
| `CGRect.normalized`, `CGRect.clamped(to:)` | `AppShow/Utilities/CGRect+Extensions.swift` | Pure |
| `CodableColor` (`hexString`, `init(cgColor:)` RGB and gray paths, Codable) | `AppShow/Utilities/CodableColor.swift` | Pure |
| `KeyboardShortcut.matchesCGEvent(keyCode:flags:)`, `keyName(for:)`, `displayString`, Codable; `ShortcutAction.defaultShortcut/isGlobal/isSessionAction`; `matches(_ NSEvent)` via `NSEvent.keyEvent(...)` | `AppShow/Utilities/KeyboardShortcut.swift` | Pure; `NSEvent.keyEvent` constructs headless |
| `SubtitleExporter.exportSRT/exportVTT(segments:to:)` | `AppShow/Utilities/SubtitleExporter.swift` | Writes to a caller-supplied URL (temp dir); timestamp formatting private → assert on file contents |
| `SharedRecordingClock.registerStream(firstPTS:)`, `referenceTimeSeconds`, `adjustPTS(_:pauseOffset:)` | `AppShow/Recording/SharedRecordingClock.swift` | Pure `CMTime` arithmetic behind an `NSLock`; this is the A/V-sync invariant |
| `CaptureMode.cameraMaxDimensions(for:)`, `CaptureMode` Codable | `AppShow/State/CaptureMode.swift` | Enum |
| `CaptureState` (Equatable), `CaptureError.errorDescription` | `AppShow/State/CaptureState.swift` | Enums |
| `CaptureQuality.isProRes/label`, `TimerDelay`, `AudioDevice`, `CaptureDevice` | `AppShow/State/RecordingOptions.swift` | Value types only (the `RecordingOptions` class is T2/T3) |
| `ClickSoundStyle.category/label`, `ClickSoundStyle.styles(for:)`, `ClickSoundGenerator.generateClickBuffer(style:sampleRate:)` | `AppShow/Utilities/ClickSoundGenerator.swift` | Decodes embedded PCM into an `AVAudioPCMBuffer`; no device |
| `WhisperModel` labels/raw values | `AppShow/Utilities/WhisperModelManager.swift` | Enum only; the manager is T3 |
| `MenuBarIcon.makeImage(for:)` | `AppShow/Utilities/MenuBarIcon.swift` | CoreGraphics into `NSImage`; assert size/non-nil |
| `SendableBox` | `AppShow/Utilities/SendableBox.swift` | Trivial |

### T2 — fixtures, temp dirs, or a seam first

| Type / function | File | What it needs |
| --- | --- | --- |
| `ConfigService` (merge-over-defaults `load()`, `save()`, shortcuts API) | `AppShow/State/ConfigService.swift` | `private init()` hardcodes `~/.reframed/reframed.json` → seam **S2** (`init(fileURL:)` / `AppShowPaths`). `applyAppearance()` touches `NSApp` |
| `StateService` | `AppShow/State/StateService.swift` | Same as above (`~/.reframed/state.json`) |
| `RecordingOptions` | `AppShow/State/RecordingOptions.swift` | Reads `ConfigService.shared` in `init` and every `didSet`; runs `AVCaptureDevice.DiscoverySession` only when a saved device id exists → seam **S11**, or test with an empty temp config |
| `EditorState` and its extensions: `+AudioRegions`, `+CameraRegions`, `+VideoRegions`, `+SpotlightRegions`, `+Zoom`, `+Captions`, `+CameraLayout`, `+Persistence` (`createSnapshot`/`restoreFromSnapshot`/`undo`/`redo`), `sourceTimeForPreviewElapsed`, `previewElapsedTime` | `AppShow/Editor/EditorState*.swift` | `EditorState(result:)` + `await setup()` needs a real movie because `duration` comes from `SyncedPlayerController.loadDuration()` (`AVURLAsset.load(.duration)`). Use `AppShowTests/Fixtures/screen-2s.mov`; call `teardown()` at the end. Region arithmetic is duplicated four times and could become T1 via seam **S6** |
| `AppShowProject.create(from:fps:captureMode:sourceName:in:)`, `open(at:)`, `saveEditorState`, `saveHistory/loadHistory`, `rename(to:)`, `delete()`, `recordingResult`, `screenVideoURL` (`.mov` preferred over `.mp4`) | `AppShow/Project/AppShowProject.swift` | Temp directory + dummy media files. `create` calls `FileManager.cleanupTempDir()` which wipes `/tmp/AppShow` → seam **S4** |
| `SyncedPlayerController.loadDuration()/computeDriftRatios()/seek` | `AppShow/Editor/SyncedPlayerController.swift` | Fixture movie; `AVAudioEngine` for mic may log an error without an output device — acceptable |
| `AudioWaveformGenerator.generate(from:count:)` (private `downsample`) | `AppShow/Editor/AudioWaveformGenerator.swift` | Fixture `.m4a`; `downsample` → seam S7 |
| `MediaFileInfo.load(url:)`, `formattedFileSize(url:)` | `AppShow/Utilities/MediaFileInfo.swift` | Fixture / temp file |
| `FrameRenderer.computeFrameState(...)`, `renderFrame(screenBuffer:webcamBuffer:outputBuffer:compositionTime:instruction:processedWebcamImage:)`, `drawBackground/drawScreenVideo/drawWebcam/drawCaptions/drawCursorOverlay/drawSpotlightOverlay` | `AppShow/Compositor/FrameRenderer*.swift` | In-memory `CVPixelBuffer`s (`kCVPixelFormatType_32BGRA`); golden-frame harness. `renderFrameHDR` uses CoreImage (`FrameRenderer+HDR.swift`) — pin with tolerances, not hashes |
| `VideoCompositor.buildCompositionInstruction(...)`, `addAudioTracks(...)`, `buildAudioMix(for:sources:)`, `generateClickSound(...)`, `processMicrophoneAudio(...)` | `AppShow/Compositor/VideoCompositor+InstructionBuilder.swift`, `+Audio.swift`, `+AudioPreprocessing.swift` | `AVMutableComposition` built from fixtures; temp URLs |
| `VideoCompositor.export(result:config:progressHandler:)` → `runManualExport`, `parallelRenderExport`, `gifExport`, passthrough | `AppShow/Compositor/VideoCompositor*.swift` | Fixtures + output-directory seam **S3**; slow (seconds) → env-gated end-to-end test only |
| `RNNoiseProcessor.processFile(inputURL:outputURL:intensity:)` | `AppShow/Utilities/RNNoiseProcessor.swift` | Fixture `.m4a`, CPU only; RNNoise is statically linked into the host |
| `ClickSoundGenerator.generateClickAudioFile(at:clickTimes:volume:totalDuration:style:)` | `AppShow/Utilities/ClickSoundGenerator.swift` | Temp URL; read back with `AVAudioFile` |
| `VideoTranscoder.merge(...)` | `AppShow/Recording/VideoTranscoder.swift` | Fixtures |
| `VideoTrackWriter` / `AudioTrackWriter` (`init`, `appendSampleBuffer`/`appendSample`, `pause`, `resume(withOffset:)`, `finish()`) | `AppShow/Recording/VideoTrackWriter.swift`, `AudioTrackWriter.swift` | Synthetic `CMSampleBuffer`s (`CMSampleBufferCreateReadyWithImageBuffer`) + `SharedRecordingClock`; temp output URL. Verifies PTS adjustment and pause gaps without any capture |
| `CursorMetadataRecorder.configure/recordClick/recordKeystroke/finish` | `AppShow/Recording/CursorMetadataRecorder.swift` | `start()` spins timers reading `NSEvent.mouseLocation`/`NSCursor` (T3); `recordClick` after `configure` is testable only if `startHostTime` can be set → needs a `now` seam; defer |
| `SelectionRect.screenCaptureKitRect` (AppKit→SCK Y flip, even-dimension rounding) | `AppShow/CaptureModes/Common/SelectionRect.swift` | `init(rect:displayID:)` reads `NSScreen.screen(for:)` → seam **S5** |
| `TranscriptionService.mergeShortSegments`, `stripSpecialTokens` (`private static`), `EditorState.filterNonSpeechSegments` (`private static`) | `AppShow/Utilities/TranscriptionService.swift`, `AppShow/Editor/EditorState+Captions.swift` | Pure, but `private` → seam **S7** |
| `SystemCursorRenderer.cachedImage/drawSystemCursor` | `AppShow/Editor/SystemCursorRenderer.swift` | Loads cursor PDFs from system paths; machine-dependent → smoke test only |
| `RotatingFileLogHandler` | `AppShow/Logging/RotatingFileLogHandler.swift` | Writes `~/Library/Logs/AppShow` → needs a directory seam; low value |
| `KeyboardShortcutManager.performAction(_:on:)` | `AppShow/State/KeyboardShortcutManager.swift` | Needs a `SessionState`, which needs S2; `start()` is T3 |

### T3 — permissions, hardware, windows, network (manual / integration only)

| Area | Types | File(s) | Blocker |
| --- | --- | --- | --- |
| Screen capture | `ScreenCaptureSession`, `RecordingCoordinator` (+`Screen`, `+Device`, `+Lifecycle`), `CaptureTarget`, `Permissions.fetchShareableContent` | `AppShow/Recording/`, `AppShow/App/Permissions.swift` | `SCStream`, `SCShareableContent`, Screen Recording TCC |
| Camera / mic / system audio / iOS device | `WebcamCapture`, `MicrophoneCapture` (incl. `targetFormat(deviceId:)`), `SystemAudioCapture`, `DeviceCapture`, `DeviceDiscovery` (CMIO property set in `init`) | `AppShow/Recording/` | `AVCaptureDevice.requestAccess`, real devices |
| Global input | `MouseClickMonitor` (`NSEvent.addGlobalMonitorForEvents`), `KeyboardShortcutManager.start()` (`CGEvent.tapCreate`), `CursorMetadataRecorder.start()` | `AppShow/Recording/MouseClickMonitor.swift`, `AppShow/State/KeyboardShortcutManager.swift` | Accessibility / Input Monitoring TCC |
| Permissions | `Permissions` (`CGPreflightScreenCaptureAccess`, `AXIsProcessTrusted`, request variants) | `AppShow/App/Permissions.swift` | TCC state of the machine |
| Windows and overlays | `SessionState` (+ all extensions), `SelectionCoordinator`, `WindowSelectionCoordinator`, `WindowPositionObserver`, `CaptureToolbarWindow`, `SelectionOverlayWindow/View`, `RecordingBorderWindow`, `StartRecordingOverlay`, `RecordingPreviewWindow`, `WebcamPreviewWindow`, `DevicePreviewWindow`, `EditorWindow`, `VideoPreviewContainer*`, `CursorOverlayLayer`, everything in `AppShow/UI/` | `AppShow/State/`, `AppShow/CaptureModes/`, `AppShow/UI/`, `AppShow/Editor/` | `NSScreen`, live `NSWindow`/`NSPanel`, SwiftUI hosting; `SessionState.transition(to:)` creates panels as a side effect |
| Updates and models | `SparkleUpdater`, `UpdateChecker.fetchLatestChangelog()`, `WhisperModelManager`, `TranscriptionService.transcribe(...)` | `AppShow/Utilities/` | Network, Sparkle, multi-GB model downloads |
| Display queries | `NSScreen.primaryScreenHeight/unionFrame/displayID/screen(for:)/displayID(for:)` | `AppShow/Utilities/NSScreen+Extensions.swift` | Display topology |
| Sound | `SoundEffect` | `AppShow/Utilities/SoundEffect.swift` | Audio output |

---

## 2. Seams and coupling problems

Rule from `planning/README.md`: upstream files are edited for testability only at seams listed here. Every seam below is additive (a new initializer, a new optional field, a new file, or a widened access level) so upstream merges stay trivial.

### S1 — Launch sequence side effects (`AppDelegate`)

**Problem.** A hosted test bundle launches the real app. `AppShow/App/AppDelegate.swift`:

```swift
let session = SessionState()                         // property initializer: runs before didFinishLaunching

func applicationDidFinishLaunching(_ notification: Notification) {
  _ = SparkleUpdater.shared                          // SPUStandardUpdaterController(startingUpdater: true)
  ConfigService.shared.applyAppearance()             // NSApp.appearance
  let manager = KeyboardShortcutManager(session: session)
  manager.start()                                    // CGEvent.tapCreate(.cgSessionEventTap, .defaultTap, keyDown)
  ...
  if !Permissions.allPermissionsGranted {            // CGPreflightScreenCaptureAccess() && AXIsProcessTrusted()
    showPermissionsWindow()                          // 800×500 window + NSApp.activate(ignoringOtherApps: true)
  }
  eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { ... }
}
```

and `AppShow/AppShowApp.swift` runs `LogBootstrap.configure()` in `init()` (`LoggingSystem.bootstrap` may only be called once per process — tests must never call it again) and creates the `MenuBarExtra` status item.

**Fix (minimal, no protocol).** New file `AppShow/App/LaunchEnvironment.swift`:

```swift
import Foundation

enum LaunchEnvironment {
  static let isTestHost: Bool = {
    let env = ProcessInfo.processInfo.environment
    return env["APPSHOW_TEST_HOST"] == "1"
      || env["XCTestConfigurationFilePath"] != nil
      || env["XCTestBundlePath"] != nil
  }()
}
```

and one guard as the first statement of `applicationDidFinishLaunching`: `guard !LaunchEnvironment.isTestHost else { return }`. `APPSHOW_TEST_HOST=1` is set in the scheme's `TestAction` (§3.5) so the guard does not depend on which harness (XCTest or Swift Testing) sets which variable. `session` still gets constructed (it is a `let` and `AppShowApp.body` reads it) — that is why S2 is also needed.

### S2 — `ConfigService` / `StateService` singletons write to the real home directory

**Problem.** `AppShow/State/ConfigService.swift:117` and `AppShow/State/StateService.swift:121` do `FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".reframed")` inside `private init()`. `SessionState.init` (`AppShow/State/SessionState.swift:34`) and `RecordingOptions.init` read `ConfigService.shared`, so the test host reads (and any test that sets a property writes) the developer's real `~/.reframed/reframed.json`. `WhisperModelManager` and `FileManager+AppShow` (`/tmp/AppShow`) have the same hardcoding.

**Fix.** One new file `AppShow/Utilities/AppShowPaths.swift`:

```swift
import Foundation

enum AppShowPaths {
  static var home: URL {
    if let override = ProcessInfo.processInfo.environment["APPSHOW_HOME"] {
      return URL(fileURLWithPath: override, isDirectory: true)
    }
    return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".reframed", isDirectory: true)
  }

  static var temp: URL {
    if let override = ProcessInfo.processInfo.environment["APPSHOW_TMP"] {
      return URL(fileURLWithPath: override, isDirectory: true)
    }
    return URL(fileURLWithPath: "/tmp/AppShow", isDirectory: true)
  }
}
```

plus, in `ConfigService` and `StateService`, an internal `init(fileURL: URL)` that the existing `private init()` delegates to (`self.init(fileURL: AppShowPaths.home.appendingPathComponent("reframed.json"))`), and `FileManager.reframedTempDir()`/`cleanupTempDir()` reading `AppShowPaths.temp`. Tests construct `ConfigService(fileURL: tmp)` directly (the type is `@MainActor`, so the test is too); the scheme sets `APPSHOW_HOME`/`APPSHOW_TMP` to a per-run directory so even `.shared` is harmless in the host. No fake needed — the real class on a temp file is the fake.

### S3 — Export writes into `~/Movies/AppShow` and `/tmp/AppShow`

**Problem.** `VideoCompositor.export` (`AppShow/Compositor/VideoCompositor.swift`) picks its output via `FileManager.default.tempRecordingURL()`/`tempGIFURL()` and `await MainActor.run { FileManager.default.defaultSaveURL(...) }`, which reads `ConfigService.shared.outputFolder`. An export test pollutes the user's Movies folder.

**Fix.** Add `var outputDirectory: URL? = nil` to `ExportConfiguration` (`AppShow/Compositor/ExportConfiguration.swift`); in `export` compute the destination directory once: `let outDir = config.outputDirectory ?? await MainActor.run { FileManager.default.defaultSaveDirectory() }`. Additive; `EditorState.export` does not set it.

### S4 — `AppShowProject.create` wipes the shared temp directory

> Landed 2026-09-04 as `create(..., cleanupTemp: Bool = true)`; the production caller is unchanged.

**Problem.** `AppShow/Project/AppShowProject.swift:97` calls `fm.cleanupTempDir()` (deletes every file in `/tmp/AppShow`) as part of creating a bundle. A project test running while a real recording is in flight, or two tests in parallel, would delete each other's files.

**Fix.** Move the call to the recording-stop path in `AppShow/State/SessionState+Recording.swift` (the only production caller), or add a `cleanupTemp: Bool = true` parameter. Combined with S2's `APPSHOW_TMP` either is safe.

### S5 — `SelectionRect` reads `NSScreen` in its initializer

**Problem.** `AppShow/CaptureModes/Common/SelectionRect.swift` stores `displayOrigin`/`displayHeight` but only has `init(rect:displayID:)`, which looks them up via `NSScreen.screen(for:)`. The Y-flip in `screenCaptureKitRect` is pure but unreachable without a display.

**Fix.** Add `init(rect: CGRect, displayID: CGDirectDisplayID, displayOrigin: CGPoint, displayHeight: CGFloat)` and make the existing init delegate to it. Test with `displayOrigin: .zero, displayHeight: 1080`.

### S6 — Region arithmetic lives in `@MainActor EditorState` and depends on `AVPlayer` duration

**Problem.** `addRegion(atTime:)`, `updateRegionStart/End`, `moveRegion` are implemented four times with the same algorithm (`EditorState+AudioRegions.swift`, `+CameraRegions.swift`, `+VideoRegions.swift`, `+SpotlightRegions.swift`), each reading `duration` (from `SyncedPlayerController`) and mutating `@Observable` arrays.

**Fix, phase 1 (no upstream edit).** Test through `EditorState(result: fixtureResult)` + `await setup()` on `@MainActor`; the 2-second fixture gives `duration == 2.0`.

**Fix, phase 2 (when a feature touches these files).** `protocol TimelineRegion { var startSeconds: Double { get set }; var endSeconds: Double { get set } }` adopted by `AudioRegionData`, `CameraRegionData`, `VideoRegionData`, `SpotlightRegionData`, and `enum RegionMath` with `insert(into:at:duration:)`, `clampStart/clampEnd/move`. The four extensions become one-liners and `RegionMath` is T1. Record as an ADR when done.

### S7 — `private static` helpers that are the actual logic

> Landed 2026-09-04 for `TranscriptionService.mergeShortSegments` and `stripSpecialTokens`; milestone 02 extracted `SyncedPlayerController.gapSkipDecision`, `EditorState.exportVideoRegions`/`exportTrimRange`, and `TimelineGeometry.rulerInterval` as internal pure functions. The rest stay private until a test needs them.

`TranscriptionService.mergeShortSegments/stripSpecialTokens` (`AppShow/Utilities/TranscriptionService.swift`), `EditorState.filterNonSpeechSegments` (`AppShow/Editor/EditorState+Captions.swift`), `AudioWaveformGenerator.downsample` (`AppShow/Editor/AudioWaveformGenerator.swift`), `MediaFileInfo.formatBitrate`, `SubtitleExporter.srtTimestamp/vttTimestamp`, `AppShowProject.projectPrefix`, `CursorSmoothing.buildTypingIntervals`. **Fix:** drop `private` (internal is enough for `@testable`). Do it lazily, one function per test that needs it, and list each in `planning/upstream-sync.md`.

### S8 — Wall-clock time

`History.pushSnapshot` stamps `Date()`, `AppShowProject.timestamp()` and `formatTimestamp()` default to `Date()`, `formatRelativeTime(_:)` compares to now. No refactor: pass explicit dates where a parameter exists, and for `formatRelativeTime` use `Date().addingTimeInterval(-90)` with second-granularity expectations.

### S9 — `Permissions` static enum

Used by `AppDelegate`, `PermissionsView`, `SessionState+Selection`. With S1 in place nothing in a unit test reaches it. If a future test needs it: `protocol PermissionGate { var hasScreenRecording: Bool { get }; var hasAccessibility: Bool { get } }`, `struct SystemPermissions: PermissionGate` wrapping the existing statics, `struct StubPermissions: PermissionGate` in tests. Defer.

### S10 — `RecordingOptions` reads `ConfigService.shared`

`init()` and every `didSet` in `AppShow/State/RecordingOptions.swift`. **Fix:** `init(config: ConfigService = .shared)` storing the instance; the `didSet`s use it. Low priority until a test needs `RecordingOptions`.

### S11 — Swift 6 isolation

Not a coupling problem, but it shapes every test: `History`, `EditorState`, `ConfigService`, `StateService`, `SessionState`, `AudioWaveformGenerator`, `SyncedPlayerController` are `@MainActor`; tests of them are `@MainActor` too (§3.7). `CompositionInstruction`, `ZoomTimeline`, `CursorMetadataSnapshot`, `CursorMetadataProvider` are `@unchecked Sendable` classes and can be shared fixtures; `NSImage`/`AVPlayer` cannot.

### S12 — `SessionState` state machine has no pure core

`transition(to:)` in `AppShow/State/SessionState.swift` mutates `state` and immediately creates windows/timers. There is no `CaptureState`-level rule table to test. Leave as T3 until a feature needs it; a `static func nextState(...)` extraction would be the seam.

---

## 3. Test-target mechanics

### 3.1 Why a hosted bundle

All code is in the `AppShow` app target (`productType = "com.apple.product-type.application"`), not a package, so a unit-test bundle must load the app binary: `TEST_HOST` names the executable and `BUNDLE_LOADER` lets the linker resolve the app's symbols. `@testable import AppShow` works because the project-level Debug configuration already has:

```
				ENABLE_TESTABILITY = YES;
```

(`AppShow.xcodeproj/project.pbxproj`, `F10000000000000000000005 /* Debug */`). Release has `SWIFT_COMPILATION_MODE = wholemodule` and no testability, so tests always run with `-configuration Debug`. The module name is `AppShow` (`PRODUCT_NAME = "$(TARGET_NAME)"`).

### 3.2 What to add to `project.pbxproj`

Prefer creating the target in Xcode (File ▸ New ▸ Target ▸ macOS ▸ Unit Testing Bundle, host = AppShow, language Swift, testing system Swift Testing), then verify the result matches this. The project uses `objectVersion = 90`, so the test sources folder can be a `PBXFileSystemSynchronizedRootGroup` (no per-file `PBXBuildFile` entries to merge). Required objects, with placeholder ids in the project's synthetic style:

```
/* PBXFileSystemSynchronizedRootGroup */
		7E570000000000000000000001 /* AppShowTests */ = { isa = PBXFileSystemSynchronizedRootGroup; path = AppShowTests; sourceTree = "<group>"; };

/* PBXNativeTarget */
		7E57000000000000000000000A /* AppShowTests */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = 7E57000000000000000000000B;
			buildPhases = ( 7E57000000000000000000000C /* Sources */, 7E57000000000000000000000D /* Frameworks */, 7E57000000000000000000000E /* Resources */ );
			dependencies = ( 7E57000000000000000000000F /* PBXTargetDependency → F10000000000000000000001 */ );
			fileSystemSynchronizedGroups = ( 7E570000000000000000000001 );
			name = AppShowTests;
			productName = AppShowTests;
			productReference = 7E570000000000000000000010 /* AppShowTests.xctest */;
			productType = "com.apple.product-type.bundle.unit-test";
		};
```

plus a `PBXContainerItemProxy`/`PBXTargetDependency` pair on the app target, the `.xctest` `PBXFileReference` in the `Products` group, the target in `PBXProject.targets`, and `TargetAttributes = { 7E57…0A = { TestTargetID = F10000000000000000000001; }; }`. Test-target build settings (both configurations), verbatim:

```
				BUNDLE_LOADER = "$(TEST_HOST)";
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/AppShow.app/Contents/MacOS/AppShow";
				PRODUCT_BUNDLE_IDENTIFIER = eu.jkuri.reframed.tests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				GENERATE_INFOPLIST_FILE = YES;
				MACOSX_DEPLOYMENT_TARGET = 15.0;
				SWIFT_VERSION = 6.0;
				SWIFT_INCLUDE_PATHS = "$(PROJECT_DIR)/AppShow/Libraries/gifski";
				LD_RUNPATH_SEARCH_PATHS = ( "$(inherited)", "@executable_path/../Frameworks", "@loader_path/../Frameworks" );
				SWIFT_EMIT_LOC_STRINGS = NO;
```

and `baseConfigurationReference = CC0000000000000000000001 /* Config.xcconfig */` on both test configurations so the bundle inherits the same signing as the host (§3.6). No `packageProductDependencies`, no `OTHER_LDFLAGS`, no `LIBRARY_SEARCH_PATHS`.

### 3.3 gifski (vendored static library)

The app target links it with:

```
				LIBRARY_SEARCH_PATHS = "$(PROJECT_DIR)/AppShow/Libraries/gifski";
				OTHER_LDFLAGS = "-lgifski";
				SWIFT_INCLUDE_PATHS = "$(PROJECT_DIR)/AppShow/Libraries/gifski";
```

`AppShow/Libraries/gifski/module.modulemap` declares `module gifski { header "gifski.h" export * }`; `libgifski.a` is a fat `x86_64 arm64` archive. Implications:

- **Do not** add `-lgifski` to the test bundle. `gifski_new`/`gifski_add_frame_rgba`/`gifski_finish` are already in the host executable and resolve through `-bundle_loader`. Linking twice gives duplicate-symbol errors.
- **Do** add `SWIFT_INCLUDE_PATHS` to the test bundle. `AppShow.swiftmodule` records `import gifski` (from `AppShow/Compositor/VideoCompositor+GIFExport.swift`), and the compiler deserializing that module for `@testable import AppShow` must be able to find the clang module, otherwise: `missing required module 'gifski'`.
- Tests never `import gifski` themselves.

### 3.4 SPM products and Sparkle

`swift-log`, `MenuBarExtraAccess`, `RNNoise`, `WhisperKit` (and its transitive `swift-transformers`, `yyjson`, …) are static SwiftPM products compiled into the app binary. Sparkle 2.9.0 is a dynamic `Sparkle.framework` embedded in `AppShow.app/Contents/Frameworks`. Consequences:

- The test bundle must not declare those package products as dependencies; symbols and Objective-C classes come from the host. If test code needs a type from a package (it should not — go through AppShow's own types), expect "class X is implemented in both" warnings.
- The compiler must find `Logging.swiftmodule`, `WhisperKit.swiftmodule`, etc. when importing AppShow; they are in `BUILT_PRODUCTS_DIR`, which is on the implicit search path because the test target depends on the app target. If a `missing required module` error names a package, add the product to the test target's dependencies without linking (or extend `SWIFT_INCLUDE_PATHS`).
- `LD_RUNPATH_SEARCH_PATHS` above includes `@loader_path/../Frameworks` so `Sparkle.framework` resolves from the host bundle when the `.xctest` is loaded.

### 3.5 What the host does when it launches, and the guard

With the working tree as it is (ADR 0004 applied):

| Step | Code | Effect in a test run | Mitigation |
| --- | --- | --- | --- |
| `LogBootstrap.configure()` | `AppShow/AppShowApp.swift:10` | Fine, once. A test calling it again crashes (`LoggingSystem.bootstrap` precondition) | Never bootstrap in tests |
| `MenuBarExtra` scene | `AppShowApp.body` | Status item appears in the menu bar for the duration of the run | Accept |
| `SessionState()` | `AppDelegate.session` → `ConfigService.shared`, `RecordingOptions()` | Creates `~/.reframed/`, reads `reframed.json`; enumerates capture devices only if a device id is saved | S2 (`APPSHOW_HOME`) |
| `SparkleUpdater.shared` | `AppShow/Utilities/SparkleUpdater.swift` | `SPUStandardUpdaterController(startingUpdater: true)` still starts the updater; automatic checks are now off (`automaticallyChecksForUpdates = false`, `SUEnableAutomaticChecks` false), so no network on launch, but Sparkle writes `SUHasLaunchedBefore`/`SUEnableAutomaticChecks` into the `eu.jkuri.reframed` defaults domain shared with any installed copy, and per ADR 0004 can show an "updater error" alert ~1 s after launch if it rejects the ad-hoc-signed bundle | S1 guard |
| `ConfigService.shared.applyAppearance()` | `ConfigService.swift:101` | `NSApp.appearance` — harmless | S1 guard |
| `KeyboardShortcutManager.start()` | `KeyboardShortcutManager.swift:28` | `CGEvent.tapCreate(.cgSessionEventTap, .headInsertEventTap, .defaultTap, keyDown)`. Without Accessibility trust it returns `nil` silently (CI). On a developer Mac the first launch of each new ad-hoc-signed build can raise the Input Monitoring / Accessibility TCC attribution because ad-hoc signatures are identified by `cdhash`, which changes every build | S1 guard |
| `Permissions.allPermissionsGranted` | `Permissions.swift:24` | `CGPreflightScreenCaptureAccess()` and `AXIsProcessTrusted()` do **not** prompt. They are false on CI and on any machine that has not granted the fresh cdhash, so `showPermissionsWindow()` runs: an 800×500 `.floating` window, `NSApp.activate(ignoringOtherApps: true)` (steals focus from whatever the developer is doing), and `PermissionsView`'s 1 s `Timer` polling | S1 guard |
| `NSEvent.addLocalMonitorForEvents(.leftMouseDown)` | `AppDelegate.swift:21` | Harmless | S1 guard |

**Answer to "will the launch sequence interfere?"** Yes — not by crashing, but by (a) touching the developer's real `~/.reframed` config and the real `eu.jkuri.reframed` defaults domain, (b) starting Sparkle's updater in an ad-hoc-signed bundle, (c) attempting a session-level keyboard event tap, and (d) on every machine without Screen Recording + Accessibility granted to this exact build (all CI runners, and developer Macs after every rebuild under ad-hoc signing) popping a focus-stealing permissions window. The fix is S1 (`LaunchEnvironment.isTestHost` guard, first line of `applicationDidFinishLaunching`) plus S2 (`APPSHOW_HOME`/`APPSHOW_TMP` redirected to a temp directory), wired through the scheme:

```xml
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "NO"
      shouldAutocreateTestPlan = "YES">
      <Testables>
         <TestableReference skipped = "NO" parallelizable = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "7E57000000000000000000000A"
               BuildableName = "AppShowTests.xctest"
               BlueprintName = "AppShowTests"
               ReferencedContainer = "container:AppShow.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
      <EnvironmentVariables>
         <EnvironmentVariable key = "APPSHOW_TEST_HOST" value = "1" isEnabled = "YES"/>
         <EnvironmentVariable key = "APPSHOW_HOME" value = "/tmp/reframed-tests/home" isEnabled = "YES"/>
         <EnvironmentVariable key = "APPSHOW_TMP" value = "/tmp/reframed-tests/tmp" isEnabled = "YES"/>
      </EnvironmentVariables>
   </TestAction>
```

`shouldUseLaunchSchemeArgsEnv = "NO"` keeps these out of `make dev`. `parallelizable = "NO"` stops xcodebuild from cloning the host app; Swift Testing still parallelizes *inside* the one process.

### 3.6 Code signing, hardened runtime, entitlements

Current state (working tree): the pbxproj no longer sets `CODE_SIGN_IDENTITY`/`CODE_SIGN_STYLE`/`DEVELOPMENT_TEAM`; `Config.xcconfig` (the `baseConfigurationReference` of the app target) sets:

```
CODE_SIGN_STYLE = Manual
CODE_SIGN_IDENTITY = -
DEVELOPMENT_TEAM =

#include? "Local.xcconfig"
```

The app target keeps `ENABLE_HARDENED_RUNTIME = YES`, `RUNTIME_EXCEPTION_ALLOW_JIT = YES`, `RUNTIME_EXCEPTION_DISABLE_LIBRARY_VALIDATION = NO`, `CODE_SIGN_ENTITLEMENTS = AppShow/AppShow.entitlements` (sandbox off, `device.audio-input`, `device.camera`).

- **Host and bundle must be signed alike.** Give the test target the same `baseConfigurationReference = Config.xcconfig`. A `Local.xcconfig` with a real team then signs both; without it both are ad-hoc. An ad-hoc host with an Apple-Development bundle (or vice versa) fails library validation ("mapping process and mapped file have different Team IDs").
- **Hardened runtime + test injection.** The test action relies on Xcode injecting `com.apple.security.get-task-allow` into the host's Debug entitlements (`CODE_SIGN_INJECT_BASE_ENTITLEMENTS`, default YES), which also permits the `DYLD_INSERT_LIBRARIES`-based `libXCTestBundleInject.dylib`. Xcode has handled hardened-runtime test hosts since Xcode 10. If `make test` ever fails with `code signature … not valid for use in process using Library Validation`, the fallback is `ENABLE_HARDENED_RUNTIME=NO` on the `xcodebuild test` line only (it forces a rebuild flip-flop against `make build`, so only use it if needed and record it in ADR 0006).
- **Entitlements.** The host keeps `AppShow.entitlements`; the test bundle needs none. Nothing in a unit test should need the camera/mic entitlements.
- **TCC with ad-hoc signing.** Grants are keyed on the cdhash, so every rebuild is a "new app" to TCC. This is one more reason no test may depend on a permission.

### 3.7 Swift 6 strict concurrency in tests

`SWIFT_VERSION = 6.0` applies to the test target too (set it explicitly). Practical rules:

- Tests that touch `@MainActor` types (`History`, `EditorState`, `ConfigService`, `StateService`, `SyncedPlayerController`, `AudioWaveformGenerator`) are declared `@MainActor` (`@MainActor struct HistoryTests { @Test func … }` or `@MainActor final class … : XCTestCase`). Swift Testing runs tests on arbitrary threads; the annotation hops correctly.
- Shared fixtures must be `Sendable`: structs (`EditorStateData`, `ExportConfiguration`, `CursorMetadataFile`), `@unchecked Sendable` classes (`ZoomTimeline`, `CompositionInstruction`, `CursorMetadataSnapshot`). Build `NSImage`, `AVPlayer`, `CVPixelBuffer` inside the test body.
- `CVPixelBuffer` is not `Sendable`; keep golden-frame rendering synchronous inside one test function (`FrameRenderer.renderFrame` is synchronous).
- Suites that write to a shared location (S2 temp home, `/tmp/AppShow` until S4) use `@Suite(.serialized)` and a per-test `FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)`.
- Never `LogBootstrap.configure()`; `Logger(label:)` instances in production code are fine without it.

### 3.8 Swift Testing vs XCTest

**Use Swift Testing for all new unit tests; keep XCTest available in the same target for the two things it still does better.**

Rationale: Xcode 26.6 / Swift 6.3 ship it natively; `#expect` prints both sides of a failed comparison (invaluable for `CGRect`/`CMTime`/JSON assertions); `@Test(arguments:)` turns the many value tables here (`ExportPreset`, `GradientPresets`, `ExportFPS`, `KeyboardShortcut.keyName`, `CaptionLanguage`) into one test each; `.enabled(if:)` replaces `XCTSkip` for the env-gated export test; `.serialized` and `.timeLimit` are traits, not runner flags; async tests are first-class for `EditorState.setup()`/`AVURLAsset.load`; and parallel-by-default keeps a growing T1 suite fast. XCTest stays for `measure {}` performance baselines (e.g. `CursorSmoothing.smooth` on 10 k samples, `parallelRenderExport`) and for any future UI test target. `.swift-format` already allows `XCTAssertNoThrow` in `noAssignmentInExpressions`, so upstream's formatter config does not fight either framework.

### 3.9 A `AppShowCore` package later — not now

**Pros.** `swift test` in seconds with no host launch, no signing, no TCC, no Sparkle; a compile-time boundary that stops UI code from reaching into compositor logic; tests could run on Linux for pure Foundation pieces (few). **Cons.** The T1 set is not import-clean: `GradientPresets.swift` imports SwiftUI (`Color`, `UnitPoint`), `ProjectMetadata.swift` imports AppKit/CoreText/SwiftUI (`CaptionLayout.measureText`, `CaptionFontWeight.swiftUIWeight`), `KeyboardShortcut.swift` imports AppKit (`NSEvent`), `History.swift` is `@MainActor @Observable`; moving them means splitting files, widening ~100 declarations to `public`, and diverging from upstream on exactly the files upstream edits most (every merge becomes a rename-conflict). **Decision:** stay hosted (ADR 0006) until the hosted loop is measurably too slow or milestone 01 has pinned enough behavior that a move is mechanical. When it happens, move only files whose imports are `Foundation`/`CoreGraphics`/`CoreMedia`/`AVFoundation` value types, keep folder names, and do it in one commit right after an upstream sync.

---

## 4. `xcodebuild test` and the Makefile

> **As landed (2026-09-03).** xcodebuild passes scheme `EnvironmentVariable` values literally; neither shell variables nor build-setting macros such as `$(TMPDIR)` or `$(BUILT_PRODUCTS_DIR)` are expanded, so the scheme uses the literal paths above. Object ids in the pbxproj are 24 hex characters (`7E5700000000000000000001`); the ids in the snippets of this section are illustrative. Seam S2 landed as one-line path swaps through `AppShowPaths` in `ConfigService`, `StateService`, and `FileManager+AppShow`; the `init(fileURL:)` initializer is still to be added when a `ConfigService` test needs it. The `Makefile` `test` target as shipped is shown next; `test-export` and `coverage` are not added until something gated exists.

```make
TEST_TARGET = AppShowTests
TEST_FILTER = $(if $(T),-only-testing:'$(TEST_TARGET)/$(T)',-only-testing:$(TEST_TARGET))
TEST_OUTPUT_FILTER = ^(◇|✔|✘|Test Suite|\*\* )|Executed|: error:|: warning:|failed

test:
	@set -o pipefail; xcodebuild -project AppShow.xcodeproj -scheme $(SCHEME) -configuration Debug test -derivedDataPath $(BUILD_DIR) -destination '$(DESTINATION)' -parallel-testing-enabled NO $(TEST_FILTER) 2>&1 | grep -E '$(TEST_OUTPUT_FILTER)'
```

Original proposal follows for reference (variables follow the existing ones; `xcbeautify` is optional):

```make
TEST_TARGET = AppShowTests
RESULT_BUNDLE = $(BUILD_DIR)/TestResults.xcresult
PRETTY = $(shell command -v xcbeautify >/dev/null 2>&1 && echo "xcbeautify" || echo "cat")
TEST_FILTER = $(if $(T),-only-testing:'$(TEST_TARGET)/$(T)',-only-testing:$(TEST_TARGET))

test:
	@rm -rf $(RESULT_BUNDLE)
	@set -o pipefail; xcodebuild -project AppShow.xcodeproj -scheme $(SCHEME) -configuration Debug test \
		-derivedDataPath $(BUILD_DIR) -destination '$(DESTINATION)' \
		-parallel-testing-enabled NO -resultBundlePath $(RESULT_BUNDLE) $(TEST_FILTER) 2>&1 | $(PRETTY)

test-export:
	@TEST_RUNNER_APPSHOW_RUN_EXPORT_TESTS=1 $(MAKE) test T=ExportPipelineTests

coverage:
	@$(MAKE) test T= EXTRA="-enableCodeCoverage YES"
	@xcrun xccov view --report --only-targets $(RESULT_BUNDLE)
```

Notes:

- Same `-derivedDataPath .build` and `Debug` configuration as `make build`, so `make build && make test` shares one incremental build.
- Do not pass `-quiet`; it hides test names and failures. `xcbeautify` (Homebrew) condenses output when present.
- Environment for the test host: xcodebuild forwards only variables prefixed `TEST_RUNNER_` (prefix stripped). Hence `TEST_RUNNER_APPSHOW_RUN_EXPORT_TESTS=1` and, if you want to override the scheme's `APPSHOW_HOME`, `TEST_RUNNER_APPSHOW_HOME=…`.
- Add `test`, `test-export`, `coverage` to `.PHONY`; `format`/`lint` already include `$(wildcard AppShowTests)`.

**Single test / suite** (Swift Testing identifiers use the suite type name and the function name with parentheses):

```bash
make test T=ZoomTimelineTests                                   # one suite
make test T='ZoomTimelineTests/interpolatesInInverseZoomSpace()' # one test
make test T=ProjectMetadataTests/decodesVersion1ProjectWithDefaults\(\)
xcodebuild ... test -only-testing:'AppShowTests/HistoryTests'   # raw form
```

XCTest classes use `AppShowTests/ClassName/testMethod` without parentheses.

---

## Gated suites

`ExportPipelineTests` runs only with `TEST_RUNNER_APPSHOW_RUN_EXPORT_TESTS=1`; `ExternalAudioPreviewEngineTests` only with `TEST_RUNNER_APPSHOW_RUN_AUDIO_ENGINE_TESTS=1`. Both need no permissions but take seconds and touch real AVFoundation encoders and the audio engine.

## 5. First fifteen tests

> All fifteen landed 2026-09-04 (milestone 01) plus the audio-mix pairing characterization. Where the code disagreed with the rows below, the tests pin the code: the legacy document cannot both lack `captionSettings` and carry `captionPosition` (both variants are tested); `rename` sanitizes with `CharacterSet.alphanumerics`, not ASCII; row 6's `scaleX` border scaling holds only on the cut path (the trim path leaves `borderWidth` unscaled, a likely upstream bug); row 14's solid red background renders colour-matched as `(255, 38, 0)` through the 8-bit Generic RGB path, so golden tests assert dominance and derive blends from the measured background; row 9's equal-time keyframes resolve to the first at the very first time; row 10's hold keyframe is not clamped to the duration; row 13's "nil once the next segment has started" branch is unreachable. `FrameRenderer.visibleText` crashes for `time < segment.startSeconds` with more than two lines and loops forever for `maxWordsPerLine <= 0`; both are unreachable from `drawCaptions` today and are left untested.

Ordered by (a) whether a bug would corrupt a user's `.frm` or export and (b) whether the code is about to be touched. Files are `AppShowTests/<Suite>.swift`.

| # | Target | File under test | Asserts | Tier | Why first |
| --- | --- | --- | --- | --- | --- |
| 1 | `ProjectMetadata` legacy decode | `AppShow/Project/ProjectMetadata.swift` (lenient `init(from:)` extensions, `CaptionPosition.init(from:)`) | A hand-written v1 `project.json` lacking `hasCursorMetadata`, `isHDR`, `zoomEnabled`, `captionSettings`, with `captionPosition: "top"` and `captureMode` absent, decodes; defaults equal the declared ones; unknown `backgroundStyle.type` → `.none` | T1 | The exact failure mode is "old project will not open". Pins compatibility before anyone adds a field |
| 2 | `EditorStateData` ↔ `ProjectMetadata` round trip | same | Encode with `.iso8601`/`.sortedKeys` exactly as `AppShowProject.saveEditorState`, decode, compare every field including `cameraRegions` with `customLayout`, `zoomSettings.keyframes`, `captionSegments.words`, `spotlightRegions.fadeDuration` | T1 | Any asymmetric `CodingKeys`/optional handling silently drops user edits |
| 3 | `History` | `AppShow/Editor/History.swift` | `pushSnapshot` after `undo` truncates redo; cap at 50 keeps the newest and shifts `currentIndex`; `load(from:)` clamps out-of-range `currentIndex`; `HistoryData` JSON round trip | T1 (`@MainActor`) | `history.json` is user data; off-by-one here loses undo stacks |
| 4 | `AppShowProject` bundle lifecycle | `AppShow/Project/AppShowProject.swift` | `create` moves screen/webcam/audio/cursor files into `<prefix>-<ts>.frm`, writes `project.json`; `open` restores metadata and prefers `screen.mov`; `saveEditorState` then `open` returns the state; `rename` sanitizes to `[A-Za-z0-9 -_]` and moves the bundle; `open` throws `CaptureError.recordingFailed` when `screen.*` missing | T2 (temp dir; note S4) | This is the on-disk contract of the product |
| 5 | `remapAllRegions`, trim path | `AppShow/Compositor/VideoCompositor+RegionRemapping.swift` | Region [2,8] with trim [5,10] → [0,3]; region entirely before trim → dropped; caption word times clipped and shifted; spotlight region shifted with a fresh copy | T1 | Wrong remap = webcam/captions appear at the wrong time in every trimmed export |
| 6 | `remapAllRegions`, video-cut path | same | Two `VideoSegment`s [0,2]→0 and [5,7]→2: a camera region [1,6] splits into [1,2] and [2,3]; `remapVideoRegions` only keeps regions matching a segment within 0.01 s; `borderWidth` scaled by `scaleX` for custom regions | T1 | The cut path is the newest and least exercised branch |
| 7 | `CompositionInstruction.sourceTime(for:)` + `resolveZoomRect` | `AppShow/Compositor/CompositionInstruction.swift`, `FrameRenderer+Helpers.swift` | With mappings: composition 2.5 s → source 5.5 s; outside all mappings → `t + trimStartSeconds`; `resolveZoomRect` uses source time and applies `followCursor` only when zoomed | T1 | Cursor/zoom drift after cuts is a visible export bug |
| 8 | Canvas/render size and passthrough decision | `AppShow/Compositor/VideoCompositor+InstructionBuilder.swift` | `computeCanvasSize` for each `CanvasAspect` and for padding 0.1 (×1.2); `computeRenderSize` keeps aspect and rounds height; `checkNeedsCompositor` is `false` for standard capture + default `ExportSettings` (h265/original/original) and `true` for any single effect, webcam, cursor, GIF, captions | T1 | Deciding passthrough wrongly either re-encodes needlessly or drops effects |
| 9 | `ZoomTimeline` | `AppShow/Editor/ZoomTimeline.swift` | Before first / after last keyframe → that keyframe's rect; midpoint between zoom 1 and 2 interpolates in inverse space (`t=0.5` → zoom 4/3, width 0.75); `zoomLevel ≤ 1` → unit rect; equal-time keyframes → later one; `followCursor` keeps origin within `[0, 1−w]` and returns the input when unzoomed | T1 | Pins the easing before anyone "fixes" the curve; feeds preview and export |
| 10 | `ZoomDetector` + `groupZoomRegions` | `AppShow/Editor/ZoomDetector.swift`, `ZoomRegion.swift` | Two clicks 0.2 s apart with dwell 0.5 → one region → four keyframes (1, z, z, 1) sorted, clamped to `[0, duration]`, `isAuto == true`; clicks outside duration ignored; `groupZoomRegions` returns one region with `count == 4` and correct `peakZoom` | T1 | Auto-zoom generates user-visible keyframes stored in `project.json` |
| 11 | `CursorSmoothing.smooth` invariants | `AppShow/Editor/CursorSmoothing.swift` | Output count and timestamps equal input; first sample untouched; `< 2` samples returned verbatim; a click at `t` snaps the output sample at the next timestamp to the click position; `dt ≥ 1 s` resets to the target; `.rapid` converges closer than `.slow` after 100 ms | T1 | Spring math with no tests is the most likely place for an NaN/blow-up regression |
| 12 | Export tables | `AppShow/Compositor/ExportSettings.swift`, `AppShow/Utilities/EncodingSettings.swift` | Parametrized over `ExportPreset.allCases`: each preset's `format/fps/resolution/codec/audioBitrate` as coded today; `ExportFPS.value(fallback: 60)`; `exportVideoSettings` HEVC bitrate = pixels×5 (×7 HDR), H.264 pixels×7, ProRes has no compression properties, HDR omits `AVVideoColorPropertiesKey` | T1 | Users pick presets by name; changing one silently is a regression |
| 13 | Caption timing | `AppShow/Compositor/FrameRenderer+Captions.swift`, `AppShow/Utilities/TranscriptionService.swift` (S7) | `captionSegmentAt` returns the active segment, lingers ≤ 1.5 s after the previous one, and returns nil once the next segment has started; `visibleText` splits at `maxWordsPerLine` and windows two lines by time; `mergeShortSegments` merges a 2-word segment into a 3-word predecessor within 1.5 s but not past 16 words | T1 / T2 | Burn-in captions are a recent feature with dense edge cases |
| 14 | Golden frame | `AppShow/Compositor/FrameRenderer.swift` | 64×36 BGRA buffers: green screen buffer, instruction with solid red background, `paddingH/V = 8`, `videoCornerRadius = 0` → pixel (1,1) is red, centre is green (BGRA byte order `B,G,R,A`); with `videoCornerRadius = 12` the video-rect corner pixel is red; a `.fade` `screenTransition` at progress 0.5 gives centre ≈ 50 % blend within ±3/255 | T2 (in-memory buffers) | The rendering contract for every export path, with zero fixtures |
| 15 | `SharedRecordingClock` | `AppShow/Recording/SharedRecordingClock.swift` | `referenceTimeSeconds` nil until `streamCount` streams register; reference = max of first PTS; `adjustPTS` returns nil before reference / when negative; subtracting a pause offset shifts by exactly that amount | T1 | A/V desync corrupts recordings at the source, and `AudioTrackWriter` was just rewritten (`8c67fff`) |

Runners-up in order: `TimeFormatting` (all 8 functions), `CodableColor`, `KeyboardShortcut`/`ShortcutAction.defaultShortcut`, `CursorMetadataProvider` interpolation and binary search edges, `CursorLoopTelemetry`, `SubtitleExporter` output text, `GradientPresets` id/index invariant, `CameraLayout.pixelRect`, `VideoTrackWriter` with synthetic frames (T2), `ConfigService` merge-over-defaults (after S2), `EditorState` region operations on the 2 s fixture (T2), and the env-gated `ExportPipelineTests` end-to-end MP4 (T2, `planning/tdd-strategy.md`).
