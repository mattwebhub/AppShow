# Test plan: Silence removal

Written before the production code. Layers from `planning/tdd-strategy.md`.

| Spec # | Test name | Layer | File | Fixture | Status |
|--------|-----------|-------|------|---------|--------|
| 3 | `rmsWindowsAverageEachWindow` | unit T1 | `ReframedTests/Editor/SilenceDetectorTests.swift` | none | red |
| 3 | `silentSpansFindGapsBelowRelativeThreshold` (10 s signal, silence at 3–5 and 8–10) | unit T1 | same | none | red |
| 3 | `silentSpansIgnoreGapsShorterThanMinimum` | unit T1 | same | none | red |
| 3 | `thresholdIsRelativeToPeakNotAbsolute` (same shape 20 dB quieter gives the same spans) | unit T1 | same | none | red |
| 3 | `allSilentSignalIsOneSpan`, `allLoudSignalHasNoSpans` | unit T1 | same | none | red |
| 4 | `keepSlicesPadSpeechEdges` (3–5 → keep ends at 3.15, next starts at 4.85) | unit T1 | same | none | red |
| 4 | `keepSlicesKeepRecordingEdgesUnpadded` (silence 8–10 → last slice ends at 8.15, nothing after) | unit T1 | same | none | red |
| 4 | `keepSlicesDropSlicesShorterThanMinimum` | unit T1 | same | none | red |
| 4 | `keepSlicesFromNoSilencesIsOneFullSlice`, `keepSlicesFromAllSilentIsEmpty` | unit T1 | same | none | red |
| 5 | `intersectKeepsExistingCutsAndSplitsAroundSilences` | unit T1 | same | none | red |
| 5 | `intersectPreservesTransitionsOnOuterPieces` | unit T1 | same | none | red |
| 2, 3 | `analyzeFindsGapInGeneratedTone` | T2 | `ReframedTests/Editor/SilenceAnalysisTests.swift` | `AudioFixtures.toneWithGap` (wav) | red |
| 3 | `analyzeMixesTwoSourcesByLouderWindow` | T2 | same | two `toneWithGap` files | red |
| 2 | `analyzeThrowsForMissingFile` | T2 | same | none | red |
| 2 | `previewReportsCountAndTotalWithoutMutating` | EditorState T2 | `ReframedTests/Editor/EditorStateSilenceRemovalTests.swift` | `recordingResult` + mic `toneWithGap` | red |
| 5, 6 | `applyWritesSlicesAndPushesOneLabelledSnapshot` | EditorState T2 | same | same | red |
| 6 | `undoAfterApplyRestoresPreviousSlices` | EditorState T2 | same | same | red |
| 5 | `applyIntersectsWithExistingCuts` | EditorState T2 | same | same | red |
| 7 | `previewWithNoAudioSourceIsEmpty` | EditorState T2 | same | `recordingResult` without audio | red |
| 6 | `historyEntryLabelSurvivesRoundTrip` | unit T1 | `ReframedTests/Editor/HistoryTests.swift` | none | red |

## Manual checks

Only for what cannot be automated:

- The Silences section is greyed out for a recording without audio (SwiftUI `disabled` state has no unit seam).
- After Apply the Cuts track animates in and playback jumps over the removed spans (track transition and player timing).
- The History popover row reads "Silences removed" and one ⌘Z restores the previous slices (popover rendering).
- Recorded in `planning/milestones/07-primitives/VERIFY.md`.
