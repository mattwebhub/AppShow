# 06 — Conventions Checklist (pre-PR)

Derived from `05-coding-patterns.md`. Run through the matching list before opening a PR. Paths are relative to `AppShow/`.

## Always

1. `make format` then `make build`; zero warnings.
2. No comments (`//`, `///`, `/* */`, `// MARK:`). Rename instead.
3. No stock button styles; use `PlainCustomButtonStyle`/`OutlineButtonStyle`/`PrimaryButtonStyle`/`SecondaryButtonStyle` from `UI/PrimaryButton.swift`.
4. Colours/sizes/radii only via `AppShowColors`, `FontSize`, `Radius`, `Layout` (`UI/Colors.swift`, `UI/Constants.swift`).
5. New view: `@Environment(\.colorScheme)` + `let _ = colorScheme` at top of `body`; split at ~200 lines into `View+Section.swift`.
6. New logger: `Logger(label: "com.mattwebhub.appshow.<kebab-name>")`, levels `info`/`warning`/`error` only, never `print`.
7. Errors: throw `CaptureError` (`State/CaptureState.swift`); surface with `SessionState.showError` (recording) or an inline `phase`/`errorMessage` (editor).
8. Concurrency: `@MainActor @Observable final class` for UI models, `actor` for pipeline owners, `@unchecked Sendable` only with a serial queue + `dispatchPrecondition` or all-`let` members; `MainActor.assumeIsolated` in AppKit callbacks.
9. Codable: new fields optional or `decodeOrDefault(...)` in an `extension X { init(from:) }`; string-backed enums; `CodableColor`/`CodableSize` for CG types.

## Adding a new editor property (e.g. `videoBorderWidth`)

1. `Editor/EditorState.swift` — stored `var` with default, grouped with its concern.
2. `Project/ProjectMetadata.swift` — field on `EditorStateData` (optional) or on the matching `*SettingsData` struct with a default **and** a `decodeOrDefault` line in that struct's `init(from:)` extension.
3. `Editor/EditorState+Persistence.swift` — emit in `createSnapshot()`, apply in `restoreFromSnapshot(_:)`, add `_ = self.<prop>` to `observeChanges()`.
4. `Editor/EditorState.swift` — apply on load in `init(project:)` (canvas/camera/caption family) or `setup()` (cursor/zoom/audio/region family); mirror an existing sibling.
5. `Editor/History+ChangeRules.swift` — add a `prop`/`toggle`/`sub`/`subToggle`/`regions` rule with a user-readable string.
6. `Compositor/ExportConfiguration.swift` — field with default; `Editor/EditorState+Export.swift` — pass it in the `ExportConfiguration(...)` call.
7. `Compositor/CompositionInstruction.swift` — `let` field + `init` parameter with default; `Compositor/VideoCompositor+InstructionBuilder.swift` — convert to pixel space and pass it.
8. `Compositor/FrameRenderer+<Stage>.swift` — draw it in the SDR path; `FrameRenderer+HDR.swift` if it affects the HDR path.
9. `Editor/VideoPreviewView.swift` + `VideoPreviewView+Update.swift` (+ `VideoPreviewContainer+<Stage>.swift`) — mirror it in the live preview; `Editor/EditorView+Preview.swift` — pass it from `editorState`.
10. `Editor/PropertiesPanel+<Tab>Tab.swift` — a `SectionHeader` + `SliderRow`/`ToggleRow`/`SegmentPicker` bound to `$editorState.<prop>`, optional Reset button using `PlainCustomButtonStyle()`.
11. If it should skip the compositor when default, extend `checkNeedsCompositor` in `VideoCompositor+InstructionBuilder.swift`.
12. Open an old `.frm` project and confirm it still loads, undo describes the change, and export matches preview.

## Adding a new setting (app preference)

1. `State/ConfigService.swift` — field with default in `private struct ConfigData`, get/set property calling `save()`; enums stored as `String` raw values.
2. If it affects recording: `State/RecordingOptions.swift` — property with `didSet { ConfigService.shared.x = ... }` and read in `init()`.
3. Thread the value: `State/SessionState+Recording.swift` (`options.x`) → `Recording/RecordingCoordinator+Screen.swift` / `+Device.swift` parameter → `Recording/ScreenCaptureSession.swift` / `Recording/VideoTrackWriter.swift` / `Utilities/EncodingSettings.swift`.
4. UI: `UI/Settings<General|Recording|Devices>Tab.swift` via `settingsToggle(_:isOn:)` or `settingsRow(label:) { SegmentPicker(...) }` bound with `Binding(get: { options?.x ?? default }, set: { options?.x = $0 })`; or a `CheckmarkRow` group in `UI/OptionsPopover.swift` for toolbar-level options.
5. Session-layout state (positions, last selection) goes to `State/StateService.swift`, not `ConfigService`.
6. Persisting per-project: add to `ProjectMetadata` in `Project/AppShowProject.create(...)` and read back in `AppShowProject.recordingResult` / `RecordingResult`.

## Adding a new capture mode

1. `State/CaptureMode.swift` — new `case` with explicit string raw value (persisted in `project.json`).
2. `Recording/CaptureTarget.swift` — new case if the target type differs from `.region`/`.window`; implement `displayID`.
3. `State/SessionState+Selection.swift` — handle the case in `selectMode(_:)`, add `start<Mode>Selection()` and `confirm<Mode>Selection(...)`, set `captureTarget`, then `beginRecordingWithCountdown()`.
4. `Recording/RecordingCoordinator+<Mode>.swift` — new extension file with `start<Mode>Recording(...)` mirroring `+Screen.swift` (verify devices first, build `SharedRecordingClock`, create writers, configure `CursorMetadataRecorder`); reuse `stopRecordingRaw` in `+Lifecycle.swift`.
5. Overlay/selection UI: new `CaptureModes/Capture<Mode>/` folder with a `@MainActor final class <Mode>SelectionCoordinator` and NSWindow/NSView overlay, following `CaptureModes/Common/SelectionCoordinator.swift`.
6. Toolbar: `UI/CaptureToolbar+ModeSelection.swift` — a `ModeButton(icon:label:isSelected:)` calling `session.selectMode(.x)` with `.hoverEffect(id: "mode.x")`.
7. `Utilities/KeyboardShortcut.swift` — optional `ShortcutAction.switchTo<Mode>` with `label`, `isSessionAction`, `isGlobal`, `defaultShortcut`; dispatch in `State/KeyboardShortcutManager.swift`.
8. `Project/AppShowProject.projectPrefix(captureMode:sourceName:)` — bundle-name prefix; `State/SessionState+Project.projectSourceName()` — source label.
9. `Utilities/MenuBarIcon.swift` / `SessionState.updateStatusIcon()` if the mode needs a distinct menu-bar state.

## Adding a new export option

1. `Compositor/ExportSettings.swift` — new field on `ExportSettings` with default, or new case on `ExportFormat`/`ExportCodec`/`ExportFPS`/`ExportResolution`/`ExportAudioBitrate` with `label`, `description`, and the value accessor (`fileType`, `videoCodecType`, `pixelWidth`, `value`).
2. `ExportPreset.settings` in the same file — decide what each platform preset uses.
3. `Compositor/ExportSheet.swift` — a `settingsRow(label:) { SegmentPicker(items: X.allCases, label: { $0.label }, selection: manualBinding(\.x)) }` plus a description `Text` under it; `ExportSheet+Phases.swift` if the export/completed phase changes.
4. `Compositor/VideoCompositor.swift` — read `config.exportSettings.x` in `export(...)` and route to `+ManualExport`, `+ParallelExport`, or `+GIFExport`; update `checkNeedsCompositor` in `+InstructionBuilder.swift` if the option can bypass rendering.
5. `Utilities/EncodingSettings.exportVideoSettings(...)` for codec/bitrate/colour changes; `Compositor/VideoCompositor+Audio.swift` for audio mix changes.
6. Sidecar outputs follow `Utilities/SubtitleExporter.swift` and are written next to the URL returned from `export` in `Editor/EditorState+Export.swift`.
7. Output naming/location goes through `FileManager.default.defaultSaveURL(for:extension:)` (`Recording/FileManager+AppShow.swift`) via `MainActor.run`.
8. Test one passthrough export (no effects) and one composited export in both `.parallel` and `.normal` modes.
