# 05 — Coding Patterns and Conventions

**Analysis date:** 2026-09-03
**Scope:** `Reframed/` (235 Swift files, ~33k LOC), Swift 6 strict concurrency, SwiftUI + AppKit, macOS 15+.
**Source of rules:** `AGENTS.md`, `CONTRIBUTING.md`, `.swift-format`. Every pattern below is grounded in a verbatim excerpt from the tree. Where the codebase does not follow its own rules, the deviation is called out under **Inconsistency** so a fork can decide whether to fix or codify it.

---

## 1. File organisation

### 1.1 `Type+Concern.swift` extension splitting

Large types are one primary file holding stored properties, `init`, and the smallest core API, plus N sibling files named `Type+Concern.swift` that each contain a single `extension Type { ... }`. Extensions cannot add stored properties, so every stored `var` lives in the primary file and the extensions are pure behaviour.

Observed families (file counts):

| Primary file | Extension files |
|---|---|
| `Editor/EditorState.swift` | `+AudioRegions`, `+Background`, `+CameraLayout`, `+CameraRegions`, `+Captions`, `+Cursor`, `+Export`, `+Persistence`, `+Playback`, `+Project`, `+SpotlightRegions`, `+VideoRegions`, `+Zoom` (13) |
| `State/SessionState.swift` | `+Audio`, `+Camera`, `+Project`, `+Recording`, `+Selection`, `+UI`, `+WindowInfo` (7) |
| `Compositor/VideoCompositor.swift` | `+Audio`, `+AudioPreprocessing`, `+Background`, `+GIFExport`, `+InstructionBuilder`, `+ManualExport`, `+ParallelExport`, `+RegionRemapping` (8) |
| `Compositor/FrameRenderer.swift` | `+Background`, `+Captions`, `+Cursor`, `+HDR`, `+Helpers`, `+Screen`, `+Spotlight`, `+Webcam` (8) |
| `Recording/RecordingCoordinator.swift` | `+Device`, `+Lifecycle`, `+Screen` (3) |
| `Editor/PropertiesPanel.swift` | `+AudioTab`, `+Background`, `+CameraTab`, `+CaptionsTab`, `+CursorZoomTab`, `+EffectsTab`, `+GeneralTab`, `+VideoTab` (8) |
| `Editor/TimelineView.swift` | `+AudioTrack`, `+CameraTrack`, `+Overlays`, `+Ruler`, `+ScreenTrack`, `+Shared`, `+SpotlightTrack` (7) |
| `UI/SettingsView.swift` | `SettingsGeneralTab`, `SettingsRecordingTab`, `SettingsDevicesTab`, `SettingsShortcutsTab`, `SettingsAboutTab` (no `+`, but same `extension SettingsView` pattern) |

The primary file for `RecordingCoordinator` is nothing but state and handler setters; all lifecycle logic is in extensions:

```swift
// Reframed/Recording/RecordingCoordinator.swift
actor RecordingCoordinator {
  var captureSession: ScreenCaptureSession?
  var systemAudioCapture: SystemAudioCapture?
  ...
  let logger = Logger(label: "eu.jankuri.reframed.recording-coordinator")
  var onStreamError: (@Sendable (any Error) -> Void)?
  var onDeviceLost: (@Sendable (String) -> Void)?
  ...
  func setStreamErrorHandler(_ handler: @escaping @Sendable (any Error) -> Void) {
    onStreamError = handler
  }
```

```swift
// Reframed/Recording/RecordingCoordinator+Lifecycle.swift
import CoreMedia
import Foundation

extension RecordingCoordinator {
  func pause() {
    pauseStartTime = CMClockGetTime(CMClockGetHostTimeClock())
    captureSession?.pause()
    systemAudioCapture?.pause()
    ...
    logger.info("Recording paused")
  }
```

For `@MainActor` classes the extension re-declares the isolation on the extension itself:

```swift
// Reframed/State/SessionState+Recording.swift
@MainActor
extension SessionState {
  func beginRecordingWithCountdown() {
```

For SwiftUI views the extension exposes `var xSection: some View` computed properties that the primary `body` composes:

```swift
// Reframed/Editor/PropertiesPanel+VideoTab.swift
extension PropertiesPanel {
  var canvasSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "rectangle.dashed", title: "Canvas")
      SegmentPicker(
        items: CanvasAspect.allCases,
        label: { $0.label },
        selection: $editorState.canvasAspect
      )
```

Nested/private helper types that only one extension needs are declared `private` inside that extension file (`VideoCompositor+ManualExport.swift` defines `private final class ExportProgressPoller`, `VideoCompositor+ParallelExport.swift` defines `CancelToken`, `SafeContinuation`, `FrameJobQueue`, …).

### 1.2 When a file gets split, and the 200-line rule

`CONTRIBUTING.md`: "If a view goes past 200 lines, split it into separate files using Swift extensions." The rule is scoped to **views**. Non-view files are routinely far larger: `VideoCompositor+ParallelExport.swift` (852), `GradientPresets.swift` (649), `ProjectMetadata.swift` (612), `FrameRenderer+HDR.swift` (607).

**Inconsistency.** Seven view-bearing files exceed 200 lines even after splitting: `Recording/RecordingPreviewWindow.swift` (366), `Editor/TimelineView.swift` (264), `Compositor/ExportSheet.swift` (253), `Recording/WebcamPreviewWindow.swift` (233), `CaptureModes/CaptureArea/SelectionOverlayView.swift` (217), `Recording/DevicePreviewWindow.swift` (216), `Editor/CameraRegionEditPopover.swift` (215). Treat 200 as a soft target; the split points that are actually respected are "one tab / one track / one concern per file".

### 1.3 Imports

`.swift-format` enforces `OrderedImports`. Imports are alphabetical by module name, with `@preconcurrency` attributes sorting with the module (so `@preconcurrency import ScreenCaptureKit` comes after `Logging`):

```swift
// Reframed/Recording/RecordingCoordinator+Screen.swift
import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation
import Logging
@preconcurrency import ScreenCaptureKit
```

Files import only what they use; `Foundation` is omitted when `AppKit`/`SwiftUI` already re-export it in practice (e.g. `UI/ToggleRow.swift` imports only `SwiftUI`). `Utilities/SendableBox.swift` has no imports at all.

---

## 2. State management

### 2.1 `@MainActor @Observable final class` models

The two central models are `SessionState` (app/recording lifecycle) and `EditorState` (editor). Both are `@MainActor`, `@Observable`, `final class`, with plain `var` stored properties and defaults inline. `RecordingOptions` and `History` follow the same shape.

```swift
// Reframed/Editor/EditorState.swift
@MainActor
@Observable
final class EditorState {
  var result: RecordingResult
  var project: ReframedProject?
  var playerController: SyncedPlayerController
  var cameraLayout = CameraLayout()
  var trimStart: CMTime = .zero
  var trimEnd: CMTime = .zero
  var systemAudioRegions: [AudioRegionData] = []
```

Stored properties are grouped by concern with blank lines, not by access level. There are no `private` stored properties on these models because extensions in other files need them; the only `let` members are `logger` and `options`.

### 2.2 How views bind

Two access patterns depending on whether the view needs `$` bindings:

- Views that mutate through bindings take `@Bindable var editorState: EditorState`. Used in exactly seven views: `EditorView`, `PropertiesPanel`, `TimelineView`, `EditorTopBar`, `HistoryPopover`, `ExportSheet`, `OptionsPopover`.
- Views that only read (or call methods) take a plain `let session: SessionState` (`CaptureToolbar`, `MenuBarView`, `CaptureAreaView`). `@Observable` tracking works through a plain `let` reference.

```swift
// Reframed/Editor/PropertiesPanel.swift
struct PropertiesPanel: View {
  @Bindable var editorState: EditorState
  let selectedTab: EditorTab
  @Environment(\.colorScheme) private var colorScheme
```

```swift
// Reframed/UI/CaptureToolbar.swift
struct CaptureToolbar: View {
  let session: SessionState
  @State var showOptions = false
  @State var showSettings = false
```

Controls bind straight into model properties (`$editorState.padding`), so a slider drag writes to the model on every tick; there is no local draft copy for simple properties:

```swift
// Reframed/Editor/PropertiesPanel+VideoTab.swift
      SliderRow(
        value: $editorState.padding,
        range: 0...0.50,
        step: 0.01,
        formattedValue: "\(Int(editorState.padding * 100))%"
      )
```

The model is created and owned outside SwiftUI: `AppDelegate` owns `let session = SessionState()`; `EditorWindow` creates `EditorState` and hands it to `EditorView` through `NSHostingView`. Nothing is put in `@Environment`; models are passed explicitly as init parameters.

### 2.3 `@State` versus model

`@State` (134 occurrences) is used for view-local, non-persisted UI state: popover/sheet visibility flags, drag offsets, hover, tab selection, and **local mirrors of model values that need an intermediate representation**. `PropertiesPanel` keeps a `BackgroundMode` enum and selected-gradient/colour IDs in `@State` and folds them into the single `editorState.backgroundStyle` enum in `onChange`:

```swift
// Reframed/Editor/PropertiesPanel.swift
  @State var backgroundMode: BackgroundMode = .color
  @State var selectedGradientId: Int = 0
  @State var selectedColorId: String? = "Black"
  ...
    .onChange(of: selectedGradientId) { _, newValue in
      if backgroundMode == .gradient {
        editorState.backgroundStyle = .gradient(newValue)
      }
    }
```

Popovers that edit a region take the region as a `let` value plus callbacks, copy it into `@State` on first appear, and push changes out through `onChange`:

```swift
// Reframed/Editor/VideoRegionEditPopover.swift
  @State private var localEntryTransition: RegionTransitionType = .none
  @State private var didInit = false
  ...
    .onAppear {
      if !didInit {
        localEntryTransition = region.entryTransition ?? .none
        ...
        didInit = true
      }
    }
    .onChange(of: localEntryTransition) { _, newValue in
      onUpdateTransition(newValue, nil, nil, nil)
    }
```

### 2.4 Derived state

Derived values are computed properties on the model, never cached in stored vars:

```swift
// Reframed/Editor/EditorState.swift
  var hasSystemAudio: Bool { result.systemAudioURL != nil }
  var hasMicAudio: Bool { result.microphoneAudioURL != nil }
  var effectiveSystemAudioVolume: Float { systemAudioMuted ? 0 : systemAudioVolume }
  var effectiveMicAudioVolume: Float { micAudioMuted ? 0 : micAudioVolume }
  var isPlaying: Bool { playerController.isPlaying }
```

Views compute their own cheap derived flags as `private var` for animation keys:

```swift
// Reframed/Editor/EditorView.swift
  private var timelineTrackSignature: Int {
    var h = 0
    if editorState.hasWebcam && editorState.webcamEnabled { h |= 1 }
    if !editorState.systemAudioMuted { h |= 2 }
```

### 2.5 The `let _ = colorScheme` idiom

Nearly every view declares `@Environment(\.colorScheme) private var colorScheme` and starts `body` with `let _ = colorScheme` (44 occurrences). `ReframedColors` reads `NSApp.effectiveAppearance` rather than SwiftUI's environment, so this forces a re-render when the appearance flips. Copy it into any new view that uses `ReframedColors`.

```swift
// Reframed/UI/ToggleRow.swift
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    HStack {
```

**Inconsistency.** `App/WindowController.swift` is the one model still on the old `ObservableObject` / `@Published` API:

```swift
// Reframed/App/WindowController.swift
final class WindowController: ObservableObject {
  @Published var currentWindow: WindowInfo?
```

New code must use `@Observable`.

### 2.6 Callbacks into `@MainActor` from AppKit closures

AppKit callbacks that are documented main-thread but not annotated use `MainActor.assumeIsolated` (25 uses) rather than `Task { @MainActor in }`:

```swift
// Reframed/State/SessionState+Project.swift
    editor.onSave = { [weak self, weak editor] url in
      MainActor.assumeIsolated {
        guard let self else { return }
        self.lastRecordingURL = url
```

---

## 3. Undo / redo

### 3.1 Snapshot history

`Editor/History.swift` is a `@MainActor @Observable` class holding up to 50 full `EditorStateData` snapshots plus a cursor. There is no command pattern; every undo step is a whole-state diff.

```swift
// Reframed/Editor/History.swift
  func pushSnapshot(_ snapshot: EditorStateData) {
    if currentIndex < entries.count - 1 {
      entries.removeSubrange((currentIndex + 1)...)
    }
    entries.append(HistoryEntry(snapshot: snapshot, timestamp: Date()))
    currentIndex = entries.count - 1
    if entries.count > maxSnapshots {
      let excess = entries.count - maxSnapshots
      entries.removeFirst(excess)
      currentIndex -= excess
    }
  }
```

### 3.2 How a change gets recorded

Recording is automatic and debounced. `EditorState+Persistence.swift` registers a `withObservationTracking` closure that touches **every** undoable property; on any change it schedules a save (1 s) and an undo snapshot (1.5 s), then re-registers itself:

```swift
// Reframed/Editor/EditorState+Persistence.swift
  func observeChanges() {
    withObservationTracking {
      _ = self.backgroundStyle
      _ = self.backgroundImageFillMode
      ...
      _ = self.captionAudioSource
    } onChange: {
      Task { @MainActor [weak self] in
        guard let self else { return }
        self.syncVideoRegionsToPlayer()
        self.playerController.previewMode = self.isPreviewMode
        self.scheduleSave()
        if !self.isRestoringState {
          self.scheduleUndoSnapshot()
        }
        self.observeChanges()
      }
    }
  }
```

```swift
  func scheduleUndoSnapshot() {
    pendingUndoTask?.cancel()
    pendingUndoTask = Task {
      try? await Task.sleep(for: .seconds(1.5))
      guard !Task.isCancelled else { return }
      history.pushSnapshot(createSnapshot())
    }
  }
```

Gesture-driven edits (camera drag, caption drag) bypass the debounce and push a snapshot explicitly on drag end:

```swift
// Reframed/Editor/EditorView+Preview.swift
            onDragEnd: {
              editorState.scheduleSave()
              editorState.history.pushSnapshot(editorState.createSnapshot())
            }
```

Undo/redo call `restoreFromSnapshot`, which sets `isRestoringState = true` so the observation callback does not record the restore as a new change, then clears the flag on the next main-actor hop:

```swift
// Reframed/Editor/EditorState+Persistence.swift
  func restoreFromSnapshot(_ data: EditorStateData) {
    isRestoringState = true
    pendingUndoTask?.cancel()
    let prev = createSnapshot()
    ...
    scheduleSave()
    Task { @MainActor [weak self] in
      self?.isRestoringState = false
    }
  }
```

### 3.3 "Change rules"

`History+ChangeRules.swift` turns two snapshots into human-readable strings for `HistoryPopover`. A rule is `typealias ChangeRule = (EditorStateData, EditorStateData) -> [String]`. Rules are built from four keypath helpers in `History.swift` (`prop`, `toggle`, `sub`, `subToggle`, `regions`) and collected in `static let rules: [ChangeRule]`:

```swift
// Reframed/Editor/History+ChangeRules.swift
    prop(\.canvasAspect) { "Canvas aspect ratio set to \(($0 ?? .original).label)" },
    prop(\.padding) { "Padding set to \(Int($0 * 100))%" },
    ...
    toggle(\.cameraMirrored, default: false, on: "Camera mirror enabled", off: "Camera mirror disabled"),
    ...
    regions(
      \.spotlightRegions,
      added: "Spotlight region added",
      removed: "Spotlight region removed",
      adjusted: "Spotlight region adjusted"
    ),
```

Nested optional structs (`cursorSettings`, `zoomSettings`, …) use `sub`/`subToggle` with an explicit default so a `nil` parent compares equal to the default value:

```swift
        sub(\.cursorSettings, \.spotlightRadius, default: CGFloat(200)) {
          "Spotlight radius set to \(Int($0))px"
        },
```

If no rule matches, the diff is described as the fallback string:

```swift
  static func describeChanges(from old: EditorStateData, to new: EditorStateData) -> [String] {
    var changes = rules.flatMap { $0(old, new) }
    if changes.isEmpty { changes.append("Editor settings updated") }
    return changes
  }
```

### 3.4 Wiring a new editable property into history

A property that is missing from any one of these places silently degrades (not undoable, not described, or not persisted):

1. Stored `var` on `EditorState` (`Editor/EditorState.swift`).
2. Field on `EditorStateData` in `Project/ProjectMetadata.swift`; make it optional or give it a default so old `project.json` files still decode.
3. Emit in `createSnapshot()` and apply in `restoreFromSnapshot(_:)` (`EditorState+Persistence.swift`).
4. Apply on load in `EditorState.init(project:)` **and/or** `setup()` — see the inconsistency below.
5. Add `_ = self.<property>` to `observeChanges()`.
6. Add a `prop`/`toggle`/`sub` rule in `History+ChangeRules.swift`.

**Inconsistency.** Restore-from-disk is duplicated across three places with hand-copied assignments: `EditorState.init(project:)` restores canvas/camera/caption fields, `setup()` restores cursor/zoom/animation/audio/regions, and `restoreFromSnapshot` restores everything again. The defaults are repeated inline each time (`?? CodableColor(r: 0, g: 0, b: 0, a: 1)` appears in all three). When adding a property, grep for an existing sibling (e.g. `cameraMirrored`) and mirror every site.

---

## 4. Persistence and the `.frm` project format

### 4.1 Bundle layout and `ReframedProject`

`Project/ReframedProject.swift` is a `Sendable` struct with `bundleURL` + `metadata`. File URLs inside the bundle are computed properties that return `nil` when the file is absent:

```swift
// Reframed/Project/ReframedProject.swift
  var webcamVideoURL: URL? {
    let url = bundleURL.appendingPathComponent("webcam.mp4")
    return FileManager.default.fileExists(atPath: url.path) ? url : nil
  }
```

Encoding is `JSONEncoder` with ISO-8601 dates and `[.prettyPrinted, .sortedKeys]` for `project.json`; `history.json` uses `[.sortedKeys]` only.

```swift
  func saveEditorState(_ state: EditorStateData) throws {
    var updated = metadata
    updated.editorState = state
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(updated)
    try data.write(to: bundleURL.appendingPathComponent("project.json"))
  }
```

**Inconsistency.** The encoder setup block is copy-pasted four times in `ReframedProject.swift` (`create`, `saveEditorState`, `rename`, `saveHistory`) rather than being a shared helper.

### 4.2 Codable conventions

- Persistence structs carry the `Data` suffix: `EditorStateData`, `CursorSettingsData`, `AudioRegionData`, `CameraRegionData`, `SpotlightRegionData`, `CaptionSettingsData`, `HistoryData`. They are `struct … : Codable, Sendable, Equatable` (regions add `Identifiable` with `var id: UUID = UUID()`).
- Newer fields are declared with inline defaults and decoded leniently. The decoders live in `extension` blocks so the synthesized memberwise `init` survives:

```swift
// Reframed/Project/ProjectMetadata.swift
extension CursorSettingsData {
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    showCursor = try c.decode(Bool.self, forKey: .showCursor)
    ...
    spotlightEnabled = try c.decodeOrDefault(.spotlightEnabled, false)
    spotlightRadius = try c.decodeOrDefault(.spotlightRadius, 200)
```

```swift
// Reframed/Utilities/LenientCodable.swift
extension KeyedDecodingContainer {
  func decodeOrDefault<T: Decodable>(
    _ key: Key,
    _ defaultValue: @autoclosure () -> T
  ) throws -> T {
    try decodeIfPresent(T.self, forKey: key) ?? defaultValue()
  }
}
```

- Top-level `EditorStateData` uses **optionals** for anything added after v1 and omits empty collections (`nil` rather than `[]`) when snapshotting:

```swift
// Reframed/Editor/EditorState+Persistence.swift
      systemAudioRegions: systemAudioRegions.isEmpty ? nil : systemAudioRegions,
      micAudioRegions: micAudioRegions.isEmpty ? nil : micAudioRegions,
      cameraBackgroundStyle: cameraBackgroundStyle == .none ? nil : cameraBackgroundStyle,
```

- Enums with associated values encode a string `type` discriminator plus per-case keys, and decode unknown types to a safe default:

```swift
// Reframed/Compositor/BackgroundStyle.swift
  private enum CodingKeys: String, CodingKey {
    case type, gradientId, color, filename
  }
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .none:
      try container.encode("none", forKey: .type)
    case .gradient(let id):
      try container.encode("gradient", forKey: .type)
      try container.encode(id, forKey: .gradientId)
```

- Colours are `CodableColor` (`Utilities/CodableColor.swift`), a `Sendable, Equatable, Codable` struct of four `CGFloat`s with `cgColor`, `hexString`, and `init(cgColor:)`. CG/NS types are never persisted directly; `CodableSize` wraps `CGSize`, and `StateService` has private `RectData`/`PointData`.
- Cursor metadata uses single-letter keys for size (`t`, `x`, `y`, `p`, `c` in `Editor/CursorMetadata.swift`).

### 4.3 Versioning and migration

`ProjectMetadata.version: Int = 1` exists but nothing switches on it. Forward compatibility is entirely "optional field or default". The single legacy migration is done at load time in `EditorState.setup()`:

```swift
// Reframed/Editor/EditorState.swift
      if let savedCameraRegions = saved.cameraRegions, !savedCameraRegions.isEmpty {
        cameraRegions = savedCameraRegions
      } else if let legacyRegions = saved.cameraFullscreenRegions, !legacyRegions.isEmpty {
        cameraRegions = legacyRegions.map {
          CameraRegionData(id: $0.id, startSeconds: $0.startSeconds, endSeconds: $0.endSeconds, type: .fullscreen)
        }
      }
```

**Inconsistency.** Two enum storage styles coexist: `cursorStyleRaw: Int` / `clickSoundStyleRaw: Int` store raw ints and are re-wrapped with `CursorStyle(rawValue:) ?? .centerDefault`, while every newer enum (`CaptionFontWeight`, `RegionTransitionType`, `CameraRegionType`) is `String`-backed and stored directly. New properties should use the string-backed direct form.

### 4.4 Where defaults live

Defaults are repeated, not centralised: the `EditorState` stored-property initialiser, the `EditorStateData`/`*SettingsData` inline defaults, the `decodeOrDefault` calls, the `?? x` fallbacks in restore code, and the `sub(..., default: x)` in change rules all carry the same literal. `ExportConfiguration` and `CompositionInstruction` repeat them again for the compositor. Keep them identical when adding a property.

---

## 5. Configuration

### 5.1 `ConfigService` and `StateService`

Both are `@MainActor final class` singletons with `static let shared`, a `private var data: <PrivateStruct>` and one JSON file under `~/.reframed/` (`reframed.json` and `state.json`). Every public property is a get/set pair that writes through and saves:

```swift
// Reframed/State/ConfigService.swift
  var fps: Int {
    get { data.fps }
    set { data.fps = newValue; save() }
  }
```

The backing struct is `private` at file scope with inline defaults; new keys need no migration because `load()` merges the saved dictionary over the encoded defaults:

```swift
    defaultsDict.merge(savedDict) { _, saved in saved }
    ...
private struct ConfigData: Codable {
  var outputFolder: String = "~/Movies/Reframed"
  var timerDelay: Int = 3
  var audioDeviceId: String? = nil
```

`StateService` uses a plain `JSONDecoder().decode`, which works because every `StateData` field is optional or defaulted. Enum-typed settings are stored as `String` raw values in `ConfigData` (`captureQuality: String = "standard"`, `appearance: String = "system"`) and re-wrapped at the edges.

**Inconsistency.** `AGENTS.md` says preferences live in `~/.reframed/config.json`; the code writes `reframed.json` (`docs/architecture.md` is correct). Trust the code.

### 5.2 `RecordingOptions`

`State/RecordingOptions.swift` is the `@Observable` façade the toolbar and settings bind to. Each property has a `didSet` that writes back to `ConfigService`, and `init` reads the initial values from it:

```swift
// Reframed/State/RecordingOptions.swift
@MainActor
@Observable
final class RecordingOptions {
  var timerDelay: TimerDelay {
    didSet { ConfigService.shared.timerDelay = timerDelay.rawValue }
  }
  var fps: Int {
    didSet { ConfigService.shared.fps = fps }
  }
```

Settings UI binds with explicit `Binding(get:set:)` because `options` is optional there:

```swift
// Reframed/UI/SettingsRecordingTab.swift
      settingsToggle(
        "HDR Capture",
        isOn: Binding(
          get: { options?.hdrCapture ?? false },
          set: { options?.hdrCapture = $0 }
        )
      )
```

**Inconsistency.** Two write paths coexist: recording-related settings go `SettingsView → RecordingOptions → ConfigService`, while `appearance`, `outputFolder`, `projectFolder`, `cameraMaximumResolution` are held as `@State` copies in `SettingsView` and written directly to `ConfigService.shared`. Recording-time settings should use `RecordingOptions`; app-level settings write to `ConfigService` directly.

### 5.3 Adding a setting end-to-end (observed path)

1. `ConfigData` field with default + `ConfigService` get/set property (`State/ConfigService.swift`).
2. `RecordingOptions` property with `didSet` + `init` read (`State/RecordingOptions.swift`) if it affects recording.
3. Consume it where the value is used: `SessionState+Recording.startRecording()` passes `options.*` into `RecordingCoordinator.startRecording(...)`, whose parameters then flow into `ScreenCaptureSession.start(...)` / `VideoTrackWriter.init(...)`.
4. UI: `settingsToggle`/`settingsRow` + `SegmentPicker` in the matching `UI/Settings<Tab>Tab.swift`, or a `CheckmarkRow` in `UI/OptionsPopover.swift` for toolbar-level options.

---

## 6. Actors, async, and error handling

### 6.1 Isolation map

| Kind | Examples | Rule |
|---|---|---|
| `actor` | `RecordingCoordinator` | Owns capture sources and writers; callers `await` every method. |
| `@MainActor final class` | `SessionState`, `EditorState`, `ConfigService`, `SelectionCoordinator`, `EditorWindow`, `KeyboardShortcutManager` | UI-facing state and window management. |
| `final class … @unchecked Sendable` | `ScreenCaptureSession`, `VideoTrackWriter`, `AudioTrackWriter`, `WebcamCapture`, `MicrophoneCapture`, `SystemAudioCapture`, `SharedRecordingClock`, `FrameRenderer`, `CompositionInstruction`, `ZoomTimeline` | Wrap AVFoundation/SCK delegates or immutable render data; protected by a dedicated `DispatchQueue` or `NSLock`. |
| `SendableBox<T>` | `SendableBox<AVCaptureSession>` | Carry a non-Sendable reference across an isolation boundary. |

**Inconsistency.** `AGENTS.md` states `@unchecked Sendable` is "only for `ScreenCaptureSession`". There are 31 occurrences. The real rule in the code: use it for classes whose mutation is confined to one serial `DispatchQueue` (asserted with `dispatchPrecondition`) or whose members are all `let`.

```swift
// Reframed/Recording/VideoTrackWriter.swift
final class VideoTrackWriter: @unchecked Sendable {
  ...
  let queue = DispatchQueue(label: "eu.jankuri.reframed.video-track-writer.queue", qos: .userInteractive)
  ...
  func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
    dispatchPrecondition(condition: .onQueue(queue))
```

### 6.2 Actor method conventions

Actor callbacks are stored `@Sendable` closures set via `setXHandler` methods, never assigned from outside. The `@MainActor` side hops back with `Task { @MainActor in }`:

```swift
// Reframed/State/SessionState+Recording.swift
    let coordinator = RecordingCoordinator()
    await coordinator.setStreamErrorHandler { [weak self] _ in
      guard let self else { return }
      Task { @MainActor in await self.handleStreamError() }
    }
```

Actors reach the main actor only for `ConfigService`-dependent helpers, via `MainActor.run` (4 uses in total):

```swift
// Reframed/Recording/RecordingCoordinator+Lifecycle.swift
    let destination = await MainActor.run { FileManager.default.defaultSaveURL(for: outputURL) }
```

Parallel shutdown uses `async let` on optional-chained calls:

```swift
    async let videoResult = videoWriter?.finish()
    async let webcamResult = webcamWriter?.finish()
    async let sysAudioResult = systemAudioWriter?.finish()
```

### 6.3 Wrapping callback APIs with continuations

There are 9 continuation sites and **no** `AsyncStream`. Pattern: explicit continuation type annotation, store the continuation on the object's serial queue, resume from the delegate callback, and arm a timeout that resumes with a `CaptureError`:

```swift
// Reframed/Recording/WebcamCapture.swift
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
      self.verifyQueue.async {
        self.firstFrameContinuation = continuation
      }
      DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) { [weak self] in
        guard let weakSelf = self else { return }
        nonisolated(unsafe) let sess = session
        weakSelf.verifyQueue.async {
          if let cont = weakSelf.firstFrameContinuation {
            weakSelf.firstFrameContinuation = nil
            sess.stopRunning()
            weakSelf.captureSession = nil
            cont.resume(throwing: CaptureError.cameraStreamFailed)
          }
        }
      }
    }
```

Writer `finish()` uses the non-throwing form and returns `URL?`, logging the failure instead of throwing:

```swift
// Reframed/Recording/AudioTrackWriter.swift
  func finish() async -> URL? {
    return await withCheckedContinuation { continuation in
      queue.async { [self] in
        ...
        nonisolated(unsafe) let writer = assetWriter
        writer.finishWriting {
          if writer.status == .completed {
            continuation.resume(returning: self.outputURL)
          } else {
            self.logger.error("Audio writing failed: \(writer.error?.localizedDescription ?? "unknown")")
            continuation.resume(returning: nil)
          }
```

Observation-to-async bridging (waiting for an `@Observable` change) also uses a continuation:

```swift
// Reframed/Editor/EditorWindow.swift
        await withCheckedContinuation { continuation in
          withObservationTracking {
            _ = state.isExporting
          } onChange: {
            continuation.resume()
          }
        }
```

### 6.4 `nonisolated(unsafe)` (68 uses)

Used for (a) AppKit observer tokens and timers on `@MainActor` classes so `deinit` can release them, (b) pinning a non-Sendable AVFoundation object into a `@Sendable` closure, (c) static immutable dictionaries of `Any`:

```swift
// Reframed/CaptureModes/CaptureWindow/WindowSelectionCoordinator.swift
  nonisolated(unsafe) private var eventMonitor: Any?
  nonisolated(unsafe) private var refreshTimer: Timer?
```

```swift
// Reframed/Utilities/EncodingSettings.swift
  nonisolated(unsafe) static let bt709ColorProperties: [String: Any] = [
```

### 6.5 Tasks, polling, cancellation

- Debounce: cancel the previous task, sleep, check `Task.isCancelled` (`scheduleSave`, `scheduleUndoSnapshot`).
- Polling loops: `while !Task.isCancelled { ... try? await Task.sleep(...) }` (`SessionState+Audio.startAudioLevelPolling`, `VideoCompositor+ManualExport.runExport` progress poller).
- Long operations: `try Task.checkCancellation()` inside loops, `catch is CancellationError {}` to swallow at the UI boundary.
- External cancellation: `withTaskCancellationHandler` with `nonisolated(unsafe)` capture:

```swift
// Reframed/Compositor/VideoCompositor+ManualExport.swift
    nonisolated(unsafe) let session = session
    try await withTaskCancellationHandler {
      try await session.export(to: url, as: fileType)
    } onCancel: {
      session.cancelExport()
    }
```

Long-lived tasks are stored as `Task<Void, Never>?` properties on the owning model (`exportTask`, `pendingSaveTask`, `transcriptionTask`, `audioLevelTask`) and cancelled in `teardown()`.

### 6.6 Error propagation

- **`throws` with `CaptureError`** is the only app error type. It lives in `State/CaptureState.swift`, is a `LocalizedError` enum with user-facing `errorDescription`, and is reused by the compositor (`CaptureError.recordingFailed("No video track in screen recording")`) rather than defining a compositor-specific error.
- **`Result`** is not used as a return type (one local `@Sendable func finish(_ result: Result<Void, Error>)` helper in `VideoCompositor+ManualExport.swift`).
- **Optional return** signals soft failure where a `nil` is recoverable: `finish() -> URL?`, `loadHistory() -> HistoryData?`, `ReframedProject.webcamVideoURL`.
- **`try?`** (96 sites) is the accepted form for best-effort file-system and persistence calls (`try? FileManager.default.removeItem`, `try? project.saveHistory(...)`).

```swift
// Reframed/State/CaptureState.swift
enum CaptureError: LocalizedError {
  case invalidTransition(from: String, to: String)
  case noSelectionStored
  ...
  var errorDescription: String? {
    switch self {
    case .invalidTransition(let from, let to):
      return "Invalid state transition from \(from) to \(to)"
```

### 6.7 How errors reach the user

Two surfaces. Recording/app-level failures go through `SessionState.showError`, a modal `NSAlert`, after logging and cleanup:

```swift
// Reframed/State/SessionState+Recording.swift
  func beginRecordingWithCountdown() {
    Task {
      do {
        try await startRecording()
      } catch {
        logger.error("Failed to start recording: \(error)")
        cleanupAfterRecordingFailure()
        showError(error.localizedDescription)
      }
    }
  }
```

```swift
// Reframed/State/SessionState+UI.swift
  func showError(_ message: String) {
    let alert = NSAlert()
    alert.messageText = "Recording Error"
    alert.informativeText = message
    alert.alertStyle = .critical
```

Editor/export failures stay inline: `ExportSheet` keeps `@State var errorMessage` and a `phase` enum and renders a `.failed` view:

```swift
// Reframed/Compositor/ExportSheet+Phases.swift
  func startExport() {
    phase = .exporting
    exportTask = Task {
      do {
        let url = try await editorState.export(settings: settings)
        try Task.checkCancellation()
        editorState.lastExportedURL = url
        phase = .completed
      } catch is CancellationError {
      } catch {
        errorMessage = error.localizedDescription
        phase = .failed
      }
    }
```

---

## 7. Logging

`swift-log` is bootstrapped once in `ReframedApp.init()` via `Logging/LogBootstrap.swift`: stdout in `DEBUG`, stdout plus `RotatingFileLogHandler` (`~/Library/Logs/Reframed/reframed.log`, 5 MB × 3 files) in release.

```swift
// Reframed/Logging/LogBootstrap.swift
enum LogBootstrap {
  static func configure() {
    LoggingSystem.bootstrap { label in
      #if DEBUG
      return StreamLogHandler.standardOutput(label: label)
      #else
      return MultiplexLogHandler([
        StreamLogHandler.standardOutput(label: label),
        RotatingFileLogHandler(label: label),
      ])
      #endif
```

Conventions observed across the 20 `Logger` instances:

- **Naming:** `Logger(label: "eu.jankuri.reframed.<kebab-case-component>")`, one per type, held as `private let logger` (or `let logger` when extensions in other files need it, or `static let logger` on enum namespaces). `AudioTrackWriter` suffixes the track label: `"eu.jankuri.reframed.audio-track-writer.\(label)"`.
- **Levels:** only `info` (63), `error` (38), `warning` (10). No `debug`/`trace`; verbose per-frame data is rate-limited by hand (`ScreenCaptureSession.lastLogTime`).
- **What is logged:** lifecycle transitions ("Recording paused", "Capture started"), device negotiation results, file paths on save/export, every caught error. Never per-frame or per-sample events.
- **Metadata:** used sparingly for structured values:

```swift
// Reframed/Recording/ScreenCaptureSession.swift
    logger.info(
      "Capture started",
      metadata: [
        "sourceRect": "\(sourceRect)",
        "displayScale": "\(displayScale)",
        "targetFps": "\(fps)",
        "output_size": "\(config.width)x\(config.height)",
      ]
    )
```

**Inconsistencies.**
- Logger label prefix is `eu.jankuri.reframed`, while the bundle ID is `eu.jkuri.reframed` (`AGENTS.md`). Keep using the `eu.jankuri` prefix for consistency with existing log filters.
- `App/WindowController.swift:30` uses `print("Failed to fetch SCWindows: \(error)")` instead of a logger.
- `VideoCompositor+ManualExport.swift:54` and `+ParallelExport.swift:413` create a local `let logger = Logger(label: "eu.jankuri.reframed.video-compositor")` inside a function although `VideoCompositor.logger` already exists as a static.

---

## 8. Rendering

### 8.1 `CompositionInstruction` → `FrameRenderer`

Export rendering is the `AVVideoCompositing` protocol. `CompositionInstruction` (`Compositor/CompositionInstruction.swift`) is an immutable, `let`-only `NSObject` subclass marked `@unchecked Sendable` with a ~70-parameter `init` in which everything after the track IDs has a default. It is the single bag of per-export parameters; nothing is looked up from `EditorState` at render time.

```swift
// Reframed/Compositor/CompositionInstruction.swift
final class CompositionInstruction: NSObject, AVVideoCompositionInstructionProtocol, @unchecked Sendable {
  let timeRange: CMTimeRange
  let enablePostProcessing = false
  let containsTweening = false
  let requiredSourceTrackIDs: [NSValue]?
  let passthroughTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid

  let screenTrackID: CMPersistentTrackID
  let webcamTrackID: CMPersistentTrackID?
  let cameraRect: CGRect?
```

The instruction is built in one place, `VideoCompositor+InstructionBuilder.buildCompositionInstruction`, which converts `ExportConfiguration` (canvas-space, percentages) into pixel-space values for the chosen render size:

```swift
// Reframed/Compositor/VideoCompositor+InstructionBuilder.swift
    let scaleX = renderSize.width / canvasSize.width
    let scaleY = renderSize.height / canvasSize.height
    let paddingHPx = config.padding * screenNaturalSize.width * scaleX
    let paddingVPx = config.padding * screenNaturalSize.height * scaleY
```

`FrameRenderer.startRequest` is thin: unwrap buffers, run person segmentation if needed, delegate to a **static** `renderFrame`, finish the request. All drawing functions are `static func` on `FrameRenderer` extensions so the parallel exporter can call them without an instance.

```swift
// Reframed/Compositor/FrameRenderer.swift
  func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
    guard let instruction = request.videoCompositionInstruction as? CompositionInstruction else {
      request.finish(with: NSError(domain: "FrameRenderer", code: -1))
      return
    }
    guard let screenBuffer = request.sourceFrame(byTrackID: instruction.screenTrackID) else {
      request.finish(with: NSError(domain: "FrameRenderer", code: -2))
      return
    }
```

Per-frame derived geometry is computed once into a value type (`FrameState` in `FrameRenderer+Helpers.swift`) and passed to every draw stage. Time-varying region lookups use `instruction.xRegions.first { $0.timeRange.containsTime(compositionTime) }`.

### 8.2 CoreGraphics on `CVPixelBuffer` (SDR path)

The SDR pipeline is pure CoreGraphics on a locked pixel buffer: 16-bit half-float RGBA (`kCVPixelFormatType_64RGBAHalf`), sRGB colour space, lock/unlock paired with `defer`, y-flip via `translateBy`/`scaleBy`, every stage bracketed by `saveGState`/`restoreGState`.

```swift
// Reframed/Compositor/FrameRenderer.swift
    CVPixelBufferLockBaseAddress(screenBuffer, .readOnly)
    CVPixelBufferLockBaseAddress(outputBuffer, [])
    if let wb = webcamBuffer {
      CVPixelBufferLockBaseAddress(wb, .readOnly)
    }
    defer {
      CVPixelBufferUnlockBaseAddress(screenBuffer, .readOnly)
      CVPixelBufferUnlockBaseAddress(outputBuffer, [])
```

```swift
// Reframed/Compositor/FrameRenderer+Cursor.swift
    context.saveGState()
    context.translateBy(x: 0, y: CGFloat(outputHeight))
    context.scaleBy(x: 1, y: -1)
    let flippedVideoRect = CGRect(
      x: videoRect.origin.x,
      y: CGFloat(outputHeight) - videoRect.origin.y - videoRect.height,
```

Coordinates flowing from metadata are normalised 0–1 and converted to pixels at the draw site. Easing uses the shared `smoothstep` free function from `Utilities/MathUtilities.swift`.

### 8.3 CoreImage (HDR and segmentation only)

`CIImage`/`CIContext` appear in exactly two files: `FrameRenderer+HDR.swift` (a `static let hdrCIContext` and an HDR variant of every stage) and `PersonSegmentationProcessor.swift` (Vision + CI). There is **no Metal** code. If you add a GPU path, follow the HDR file: keep a static `CIContext`, build `CIImage(cvPixelBuffer:)`, render into the output buffer with `hdrCIContext.render(...)`.

Shared, non-thread-safe processors are pooled with `NSCondition` rather than made actors, because the render callback is synchronous:

```swift
// Reframed/Compositor/PersonSegmentationProcessor.swift
final class SegmentationProcessorPool: @unchecked Sendable {
  private let condition = NSCondition()
  private var available: [PersonSegmentationProcessor] = []
  ...
    condition.lock()
    while available.isEmpty {
      condition.wait()
    }
```

### 8.4 Preview mirrors export

The editor preview is an `NSViewRepresentable` (`Editor/VideoPreviewView.swift`) whose value-typed properties are a hand-maintained mirror of `CompositionInstruction`, applied to an `NSView` with `CALayer`s (`VideoPreviewContainer`, `CursorOverlayLayer`, `SpotlightOverlayLayer`). Region tuples are inlined as labelled tuples rather than reusing `RegionTransitionInfo`:

```swift
// Reframed/Editor/VideoPreviewView.swift
  var cameraFullscreenRegions:
    [(
      start: Double, end: Double,
      entryTransition: RegionTransitionType, entryDuration: Double,
      exitTransition: RegionTransitionType, exitDuration: Double
    )] = []
```

Any visual property therefore has **two** render implementations to keep in sync: `FrameRenderer+X.swift` (export) and `VideoPreviewView+Update.swift` / `VideoPreviewContainer+X.swift` (preview).

---

## 9. UI conventions

### 9.1 Button styles

Defined in `UI/PrimaryButton.swift`: `PrimaryButtonStyle` (filled), `SecondaryButtonStyle` (muted fill), `OutlineButtonStyle` (border), and `PlainCustomButtonStyle` (label only — the style for icon/tab/row buttons). All take `ButtonSize` (`.small`/`.medium`/`.large`) and optional `fullWidth`. Usage counts: `PlainCustomButtonStyle` 33, `OutlineButtonStyle` 20, `PrimaryButtonStyle` 8, `SecondaryButtonStyle` 3.

```swift
// Reframed/UI/PrimaryButton.swift
struct OutlineButtonStyle: ButtonStyle {
  var size: ButtonSize = .small
  var fullWidth: Bool = false
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.colorScheme) private var colorScheme

  func makeBody(configuration: Configuration) -> some View {
    let _ = colorScheme
    configuration.label
      .font(.system(size: size.fontSize, weight: size.fontWeight))
      .foregroundStyle(ReframedColors.primaryText)
```

```swift
// Reframed/Editor/VideoRegionEditPopover.swift
        .buttonStyle(OutlineButtonStyle(size: .medium, fullWidth: true))
```

**Inconsistency.** Four "Reset" buttons still use the forbidden stock style: `Editor/PropertiesPanel+VideoTab.swift:30,54,77` and `Editor/PropertiesPanel+CameraTab.swift:41` (`.buttonStyle(.plain)`). New code must use `PlainCustomButtonStyle()`; these four are candidates for a cleanup commit.

### 9.2 Design tokens and colours

No literal font sizes, radii, or colours in views. Tokens are `enum` namespaces in `UI/Constants.swift` (`FontSize`, `Radius`, `Layout`, `Track`) and semantic colours in `UI/Colors.swift` (`ReframedColors.primaryText`, `.secondaryText`, `.tertiaryText`, `.border`, `.muted`, `.background`, `.backgroundCard`, `.backgroundPopover`, `.fieldBackground`, `.divider`, `.accent`, plus `NSColor` variants suffixed `NS`). Preset palettes are `TailwindColors.all: [ColorPreset]`.

```swift
// Reframed/UI/Constants.swift
enum Layout {
  static let sectionSpacing: CGFloat = 32
  static let itemSpacing: CGFloat = 16
  static let compactSpacing: CGFloat = 8
  ...
  static let regionPopoverWidth: CGFloat = 350
  static let propertiesPanelWidth: CGFloat = 390
```

Exception: the light-only capture overlays (`CaptureAreaView`, `ResizePopover`) define `private let textColor = Color.black` locals because they render over a dimmed screen regardless of appearance.

### 9.3 Reusable components (`UI/`)

Check these before writing a new control: `SectionHeader` (icon+title or bare title), `SliderRow` (+ private `MonoSlider`), `ToggleRow`/`CustomToggle`, `SegmentPicker<Item: Hashable>`, `CheckmarkRow`, `IconButton`, `Dropdown`, `NumberField`, `SwatchButton`, `TailwindColorPicker`, `InlineEditableText`, `ImageDropSection`, `TransitionControlsSection`, `ShortcutRecorderButton`/`ShortcutRow`, `ModeButton`, `StartRecordingButton`, `HoverEffectScope` + `.hoverEffect(id:)` (shared sliding hover highlight), and `.popoverContainerStyle()`.

Component API shape: `let` inputs first, `@Binding` for the edited value, optional customisation as `var x: T? = nil` with defaults, trailing `action` closure last.

```swift
// Reframed/UI/SliderRow.swift
struct SliderRow<V: BinaryFloatingPoint>: View where V.Stride: BinaryFloatingPoint {
  var label: String? = nil
  var labelWidth: CGFloat? = nil
  @Binding var value: V
  let range: ClosedRange<V>
  var step: V.Stride = 1
  var formattedValue: String? = nil
```

### 9.4 Popovers and sheets

Popover content: `VStack(alignment: .leading, spacing: 0)`, a `SectionHeader(title:)` first, `CheckmarkRow`s or controls, `Divider().background(ReframedColors.divider).padding(.vertical, 4)` between groups, fixed `.frame(width: Layout.regionPopoverWidth)` for editor popovers, and `.popoverContainerStyle()` last. Presented with `.popover(isPresented:arrowEdge:)` plus `.presentationBackground(ReframedColors.backgroundPopover)` when the container style is not applied.

```swift
// Reframed/UI/OptionsPopover.swift
    VStack(alignment: .leading, spacing: 0) {
      SectionHeader(title: "Timer")
      ForEach(TimerDelay.allCases, id: \.self) { delay in
        CheckmarkRow(
          title: delay.label,
          isSelected: options.timerDelay == delay
        ) {
          options.timerDelay = delay
        }
      }
      Divider()
        .background(ReframedColors.divider)
        .padding(.vertical, 4)
```

Multi-step sheets model their steps as a `phase` enum and switch in `body` (`ExportSheet.ExportPhase: settings / exporting / completed / failed`), with the phase views in a `+Phases.swift` extension. Sheets disable interactive dismissal while busy: `.interactiveDismissDisabled(phase == .exporting)`.

### 9.5 Properties panel tabs

`Editor/EditorTab.swift` is a `String`-backed `CaseIterable, Identifiable` enum with `label` and `icon`. `PropertiesPanel.body` switches on `selectedTab` and lists `xSection` properties; each tab's sections live in `PropertiesPanel+<Tab>Tab.swift`. Sidebar buttons (`EditorView+Sidebar.swift`) compute `disabled` per tab from `EditorState` capabilities.

```swift
// Reframed/Editor/PropertiesPanel.swift
        switch selectedTab {
        case .general:
          projectSection
        case .video:
          canvasSection
          paddingSection
          cornerRadiusSection
          videoShadowSection
          backgroundSection
```

Section layout is always `VStack(alignment: .leading, spacing: Layout.itemSpacing) { SectionHeader(icon:title:); control }`, with an optional right-aligned "Reset" button in an `HStack` when the value is non-default.

### 9.6 Keyboard shortcut plumbing

- `ShortcutAction` (`Utilities/KeyboardShortcut.swift`) enumerates every bindable action with `label`, `isSessionAction`, `isGlobal`, and `defaultShortcut`.
- `ConfigService.shortcut(for:)` returns the user override or the default; `SettingsShortcutsTab` edits them via `ShortcutRecorderButton`.
- Session actions are dispatched by `State/KeyboardShortcutManager.swift`: a local `NSEvent` monitor when focused plus a `CGEventTap` for global actions during recording (with `tapDisabledByTimeout` re-enable).
- Editor shortcuts are matched in `EditorWindow.setupKeyboardMonitor()`; unbindable transport keys are hard-coded by `keyCode` (49 space, 36 return, 53 escape).

```swift
// Reframed/Editor/EditorWindow.swift
      let undoShortcut = ConfigService.shared.shortcut(for: .editorUndo)
      let redoShortcut = ConfigService.shared.shortcut(for: .editorRedo)
      if redoShortcut.matches(event) {
        state.redo()
        return nil
      }
```

Text fields are protected by an early `firstResponder is NSTextView` check in both monitors.

---

## 10. Naming and style

### 10.1 Types and files

- One primary type per file, file named after the type; extensions in `Type+Concern.swift`; extensions on system types in `Utilities/<Type>+Extensions.swift` (`CGRect+Extensions.swift`, `NSScreen+Extensions.swift`).
- Suffix vocabulary: `*State` (observable models), `*Service` (singletons), `*Coordinator` (window/overlay managers), `*Capture` (input sources), `*Writer` (AVAssetWriter wrappers), `*Window` (NSWindow subclasses/controllers), `*View`/`*Overlay`/`*Layer`, `*Popover`, `*Sheet`, `*Row`, `*Tab`, `*Data` (Codable persistence), `*Settings` (value-type option bags), `*Info` (immutable computed descriptors).
- Enum namespaces for stateless function groups: `VideoCompositor`, `Permissions`, `LogBootstrap`, `EncodingSettings`, `GradientPresets`, `TailwindColors`, `Layout`, `FontSize`, `Radius`, `ZoomDetector`, `SubtitleExporter`, `CursorEffects`.

```swift
// Reframed/App/Permissions.swift
enum Permissions {
  static var hasScreenRecordingPermission: Bool {
    CGPreflightScreenCaptureAccess()
  }
  static func fetchShareableContent() async throws -> SCShareableContent {
    try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
  }
}
```

### 10.2 Enums as option lists

Every user-visible enum is `CaseIterable, Identifiable` with `var id: Self { self }` (or `rawValue` for `String`-backed), a `label`, and often `icon`/`description`. Single-expression `switch` bodies omit `return`:

```swift
// Reframed/Compositor/ExportSettings.swift
enum ExportResolution: Sendable, CaseIterable, Identifiable {
  case original
  case uhd4k
  case fhd1080
  case hd720

  var id: Self { self }

  var label: String {
    switch self {
    case .original: "Original"
    case .uhd4k: "4K"
    case .fhd1080: "1080p"
    case .hd720: "720p"
    }
  }
```

**Inconsistency.** Both `return`-less and `return`-ful switch styles coexist (`CaptureError.errorDescription`, `SoundEffect.soundName` use `return`), permitted by `"OmitExplicitReturns": false`. Prefer the `return`-less form in new code.

### 10.3 Functions and free functions

- Formatting and math helpers are **free functions** in `Utilities/` (`formatDuration`, `formatCompactTime`, `formatTimestamp`, `formatRelativeTime`, `smoothstep`), not extensions on `CMTime`/`Double`.
- File-private helpers are `private func` at file scope (`.swift-format` `fileScopedDeclarationPrivacy: private`), e.g. `private func cursorBinarySearch(...)` in `Editor/CursorMetadataProvider.swift`.
- Argument labels read as prose: `formatDuration(seconds:)`, `defaultSaveURL(for:extension:)`, `setRegions(_:for:)`, `updateRegionStart(trackType:regionId:newStart:)`.
- Setters that must run on a specific queue are named plainly and enforce the queue internally (`pause()`, `resume(withOffset:)`).

### 10.4 Access control

`private` is the only modifier in real use (751 occurrences, 2 `fileprivate`, no `internal`/`public`/`open` as access modifiers; the word `open` only appears as a method name such as `ReframedProject.open(at:)`). `private(set)` guards read-only state (`History.entries`, `DeviceDiscovery.availableDevices`). Model classes intentionally leave properties internal so `+Concern` extensions can reach them.

### 10.5 Formatting (from `.swift-format`)

2-space indent, 140-column lines, trailing commas in multi-line collections, one argument per line when wrapped (`lineBreakBeforeEachArgument`), max one blank line, no semicolons except in the `set { data.x = newValue; save() }` one-liners, `UseEarlyExits` off (but `guard` is still used pervasively). Run `make format` (`swift format -i -r Reframed/`) before every commit.

### 10.6 The no-comments rule

`AGENTS.md`/`CONTRIBUTING.md`: no inline or doc comments. The tree has 18 comment lines total.

**Inconsistency.** Existing violations: a four-line explanatory block at `Project/ProjectMetadata.swift:511-515`, 14 `// MARK:` lines in `Compositor/FrameRenderer+HDR.swift`, `Compositor/FrameRenderer+Helpers.swift`, `Project/ProjectMetadata.swift`, and a trailing `// 5 MB` in `Logging/RotatingFileLogHandler.swift`. Do not add more; the maintainers treat `// MARK:` as tolerated but not encouraged.

---

## 11. Anti-patterns (per `CONTRIBUTING.md`) and what to do instead

| Do not | Do instead | Where the good pattern lives |
|---|---|---|
| `.buttonStyle(.plain)`, `.borderless`, `.bordered`, `.link` | `PlainCustomButtonStyle()`, `OutlineButtonStyle(...)`, `PrimaryButtonStyle(...)`, `SecondaryButtonStyle(...)` | `UI/PrimaryButton.swift` |
| Literal `Color(...)`, `.font(.system(size: 13))`, `cornerRadius: 7` | `ReframedColors.*`, `FontSize.*`, `Radius.*`, `Layout.*` | `UI/Colors.swift`, `UI/Constants.swift` |
| A new time/size formatter inside a view | `formatDuration`, `formatPreciseDuration`, `formatCompactTime`, `formatRelativeTime` | `Utilities/TimeFormatting.swift` |
| A second `Codable` colour/size wrapper | `CodableColor`, `CodableSize` | `Utilities/CodableColor.swift`, `Project/ProjectMetadata.swift` |
| Inline `// explains why` comments | Rename the function/variable until it explains itself | rule in `AGENTS.md` |
| Band-aids (`DispatchQueue.main.asyncAfter` to "wait for" state, catching and ignoring the real error) | Fix the state machine or propagate the `CaptureError` | `SessionState.transition(to:)`, `CaptureError` |
| `ObservableObject` / `@Published` / `@StateObject` | `@Observable` + `@Bindable` | every model except `WindowController` |
| Growing a view file past ~200 lines | Split into `View+Section.swift` extensions | `PropertiesPanel+*.swift`, `TimelineView+*.swift` |
| `print(...)` | `logger.info/warning/error` with the `eu.jankuri.reframed.*` label | `Logging/LogBootstrap.swift` |
| `MainActor.run` from AppKit delegate callbacks | `MainActor.assumeIsolated { }` | `SessionState+Project.swift`, `AppDelegate.swift` |
| Unrelated new settings singletons | Add to `ConfigService` (persistent) or `StateService` (layout/session) | `State/ConfigService.swift` |

Two idioms in the tree look like workarounds but are the accepted pattern and should be copied, not "fixed": the `let _ = colorScheme` re-render trigger (Section 2.5), and the window-level flip used to bring new windows to the front (`window.level = .floating; makeKeyAndOrderFront; DispatchQueue.main.async { window.level = .normal }` in `App/AppDelegate.swift` and `Editor/EditorWindow.swift`).

---

## 12. Stale documentation to be aware of

- `AGENTS.md` names the config file `config.json`; it is `~/.reframed/reframed.json` (`State/ConfigService.swift:112`).
- `AGENTS.md` says `@unchecked Sendable` is used only by `ScreenCaptureSession`; there are 31 uses (Section 6.1).
- `AGENTS.md` calls `VideoTrackWriter` / `AudioTrackWriter` "actors"; both are `final class … @unchecked Sendable` guarded by a serial `DispatchQueue` (`Recording/VideoTrackWriter.swift:6`, `Recording/AudioTrackWriter.swift:5`). The only `actor` in the tree is `RecordingCoordinator`.
- `docs/export.md` describes `VideoCompositor.export()` as taking "40+ parameters"; it now takes `RecordingResult`, `ExportConfiguration`, and a progress closure (`Compositor/VideoCompositor.swift:14-18`).
- `docs/editor.md` says history persists in `history.json` inside the bundle — correct — but `docs/project-format.md` still lists the bundle without `background-image.*` / `camera-bg-image.*` files that `EditorState+Background.swift` writes.

*Patterns analysis: 2026-09-03*
