# Tasks: Silence removal

Ordered red-green-refactor steps. One commit per step is the default.

- [x] 1. Planning docs: this folder and `planning/milestones/07-primitives/`.
- [x] 2. Red: `AppShowTests/Editor/SilenceDetectorTests.swift` (RMS windows, spans, padding, minimum length, slices, intersection, edge cases, relative threshold); `make test T=SilenceDetectorTests` fails to compile. Green: `AppShow/Editor/SilenceDetector.swift` (`SilenceDetectorConfig`, `rmsWindows`, `silentSpans`, `keepSlices`, `intersect`), registered in the project. `make format`, `make lint`.
- [x] 3. Red: `AudioFixtures.toneWithGap` helper plus `AppShowTests/Editor/SilenceAnalysisTests.swift` (gap in a generated tone, two-source mix, missing file). Green: `AppShow/Editor/SilenceAnalysis.swift` reading `AVAudioFile` in chunks.
- [x] 4. Red: `HistoryTests` label round trip and `AppShowTests/Editor/EditorStateSilenceRemovalTests.swift` (preview, apply, undo, intersection, no audio). Green: `HistoryEntry.label`, `History.pushSnapshot(_:label:)`, `HistoryPopover` label, `AppShow/Editor/EditorState+SilenceRemoval.swift`.
- [x] 5. UI: `AppShow/Editor/PropertiesPanel+SilencesSection.swift` (`SilenceRemovalSection`) wired into the Video tab; `make build` warning-free; manual checks recorded in the milestone `VERIFY.md`.
