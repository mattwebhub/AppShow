# Tasks: Silence removal

Ordered red-green-refactor steps. One commit per step is the default.

- [x] 1. Planning docs: this folder and `planning/milestones/07-primitives/`.
- [x] 2. Red: `ReframedTests/Editor/SilenceDetectorTests.swift` (RMS windows, spans, padding, minimum length, slices, intersection, edge cases, relative threshold); `make test T=SilenceDetectorTests` fails to compile. Green: `Reframed/Editor/SilenceDetector.swift` (`SilenceDetectorConfig`, `rmsWindows`, `silentSpans`, `keepSlices`, `intersect`), registered in the project. `make format`, `make lint`.
- [x] 3. Red: `AudioFixtures.toneWithGap` helper plus `ReframedTests/Editor/SilenceAnalysisTests.swift` (gap in a generated tone, two-source mix, missing file). Green: `Reframed/Editor/SilenceAnalysis.swift` reading `AVAudioFile` in chunks.
- [x] 4. Red: `HistoryTests` label round trip and `ReframedTests/Editor/EditorStateSilenceRemovalTests.swift` (preview, apply, undo, intersection, no audio). Green: `HistoryEntry.label`, `History.pushSnapshot(_:label:)`, `HistoryPopover` label, `Reframed/Editor/EditorState+SilenceRemoval.swift`.
- [ ] 5. UI: `Reframed/Editor/PropertiesPanel+SilencesSection.swift` (`SilenceRemovalSection`) wired into the Video tab; `make build` warning-free; manual checks recorded in the milestone `VERIFY.md`.
