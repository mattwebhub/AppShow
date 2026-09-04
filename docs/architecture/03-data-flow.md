# 03 — End-to-End Data Flows

Three traces through the code, written as `Type.method → Type.method` chains with file paths. Line numbers are from `v0.14.7` and are approximate.

## State machine, as implemented

`CaptureState` (`AppShow/State/CaptureState.swift`):

```swift
enum CaptureState: Sendable, Equatable {
  case idle
  case selecting
  case countdown(remaining: Int)      // declared, never entered — see below
  case recording(startedAt: Date)
  case paused(elapsed: TimeInterval)
  case processing
  case editing
}
```

Every mutation goes through `SessionState.transition(to:)` (`AppShow/State/SessionState.swift:57`), which also fires side effects. The complete set of `transition(to:)` call sites:

| From | To | Trigger | Call site |
| --- | --- | --- | --- |
| `.idle` | `.selecting` | `selectMode(.selectedArea)` → `beginSelection()`; `selectMode(.selectedWindow)` → `startWindowSelection()` | `AppShow/State/SessionState+Selection.swift:39,57` |
| `.selecting` | `.idle` | `cancelSelection()` (Esc, overlay cancel, device preview cancel) | `SessionState+Selection.swift:118` |
| `.selecting` / `.idle` / `.countdown` | `.recording(startedAt:)` | `startRecording()` after `RecordingCoordinator.startRecording` returns; also `startDeviceRecordingInternal` | `SessionState+Recording.swift:95,132` |
| any | `.idle` | `cleanupAfterRecordingFailure()` when `startRecording()` throws | `SessionState+Recording.swift:31` |
| `.recording` | `.paused(elapsed:)` | `pauseRecording()` | `SessionState+Recording.swift:201` |
| `.paused` | `.recording(startedAt: now − elapsed)` | `resumeRecording()` | `SessionState+Recording.swift:212` |
| `.recording` / `.paused` | `.processing` | `stopRecording()` (status-item click, toolbar, global shortcut, stream error, captured window disappeared) | `SessionState+Recording.swift:149` |
| `.processing` | `.idle` | `stopRecording()` when `stopRecordingRaw()` returns `nil` (no video written) | `SessionState+Recording.swift:161` |
| `.processing` | `.editing` | `openEditor(project:result:)` | `AppShow/State/SessionState+Project.swift:25` |
| `.recording`/`.paused`/`.countdown` | `.idle` | `restartRecording()` (discards, then immediately re-enters the countdown UI) | `SessionState+Recording.swift:243` |
| `.editing` | `.idle` | `removeEditor(_:)` when `editorWindows` becomes empty | `SessionState+Project.swift:73` |
| `.idle` | `.editing` | `openProject(at:)` (double-click `.appshow` or legacy `.frm`, menu bar recent list) → `openEditor` | `SessionState+Project.swift:25` |

**`.countdown` is unreachable.** `grep -rn "\.countdown(remaining" AppShow` only finds `case` patterns. The countdown is implemented as a SwiftUI timer inside `StartRecordingButton` (`AppShow/UI/StartRecordingButton.swift`), embedded in `CaptureAreaView`, `StartRecordingOverlayView`, `WindowSelectionView` and `DevicePreviewWindow`; only when it finishes does the view call `session.confirmSelection(_:)` / `startRecordingFromOverlay` / `startDeviceRecording`. During those seconds `state` is `.selecting` (area, window) or `.idle` (entire screen — `selectMode(.entireScreen)` never transitions). Effects: `MenuBarIcon.State.countdown` is never shown; the `CGEventTap` global shortcuts in `KeyboardShortcutManager` (gated on `.countdown/.recording/.paused`) do not work during a countdown; `restartRecording`'s `.countdown` branch is dead.

Side effects wired into `transition(to:)` (`SessionState.swift:57-85`): on `.recording` start the 100 ms audio-level polling task, start `WindowPositionObserver` for window targets, hide the webcam preview if configured, show the toolbar, and raise the captured window via AX; on `.paused` un-hide the preview; on anything else stop polling and tracking. `updateStatusIcon()` runs on every transition and starts the 0.6 s pulse timer while `.processing` or while any editor `isExporting`.

---

## Flow A — Area recording, from click to editor

Actors involved: `@MainActor` (`SessionState`, overlays) → `RecordingCoordinator` (actor) → writer queues → back to `@MainActor`.

### A.1 Selecting the area

1. `CaptureToolbar+ModeSelection` (`AppShow/UI/CaptureToolbar+ModeSelection.swift`) or `MenuBarView` calls **`SessionState.selectMode(.selectedArea)`** (`AppShow/State/SessionState+Selection.swift:7`).
2. `selectMode` → `hideToolbar()` → **`beginSelection()`** (`:42`): guards `state == .idle` and `Permissions.hasScreenRecordingPermission` (else `CGRequestScreenCaptureAccess()` and throws `.permissionDenied`), then `transition(to: .selecting)`, `captureTarget = nil`.
3. `beginSelection` creates **`SelectionCoordinator()`** and calls `coordinator.beginSelection(session: self)` (`AppShow/CaptureModes/Common/SelectionCoordinator.swift:8`): one `SelectionOverlayWindow(screen:session:)` per `NSScreen`, `.screenSaver` level, first one made key, `NSApp.activate`.
4. If `options.rememberLastSelection` and `StateService.shared.lastSelectionRect` exists → `coordinator.restoreSelection(_:displayID:session:)` → `SelectionOverlayView.applyExternalRect(_:)` and `session.overlayView = overlayView`; `captureTarget` is pre-set to `.region(SelectionRect(...))`.
5. User drags; `SelectionOverlayView` (+ `+Resize`, `+Drawing`) maintains `selectionRect` in view coordinates; `updateControlsPanel()` (`SelectionOverlayView+Controls.swift:31`) hosts a `CaptureAreaView` (SwiftUI) under the rect containing the `StartRecordingButton` with the countdown and the size-presets popover.
6. When the countdown completes, **`SelectionOverlayView.confirmSelection()`** (`+Controls.swift:11`) converts view → window → screen coordinates (`window.convertToScreen`), finds the display whose frame contains the midpoint, and builds `SelectionRect(rect: screenRect, displayID:)` (AppKit bottom-left coordinates; `SelectionRect.init` captures `displayOrigin` and `displayHeight` from `NSScreen.screen(for:)`).
7. **`SessionState.confirmSelection(_:)`** (`SessionState+Selection.swift:68`): `selectionCoordinator?.destroyOverlay()`, `showRecordingBorder(screenRect:)` (a `RecordingBorderWindow`, `.floating`, click-through), `captureTarget = .region(selection)`, persist rect + display in `StateService`, then **`beginRecordingWithCountdown()`**.

### A.2 Starting the capture

8. `beginRecordingWithCountdown()` (`SessionState+Recording.swift:8`) is `Task { try await startRecording() }` with failure → `cleanupAfterRecordingFailure()` + `showError`.
9. **`SessionState.startRecording()`** (`:26`):
   - guard state ∈ {`.selecting`, `.idle`, `.countdown`}; guard `captureTarget` (else `.noSelectionStored`).
   - `let coordinator = RecordingCoordinator()` — **a fresh actor per recording**; install `setStreamErrorHandler` / `setDeviceLostHandler` closures that hop back with `Task { @MainActor in … }`.
   - `let metadataRecorder = CursorMetadataRecorder()`; `SoundEffect.startRecording.play()`.
   - `await coordinator.startRecording(target:fps:captureSystemAudio:microphoneDeviceId:cameraDeviceId:cameraResolution:existingWebcam:cursorMetadataRecorder:captureQuality:retinaCapture:hdrCapture:)`, pulling every option from `options` (`RecordingOptions`) and `ConfigService.shared.cameraMaximumResolution`, and passing `attachExistingWebcam()` (the already-running preview `WebcamCapture`, if the camera toggle is on).
10. **`RecordingCoordinator.startRecording`** (`AppShow/Recording/RecordingCoordinator+Screen.swift:9`), in order:
    1. Webcam: reuse `existingWebcam` or `WebcamCapture().startAndVerify(deviceId:fps:maxWidth:maxHeight:)` (waits for first frame, 3 s timeout).
    2. Mic: `MicrophoneCapture().startAndVerify(deviceId:)` (5 s timeout). Any failure stops what was started and rethrows.
    3. `Permissions.fetchShareableContent()` → find `SCDisplay` with `displayID == target.displayID` (else `.displayNotFound`).
    4. `displayScale` from `CGDisplayCopyDisplayMode(pixelWidth / width)`; `sourceRect = selection.screenCaptureKitRect` (**the Y-flip**: `localQuartzY = displayHeight − localAppKitY − h`, `AppShow/CaptureModes/Common/SelectionRect.swift:17`); `pixelW/H = round(sourceRect × scale) & ~1`, doubled if `retinaCapture`.
    5. `streamCount = 1 + [mic] + [systemAudio] + [webcam]` → **`SharedRecordingClock(streamCount:)`**.
    6. **`VideoTrackWriter(outputURL: FileManager.tempVideoURL(captureQuality:), width:height:fps:clock:captureQuality:isHDR:)`** — `AVAssetWriter` (`.mp4`, or `.mov` for ProRes) with `EncodingSettings.captureVideoSettings`; for HDR the input is created lazily with a `sourceFormatHint` on the first sample.
    7. `cursorMetadataRecorder.configure(captureOrigin: sckRect.origin, captureSize:, displayScale:, displayHeight: CGDisplayPixelsHigh)`.
    8. **`ScreenCaptureSession(videoWriter:captureQuality:hdrCapture:)`** then `session.start(target:display:displayScale:fps:hideCursor: recorder != nil, retinaCapture:, excludedApps: [self app])` (`AppShow/Recording/ScreenCaptureSession.swift:29`): `SCContentFilter(display:excludingApplications:exceptingWindows:)`, `SCStreamConfiguration` with `sourceRect`, `width/height`, `minimumFrameInterval = 1/(fps×1.2)`, pixel format `420YpCbCr10BiPlanarFullRange` (or `32BGRA` for ProRes, `…VideoRange` + `hdrLocalDisplay` for HDR), `showsCursor = !hideCursor`, `queueDepth = 8`; `stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: videoWriter.queue)`; `try await stream.startCapture()`.
    9. Webcam writer: `VideoTrackWriter(... isWebcam: true)`, `cam.attachWriter(camWriter)` (re-points the `AVCaptureVideoDataOutput` delegate queue to `camWriter.queue`), `cam.onDisconnected → handleDeviceLost("camera")`.
    10. Mic writer: `AudioTrackWriter(outputURL: tempAudioURL(label: "mic"), label:sampleRate:channelCount:clock:)`; `mic.attachWriter`.
    11. System audio: `AudioTrackWriter(label: "sysaudio", 48 kHz stereo)` + **`SystemAudioCapture(audioWriter:)`.`start(display:)`** (second `SCStream`, `capturesAudio = true`, `excludesCurrentProcessAudio = true`, 2×2 px video discarded).
    12. `systemAudioWriter?.setVideoPTSProvider { vidWriter.lastWrittenPTS }`, same for mic (drift correction input).
    13. `return Date()` → becomes `startedAt`.
11. Back in `SessionState.startRecording`: `metadataRecorder.start()` (8 ms `DispatchSourceTimer` sampling `NSEvent.mouseLocation`); `showCameraPreviewIfNeeded(from: await coordinator.getWebcamCaptureSessionBox())` (the `SendableBox<AVCaptureSession>` hop); `MouseClickMonitor(metadataRecorder:).start()` (global `NSEvent` monitors for clicks and keystrokes); `await startRecordingPreview(coordinator:)` if `options.showRecordingPreview` (installs `setPreviewFrameHandler` → `RecordingPreviewWindow.updateFrame`); finally **`transition(to: .recording(startedAt:))`**.

### A.2b The same start sequence as a diagram

```mermaid
sequenceDiagram
    autonumber
    participant V as SelectionOverlayView (main)
    participant S as SessionState (main)
    participant C as RecordingCoordinator (actor)
    participant W as WebcamCapture / MicrophoneCapture
    participant K as SharedRecordingClock
    participant SC as ScreenCaptureSession + SCStream
    participant VW as VideoTrackWriter.queue
    participant R as CursorMetadataRecorder
    V->>S: confirmSelection(SelectionRect)
    S->>S: showRecordingBorder, captureTarget = .region, StateService.lastSelectionRect
    S->>S: beginRecordingWithCountdown → Task { startRecording() }
    S->>C: RecordingCoordinator() ; setStreamErrorHandler / setDeviceLostHandler
    S->>C: await startRecording(target, fps, audio flags, device ids, existingWebcam, recorder, quality, retina, hdr)
    C->>W: startAndVerify(...)  (continuation + 3–5 s timeout)
    W-->>C: VerifiedCamera / ok
    C->>C: Permissions.fetchShareableContent → SCDisplay, displayScale, sourceRect (Y-flipped), pixelW/H
    C->>K: SharedRecordingClock(streamCount)
    C->>VW: VideoTrackWriter(tempVideoURL, w, h, fps, clock)
    C->>R: configure(captureOrigin, captureSize, displayScale, displayHeight)
    C->>SC: ScreenCaptureSession(videoWriter).start(...)  → SCStream.startCapture()
    C->>W: attachWriter(webcam VideoTrackWriter) / attachWriter(mic AudioTrackWriter)
    C->>C: SystemAudioCapture(audioWriter).start(display)
    C->>C: audio writers .setVideoPTSProvider { vidWriter.lastWrittenPTS }
    C-->>S: startedAt: Date
    S->>R: start()  (8 ms timer)
    S->>C: await getWebcamCaptureSessionBox()
    C-->>S: SendableBox<AVCaptureSession>?
    S->>S: showCameraPreviewIfNeeded, MouseClickMonitor.start, startRecordingPreview
    S->>S: transition(to: .recording(startedAt))  → audio polling, window tracking, toolbar, status icon
    loop every frame (SCStream thread → VideoTrackWriter.queue)
        SC->>VW: appendSampleBuffer(sb)
        VW->>K: registerStream(firstPTS) once; adjustPTS(raw, pauseOffset)
        VW->>VW: startSession(atSourceTime:) once; videoInput.append(retimed sb)
    end
```

### A.3 Steady state (per frame)

```
SCStream (ScreenCaptureKit thread)
  → ScreenCaptureSession.stream(_:didOutputSampleBuffer:of:)          [on videoWriter.queue]
    → handleVideoSample: read SCFrameStatus from attachments
       .complete → lastPixelBuffer = image; onPreviewFrame?(sb); videoWriter.appendSampleBuffer(sb)
       .idle     → createSampleBuffer(from: lastPixelBuffer, pts: sb.pts) → videoWriter.appendSampleBuffer
    → VideoTrackWriter.appendSampleBuffer                               [dispatchPrecondition on queue]
       if !hasRegistered → clock.registerStream(firstPTS: rawPTS)
       adjusted = clock.adjustPTS(rawPTS, pauseOffset)  (nil → drop)
       first time → assetWriter.startWriting(); startSession(atSourceTime: adjusted)
       CMSampleBufferCreateCopyWithNewTiming(pts: adjusted) → videoInput.append; lastWrittenPTS = adjusted
```

Audio is identical through `AudioTrackWriter.appendSample` on its own queue, plus peak metering (`currentPeakLevel`, decayed ×0.85) and the 100-buffer drift check. Meanwhile on `@MainActor`: `SessionState.startAudioLevelPolling()` reads `coordinator.getAudioLevels()` every 100 ms into `micAudioLevel`/`systemAudioLevel` for the toolbar; `CursorMetadataRecorder` appends `CursorSample`s (normalised 0–1 within the capture rect) under its lock.

Pause: `SessionState.pauseRecording()` → `mouseClickMonitor?.stop()`, `Task { await coordinator.pause() }`, `transition(to: .paused(elapsed:))`. `RecordingCoordinator.pause()` (`+Lifecycle.swift:6`) stamps `pauseStartTime` and `queue.async { isPaused = true }` on every source/writer.

### A.3b Stop sequence as a diagram

```mermaid
sequenceDiagram
    autonumber
    participant U as trigger (toolbar / status item / shortcut / stream error)
    participant S as SessionState (main)
    participant C as RecordingCoordinator (actor)
    participant SRC as capture sources
    participant W as track writers (own queues)
    participant R as CursorMetadataRecorder
    participant P as AppShowProject
    participant E as EditorWindow / EditorState (main)
    U->>S: stopRecording()
    S->>S: stop MouseClickMonitor, close preview, transition(.processing), cleanupCoordinators()
    S->>C: await stopRecordingRaw(keepWebcamAlive: false)
    C->>R: stop()
    C->>SRC: stop() mic / webcam / device ; await stop() system audio ; await captureSession.stop()
    par async let
        C->>W: videoWriter.finish()
        C->>W: webcamWriter.finish()
        C->>W: systemAudioWriter.finish()
        C->>W: micAudioWriter.finish()
    end
    W-->>C: URLs (nil if never started)
    C->>R: adjustTimestamps(by: cursorStart − clock.referenceTime) ; writeToFile(/tmp/…json)
    C-->>S: RecordingResult?
    alt result == nil
        S->>S: transition(.idle), showToolbar()
    else
        S->>P: AppShowProject.create(from: result, fps, captureMode, sourceName, in: projectSaveDirectory())
        P->>P: mkdir <Prefix>-<ts>.appshow ; moveItem × media ; write project.json ; cleanupTempDir()
        P-->>S: AppShowProject
        S->>E: openEditor(project:) → transition(.editing) → EditorWindow().show(project:)
        E->>E: EditorState(project:) ; NSWindow + NSHostingView(EditorView)
        E->>E: .task { await editorState.setup() } → players, default regions, cursor provider, history, startAutoSave()
    end
```

### A.4 Stopping and writing the bundle

12. Any stop trigger → **`SessionState.stopRecording()`** (`SessionState+Recording.swift:135`): guard `.recording`/`.paused`; stop `MouseClickMonitor`; drop `cursorMetadataRecorder` and `recordingPreviewWindow`; `transition(to: .processing)`; `cleanupCoordinators()` (border window gone); `let sourceName = projectSourceName()` (screen name / app name / device name).
13. `guard let result = try await recordingCoordinator?.stopRecordingRaw(keepWebcamAlive: false)` → **`RecordingCoordinator.stopRecordingRaw`** (`+Lifecycle.swift:43`):
    1. `cursorMetadataRecorder?.stop()`; `microphoneCapture?.stop()`; `webcamCapture?.stop()`; `deviceCapture?.stop()`; `await systemAudioCapture?.stop()`; `await captureSession?.stop()` (`SCStream.stopCapture()`).
    2. `async let` on all five `writer.finish()` calls → each does `markAsFinished()` + `finishWriting { continuation.resume(returning: outputURL or nil) }` on its queue.
    3. Cursor: `offset = recorder.startHostTimeSeconds − clock.referenceTimeSeconds`; if |offset| > 1 ms `recorder.adjustTimestamps(by:)`; `recorder.writeToFile(at: /tmp/…/cursor-metadata-<uuid>.json)`.
    4. Null out all writers and the clock; `guard let videoFile` else return `nil`.
    5. Return **`RecordingResult(screenVideoURL:webcamVideoURL:systemAudioURL: sys ?? deviceAudio, microphoneAudioURL:cursorMetadataURL:screenSize:webcamSize:fps:captureQuality:isHDR:)`**.
14. `SessionState.stopRecording` continues: `SoundEffect.stopRecording.play()`, release coordinator/target/device, `stopCameraPreview()`, then `saveDir = FileManager.default.projectSaveDirectory()` (`~/AppShow`, `@MainActor` because it reads `ConfigService`) and **`AppShowProject.create(from: result, fps:, captureMode:, sourceName:, in: saveDir)`** (`AppShow/Project/AppShowProject.swift:72`):
    - `bundleName = "<Prefix>-<yyyy-MM-dd-HHmmss>.appshow"` where `Prefix` is the sanitised source name or `Screen`/`Window`/`Area`/`Device`/`Recording`.
    - `createDirectory`, then **`FileManager.moveItem`** (not copy) for `screen.<mp4|mov>`, `webcam.mp4`, `system-audio.m4a`, `mic-audio.m4a`, `cursor-metadata.json`; `cleanupTempDir()`.
    - Build `ProjectMetadata(name:createdAt:fps:screenSize:webcamSize:hasSystemAudio:hasMicrophoneAudio:hasCursorMetadata:hasWebcam:captureMode:captureQuality:isHDR:)` with `editorState == nil`, encode ISO-8601/pretty/sorted → `project.json`.
    - Return `AppShowProject(bundleURL:metadata:)`.
    On failure the editor is still opened with the raw `RecordingResult` (`openEditor(project: nil, result:)`), i.e. files stay in `/tmp/AppShow`.
15. **`SessionState.openEditor(project:)`** (`SessionState+Project.swift:19`): `hideToolbar()`, `transition(to: .editing)`, `EditorWindow()` with `onSave`/`onCancel`/`onDelete`/`onExportingChanged` closures (all wrapped in `MainActor.assumeIsolated`), **`editor.show(project:)`**, append to `editorWindows`.
16. **`EditorWindow.show(project:)`** (`AppShow/Editor/EditorWindow.swift:14`) → `EditorState(project:)` (reads any saved `editorState` from `project.json`; there is none for a fresh recording) → `showWindow(state:)`: `NSHostingView(rootView: EditorView(editorState:onDelete:))` in a 1400×900-minimum `NSWindow`, frame restored from `StateService.editorWindowFrame`; `setupKeyboardMonitor()`; `observeExporting(state:)`.
17. `EditorView.body.task { await editorState.setup() }` (`AppShow/Editor/EditorView.swift:90`) → **`EditorState.setup()`** (`EditorState.swift:244`): `playerController.loadDuration()` + `computeDriftRatios()`; default one full-length `AudioRegionData` per audio track and one `VideoRegionData`; `CursorMetadataProvider.load(from: cursor-metadata.json)`; if no saved state and there is a webcam `setCameraCorner(.bottomRight)`; `history.pushSnapshot(createSnapshot())`; **`startAutoSave()`** → `observeChanges()`. The editor is now live; the first autosave (1 s later) writes `editorState` into `project.json` for the first time.

---

## Flow B — Editor property change → preview re-render

Everything here is `@MainActor`. The pattern is: a view writes a stored property of `EditorState`; `@Observable` invalidates every SwiftUI view that read it; `EditorView+Preview` rebuilds `VideoPreviewView`, whose `updateNSView` pushes the new values into the AppKit `VideoPreviewContainer` layers; separately, `EditorState.observeChanges` schedules autosave and an undo snapshot.

### B.1 Example: editing a zoom region on the timeline

1. `TimelineView` (`AppShow/Editor/TimelineView.swift`) shows a `ZoomKeyframeEditor` (`AppShow/Editor/ZoomKeyframeEditor.swift`) when `editorState.zoomEnabled`. Regions are derived from keyframes with `groupZoomRegions(from:)` (4 keyframes = one `ZoomRegion`, `AppShow/Editor/ZoomRegion.swift`).
2. Dragging a region body/edge updates `@State dragOffset`/`dragType`; `effectiveTimes(for:)` (`ZoomKeyframeEditor+Logic.swift:4`) computes clamped preview times without touching `EditorState` (so the preview follows the drag without creating undo entries).
3. On release, **`ZoomKeyframeEditor.commitDrag(for:)`** (`+Logic.swift:55`) rewrites the four `ZoomKeyframe`s and calls **`EditorState.updateZoomRegion(startIndex:count:newKeyframes:)`** (`AppShow/Editor/EditorState+Zoom.swift:93`), which does `kfs.replaceSubrange(...)` and **`zoomTimeline = ZoomTimeline(keyframes: kfs)`** — a *new instance*, because `ZoomTimeline` is an immutable-after-init class and `@Observable` only sees the property assignment.
4. **Observation fan-out** (synchronous, same run-loop turn):
   - `EditorView+Preview.videoPreview` (`AppShow/Editor/EditorView+Preview.swift:5`) read `editorState.zoomTimeline` while building `VideoPreviewView(... zoomTimeline: editorState.zoomTimeline, currentTime: CMTimeGetSeconds(editorState.currentTime), zoomFollowCursor:, cursorMetadataProvider: editorState.activeCursorProvider, ...)` → SwiftUI re-evaluates the body and calls **`VideoPreviewView.updateNSView(_:context:)`** (`AppShow/Editor/VideoPreviewView.swift:106`).
   - `updateNSView` runs, in order: `updateCameraVisibility`, `updateScreenVisibility`, `updateWebcamOutput`, `updateLayout`, **`updateZoom`**, `updateOverlays`, `updateClickSound` (`AppShow/Editor/VideoPreviewView+Update.swift`).
   - **`updateZoom(_:)`** (`+Update.swift:318`): `zoomRect = zoomTimeline.zoomRect(at: currentTime)` (binary search + quintic ease, `AppShow/Editor/ZoomTimeline.swift:24`); if `zoomFollowCursor` and zoomed in, `ZoomTimeline.followCursor(rect, cursorPosition: provider.sample(at:))`; then **`VideoPreviewContainer.updateZoomRect(_:)`** (`AppShow/Editor/VideoPreviewContainer+Layout.swift`), which sets `currentZoomRect` and re-lays out `screenContainerLayer`/`screenPlayerLayer` (the zoom is a layer transform over the `AVPlayerLayer`, not a re-decode).
   - `TimelineView+Overlays`/`ZoomKeyframeEditor+RegionView` re-render the region chip from the new `allKeyframes`.
5. **Persistence fan-out** (asynchronous): `EditorState.observeChanges()` (`AppShow/Editor/EditorState+Persistence.swift:351`) listed `_ = self.zoomTimeline` in its `withObservationTracking` body, so its `onChange` fires → `Task { @MainActor in syncVideoRegionsToPlayer(); playerController.previewMode = isPreviewMode; scheduleSave(); if !isRestoringState { scheduleUndoSnapshot() }; observeChanges() }`.
   - `scheduleSave()` (`:8`): cancel the pending task, sleep 1 s, then `saveState()` → `project.saveEditorState(createSnapshot())` → rewrite `project.json`.
   - `scheduleUndoSnapshot()` (`:338`): cancel pending, sleep 1.5 s, then `history.pushSnapshot(createSnapshot())` (`AppShow/Editor/History.swift:31`; truncates redo, caps at 50). Continuous dragging therefore produces one snapshot per pause of ≥ 1.5 s.
6. **Playback keeps the preview in sync**: `SyncedPlayerController.setupTimeObserver()` (`AppShow/Editor/SyncedPlayerController.swift:173`) updates `currentTime` 60×/s on `.main` inside `MainActor.assumeIsolated`; `EditorState.currentTime` is a computed passthrough, so every view that reads it (the preview, ruler, playhead) re-evaluates and `updateNSView` re-runs `updateZoom`/`updateOverlays` with the new time. Cursor sway/bounce/blur are computed per tick from `CursorEffects` using the sample 1/60 s earlier.

### B.2 Example: changing the background

- **Solid colour / gradient.** `PropertiesPanel+Background.swift` renders `SwatchButton`s that set `PropertiesPanel`'s `@State selectedColorId` / `selectedGradientId`; the panel's `onChange` handlers write **`editorState.backgroundStyle = .solidColor(CodableColor)`** or **`.gradient(id)`** (`BackgroundStyle`, `AppShow/Compositor/BackgroundStyle.swift`).
- **Image.** `ImageDropSection.onDrop` → **`EditorState.setBackgroundImage(from:)`** (`AppShow/Editor/EditorState+Background.swift:5`): deletes any `background-image.*` in the bundle, `copyItem` to `<bundle>/background-image.<ext>`, `backgroundImage = NSImage(contentsOf:)`, `backgroundStyle = .image(filename)`. (The image therefore travels with the `.appshow` bundle, and `restoreFromSnapshot` reloads it by filename.)
- **Preview.** `EditorView+Preview.videoPreview` recomputes `hasEffects` (any non-`.none` background, non-original aspect, padding, corner radius, or shadow) and `canvasAspect = editorState.canvasSize(for: screenSize)`; if `hasEffects` it draws `backgroundView` (a SwiftUI `LinearGradient`/`Color`/`Image`) *behind* the `VideoPreviewView` and switches the `.aspectRatio` modifier to the canvas ratio. The AppKit container only receives `padding`/`videoCornerRadius`/`videoShadow` through `updateLayout` → `updateCameraLayout(...)`; the background itself is pure SwiftUI in the editor and pure CoreGraphics (`FrameRenderer+Background`) at export — two implementations of the same visual, which is a classic source of preview/export mismatch and a good target for a golden-image test.
- Persistence and undo proceed exactly as in B.1 step 5 (`backgroundStyle` and `backgroundImageFillMode` are in the observed list; `History+ChangeRules.swift` turns the diff into a label such as "Background changed").

### B.3 Undo, for completeness

`EditorWindow`'s key monitor → `EditorState.undo()` → `history.undo()` → **`restoreFromSnapshot(_:)`** (`EditorState+Persistence.swift:131`): sets `isRestoringState = true`, assigns every property from the `EditorStateData`, diffs against the previous snapshot to decide which side-effect syncs to run (`syncAudioVolumes`, `syncAudioRegionsToPlayer`, `syncNoiseReduction`, `regenerateSmoothedCursor`, `clampCameraPosition`), `scheduleSave()`, then clears `isRestoringState` in a follow-up `Task` so the observation fan-out that these assignments trigger does not push a new undo snapshot.

---

## Flow C — Export, from `ExportSheet` to finished MP4

### C.1 UI → EditorState

1. `EditorTopBar` sets `editorState.showExportSheet = true`; `EditorView` presents **`ExportSheet(editorState:isPresented:)`** as a `.sheet` (`AppShow/Editor/EditorView.swift:112`).
2. `ExportSheet` (`AppShow/Compositor/ExportSheet.swift`) edits a local `@State settings = ExportSettings()`; choosing an `ExportPreset` replaces it wholesale; manual edits go through `manualBinding(_:)` which resets the preset to `.custom`. Format/codec coherence rules (`GIF ⇒ fps ≤ 30`, `MP4 ⇒ no ProRes`, `ProRes ⇒ MOV`) are `onChange` handlers.
3. **`ExportSheet.startExport()`** (`ExportSheet+Phases.swift:129`): `phase = .exporting`; `exportTask = Task { let url = try await editorState.export(settings: settings); … phase = .completed }`; stores the task in `editorState.exportTask` so `cancelExport()` can cancel it. `interactiveDismissDisabled` while exporting; `onDisappear` cancels.
4. **`EditorState.export(settings:)`** (`AppShow/Editor/EditorState+Export.swift:5`):
   - `isExporting = true` (observed by `EditorWindow.observeExporting` → `SessionState.updateStatusIcon()` → pulsing menu-bar icon).
   - Waits (100 ms polling) if `isMicProcessing` (a noise-reduction pass is still running from a slider change).
   - `cursorSnapshot = showCursor ? activeCursorProvider?.makeSnapshot() : nil` — `activeCursorProvider` is the spring-smoothed provider when `cursorMovementEnabled` (`EditorState+Cursor.swift`); for GIF the samples are made loopable by `CursorLoopTelemetry.makeLoopable`.
   - Converts all region arrays to `CMTimeRange`s / `RegionTransitionInfo` / `CameraCustomRegion`; decides `vidRegions` is empty when the single video region equals the trim range with no transitions (`isSingleFullRange`).
   - Builds **`ExportConfiguration`** (~70 fields) — the *only* thing the compositor sees — with `trimRange` = trim (no cuts) or `0…duration` (cuts), effective volumes (mute ⇒ 0), `captionSegments` only if `settings.burnInCaptions`, `spotlightRegions` only if `spotlightEnabled && showCursor`.
   - `let url = try await VideoCompositor.export(result: exportResult, config: exportConfig, progressHandler: { progress, eta in state.exportProgress = progress; state.exportETA = eta })`.
   - Afterwards writes `.srt`/`.vtt` next to the output via `SubtitleExporter` if requested; `lastExportedURL = url`; `defer` resets `isExporting`.

### C.2 `VideoCompositor.export` (`AppShow/Compositor/VideoCompositor.swift:16`) — runs off-main

5. `AVMutableComposition`; load the screen track, `naturalSize`, `timeRange`; `effectiveTrim = config.trimRange` if valid else the whole track.
6. **Timeline compression.** If `config.videoRegions` is non-empty, insert each region's overlap with the trim into the composition track back-to-back, recording `VideoSegment(sourceRange:compositionStart:)`; `compositionDuration = Σ`. Otherwise insert the trim at `.zero`.
7. **Audio preprocessing** (`VideoCompositor+AudioPreprocessing.swift`): `processMicrophoneAudio(result:config:)` → if `micNoiseReductionEnabled`, reuse `config.processedMicAudioURL` (the editor's cached `denoised-mic.m4a` inside the bundle) or run `RNNoiseProcessor.processFile`; `generateClickSound(...)` → `ClickSoundGenerator` renders an audio file of clicks (remapped through `VideoCompositor+RegionRemapping` if the timeline was compressed). Both temp files are `defer`-deleted.
8. Assemble `[AudioSource(url:regions:volume:)]` for system, mic (denoised or raw), and insert the click track directly.
9. **`checkNeedsCompositor(...)`** (`VideoCompositor+InstructionBuilder.swift:6`): true if any visual effect, webcam, cursor snapshot, zoom, GIF, video regions, captions, spotlight, click sound, **or** the export codec/resolution/fps differ from the source (`.standard ⇒ h265`, `.high ⇒ proRes422`, `.veryHigh ⇒ proRes4444`). Only a bare trim with matching codec takes the passthrough path.
10. `canvasSize = computeCanvasSize(screenNaturalSize:canvasAspect:padding:)` (aspect preset or `× (1 + 2·padding)`); `renderSize = computeRenderSize(canvasSize:resolution:)`; `exportFPS = settings.fps.value(fallback: result.fps)`.

**Passthrough branch** (`needsCompositor == false`): `addAudioTracks(...)`, `AVAssetExportSession(asset:presetName: AVAssetExportPresetPassthrough)` with `timeRange` and `audioMix`, **`runExport(_:to:fileType:progressHandler:)`** (`+ManualExport.swift:13`, polls `session.progress` every 200 ms from a `Task.detached`, `session.export(to:as:)`, cancellation → `cancelExport()`), then `moveToFinal`.

**Compositor branch**:

11. **`buildCompositionInstruction(...)`** (`+InstructionBuilder.swift`): adds the webcam track to the composition (time-remapped through the segments if cut), rasterises the background/camera-background images to `CGImage`, computes `cameraRect` from `CameraLayout` and `renderSize`, converts regions into composition time, and returns an immutable **`CompositionInstruction`**.
12. `format.isGIF` → **`gifExport(...)`** (`+GIFExport.swift`): `gifski_new(&settings)` (quality from `GIFQuality`), `gifski_set_file_output`, then an `AVAssetReader` loop on a global queue calling `FrameRenderer.renderFrame(...)` per frame and `gifski_add_frame_rgba`, `gifski_finish`. Output moved to `defaultSaveURL(for:extension: "gif")`. Return.
13. Otherwise `addAudioTracks(to:sources:videoTrimRange:videoSegments:)` + `buildAudioMix(for:sources:)` (`+Audio.swift`: one composition audio track per source, `AVMutableAudioMixInputParameters` volume), then:
    - `settings.mode == .parallel` → **`parallelRenderExport(...)`** (C.3), else **`runManualExport(...)`** (C.4). Both receive `composition, instruction, renderSize, fps, trimDuration = compositionDuration, outputURL = tempRecordingURL(), fileType, codec, audioMix, audioBitrate, isHDR, progressHandler`.
14. `destination = await MainActor.run { FileManager.default.defaultSaveURL(for: outputURL, extension: format.fileExtension) }` (`~/Movies/AppShow/reframed-<ts>.<ext>`), `moveToFinal(from:to:)` (replaces an existing file), return `destination`.

### C.3 Parallel export internals (`VideoCompositor+ParallelExport.swift:404-852`)

```
[async context]                          [DispatchQueue.global(.userInitiated)]                       [render-workers (concurrent)]           [video-writer queue]
withTaskCancellationHandler
 └ withCheckedThrowingContinuation
    └ global.async ──────────────────►  audio: aIn.requestMediaDataWhenReady → copy audioOutput → aIn  (DispatchGroup)
                                        frameWriter = OrderedFrameWriter(adaptor, input, totalFrames, progress, sem, metrics).start()
                                        jobs = FrameJobQueue(cap ≥ 256)
                                        spawn workerCount = activeProcessorCount workers ─────────►  loop: job = jobs.pop() (blocks; nil when closed)
                                        for frameIndex in 0..<totalFrames:                              seg = segPool.process(webcam)   (if camera bg)
                                          advance screen/webcam readers to PTS ≤ frameTime              FrameRenderer.renderFrame(job…)
                                          sem.wait()   ← CountingCondition(maxInFlight) back-pressure   frameWriter.submit(index, buffer, time)
                                          outputBuffer = CVPixelBufferPoolCreatePixelBuffer(pool)                                        │
                                          jobs.push(FrameJob(index, time, screen, webcam, out, …))                                        ▼
                                        jobs.close(); renderGroup.wait()                                             OrderedFrameWriter.drain():
                                        frameWriter.finish(); frameWriter.waitUntilDone()                             while pending[nextIndex] && input.isReadyForMoreMediaData:
                                        videoInput.markAsFinished(); reader.cancelReading(); audioGroup.wait()          adaptor.append(buffer, withPresentationTime:)
                                        writer.finishWriting { safeCont.resume() / .resume(throwing:) }                  nextIndex += 1; sem.signal(); progress every N frames
 onCancel: cancelToken.cancel()         (cancel checked before each push, in workers, before finish; on cancel: cancelWriting, delete output, throw CancellationError)
```

Key numbers: `maxInFlight = min(max(workers×2, 8), 20)`; pool minimum `maxInFlight + 4` buffers of `kCVPixelFormatType_64RGBAHalf` at `renderSize`; frame `i` has PTS `CMTime(value: i, timescale: fps)`; source frames are matched by "latest sample with PTS ≤ frame time + 1 ms" (so a 60 fps source exported at 30 fps drops every other frame, and a lower-fps source is frame-doubled). Progress/ETA come from `OrderedFrameWriter` on the writer queue via `Task { @MainActor in handler(...) }`. `Metrics` accumulates per-phase timings that are logged at the end.

### C.4 Manual export (`VideoCompositor+ManualExport.swift:41-374`)

Same reader/writer/pool setup, but a single loop on the global queue: match samples → `CVPixelBufferPoolCreatePixelBuffer` → `autoreleasepool { segmentation; FrameRenderer.renderFrame }` → spin-wait (`Thread.sleep(0.001)`) until `videoInput.isReadyForMoreMediaData` → `adaptor.append` → progress every 10 frames. Cancellation is a `nonisolated(unsafe)` `UnsafeMutablePointer<Bool>` flipped by `onCancel`. Despite the docs, this path does **not** use `AVAssetExportSession` or `AVVideoComposition`.

### C.5 Per-frame rendering (`FrameRenderer.renderFrame`, `AppShow/Compositor/FrameRenderer.swift`)

`computeFrameState(...)` derives, for `compositionTime`: the padded video rect (`AVMakeRect(aspectRatio:insideRect:)`), whether the camera is fullscreen/hidden/custom and its transition progress (`resolveActiveTransitionType`), screen transition state from `videoRegions`, the zoom rect (`instruction.zoomTimeline?.zoomRect(at:)` + `followCursor`), and cursor/spotlight/caption visibility. The extensions then draw in order into a `CGContext` over the output `CVPixelBuffer`: `+Background` → `+Screen` (zoom crop, corner radius, shadow) → `+Webcam` (PiP or fullscreen, border, mirror, segmentation image) → `+Cursor` (`CursorRenderer`/`SystemCursorRenderer`, click rings) → `+Spotlight` → `+Captions` (`CaptionLayout`). `+HDR` handles the P3/HLG paths when `isHDR`.

### C.5b Export as a diagram

```mermaid
sequenceDiagram
    autonumber
    participant X as ExportSheet (SwiftUI)
    participant E as EditorState (main)
    participant VC as VideoCompositor (nonisolated statics)
    participant PRE as RNNoiseProcessor / ClickSoundGenerator
    participant IB as +InstructionBuilder
    participant G as DispatchQueue.global driver
    participant WK as render-workers ×N
    participant OW as OrderedFrameWriter → AVAssetWriter
    X->>E: Task { export(settings:) } ; editorState.exportTask = task
    E->>E: isExporting = true ; wait for isMicProcessing ; cursorSnapshot = activeCursorProvider.makeSnapshot()
    E->>E: build ExportConfiguration (regions → CMTimeRange, effective volumes, captions/spotlight gating)
    E->>VC: await export(result:, config:, progressHandler:)
    VC->>VC: AVMutableComposition ; insert trim or video-region segments
    VC->>PRE: processMicrophoneAudio (cached denoised-mic.m4a or RNNoise) ; generateClickSound
    VC->>IB: checkNeedsCompositor ; computeCanvasSize ; computeRenderSize
    alt passthrough (no effects, codec/res/fps match)
        VC->>VC: addAudioTracks ; AVAssetExportSession(passthrough) ; runExport (Task.detached progress poller)
    else compositor
        VC->>IB: buildCompositionInstruction → CompositionInstruction (immutable)
        alt GIF
            VC->>G: gifExport: reader loop → FrameRenderer.renderFrame → gifski_add_frame_rgba → gifski_finish
        else parallel (default)
            VC->>VC: addAudioTracks ; buildAudioMix
            VC->>G: parallelRenderExport (withTaskCancellationHandler + withCheckedThrowingContinuation)
            G->>G: AVAssetReader(screen, webcam) ; AVAssetReader(audio mix) ; AVAssetWriter(video, audio)
            G->>OW: start() (requestMediaDataWhenReady)
            loop frameIndex in 0..<totalFrames
                G->>G: match latest sample ≤ frame time ; sem.wait() ; pool buffer
                G->>WK: jobs.push(FrameJob)
                WK->>WK: segPool.process ; FrameRenderer.renderFrame(job)
                WK->>OW: submit(index, buffer, time)
                OW->>OW: drain in index order ; adaptor.append ; sem.signal() ; progress → Task { @MainActor handler }
            end
            G->>G: jobs.close ; renderGroup.wait ; frameWriter.finish/waitUntilDone ; audioGroup.wait
            G->>G: writer.finishWriting { safeCont.resume() }
        else manual
            VC->>G: runManualExport (same, single loop, spin-wait on isReadyForMoreMediaData)
        end
    end
    VC->>VC: await MainActor.run { defaultSaveURL } ; moveToFinal
    VC-->>E: URL
    E->>E: SubtitleExporter .srt/.vtt if requested ; lastExportedURL = url ; isExporting = false (defer)
    E-->>X: url → phase = .completed
```

### C.6 Back to the UI

15. `EditorState.export` returns → `ExportSheet.startExport`'s task sets `editorState.lastExportedURL = url`, `phase = .completed` (shows filename + `MediaFileInfo.formattedFileSize`, Copy/Show in Finder/Done). `EditorWindow.observeExporting` sees `isExporting == false` → `SessionState.updateStatusIcon()` stops the pulse. `EditorWindow.onSave` (`SessionState.lastRecordingURL`) is invoked from the editor's save action, not from export.

### C.7 What a test suite can hold onto

| Seam | Type | Why it is testable without hardware |
| --- | --- | --- |
| `EditorState.export` → compositor | `ExportConfiguration` | Pure struct; assert that editor state maps to config (mute ⇒ volume 0, `isSingleFullRange`, region conversion). |
| `checkNeedsCompositor`, `computeCanvasSize`, `computeRenderSize` | static pure functions | Table-driven tests on `ExportConfiguration` + `RecordingResult`. |
| `buildCompositionInstruction` | needs only file URLs of small fixture movies | Can run on CI with tiny generated assets. |
| `FrameRenderer.renderFrame` | `CVPixelBuffer` in/out + `CompositionInstruction` | Golden-image tests per feature (background, zoom, cursor). |
| `ZoomTimeline`, `ZoomDetector`, `CursorSmoothing`, `CursorMetadataProvider`, `VideoCompositor+RegionRemapping` | pure logic | Unit tests. |
| `SharedRecordingClock`, `VideoTrackWriter`/`AudioTrackWriter` with synthetic `CMSampleBuffer`s | queue-confined classes | Deterministic when driven synchronously on their queue. |
| `AppShowProject.create/open/saveEditorState`, `EditorStateData` lenient decoding | file system in a temp dir | Round-trip and backward-compatibility tests against checked-in `project.json` fixtures. |

## Flow D — Project conversation to live editor mutation

1. `EditorView` owns an `AgentBridgeController` for the open `EditorState`. Starting it creates a sibling `.agent/<project>/` workspace with a private token, Unix socket, frame directory, and provider configuration.
2. `AgentConversationView` starts one fresh `AgentSession` child process for the selected provider turn. The child environment is allow-listed and retains only the search path, home, locale, terminal, user identity needed for credential lookup, provider-specific configuration, and the socket/token pair.
3. `ClaudeCodeProvider` supplies a strict one-server MCP file; `CodexProvider` supplies equivalent `mcp_servers.appshow` overrides. Both CLIs start the signed `Contents/Helpers/appshow-mcp` executable.
4. The helper injects the private token into `initialize` and relays newline-framed JSON-RPC to `AgentBridgeServer`. `AgentRPCSession` rejects unauthenticated or pre-initialize calls, then delegates `tools/list` and `tools/call` to the main-actor `AgentToolDispatcher`.
5. Read-only handlers snapshot the open project or analyze its media. Mutating handlers validate their JSON schema, publish `AgentActivity`, capture a pre-call snapshot, and use the editor's existing state primitives. Success creates at most one `Agent: …` history entry and returns the compact updated timeline; failure restores the snapshot.
6. External image reads, exact-path exports, and silence passes that would remove more than 40% pause as an `AgentConfirmationRequest`. Allow Once is bound to the normalized operation and consumed on use; denial, mismatch, expiry, or session clear cannot authorize another operation.
7. `AgentTranscript` reduces streamed provider events into the single persisted project conversation. Tool rows and timeline highlights update while calls run; clearing the conversation also clears provider resume ids and outstanding confirmations.
