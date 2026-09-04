# Test plan: Text overlays

Written before the production code. Layers from `planning/tdd-strategy.md`.

| Spec # | Test name | Layer | File | Fixture | Status |
|--------|-----------|-------|------|---------|--------|
| 9 | `defaultsFillEveryOptionalField` (JSON with only start and end decodes with the declared defaults) | unit T1 | `ReframedTests/Project/TextOverlayDataTests.swift` | none | red |
| 9 | `roundTripPreservesEveryField` | unit T1 | same | none | red |
| 9 | `unknownPositionAndWeightFallBackToDefaults` | unit T1 | same | none | red |
| 9 | `editorStateWithoutOverlaysDecodesToNil` | unit T1 | same | `legacyV1ProjectJSON` | red |
| 5 | `addOverlayAtTimeCreatesThreeSecondRegion` | EditorState T2 | `ReframedTests/Editor/EditorStateTextOverlaysTests.swift` | `recordingResult` (2 s) | red |
| 5 | `addOverlayNearEndIsPulledBackAndClamped` | EditorState T2 | same | same | red |
| 4 | `overlaysMayOverlapInTime` | EditorState T2 | same | same | red |
| 6 | `updateOverlayChangesFields` | EditorState T2 | same | same | red |
| 4 | `moveAndResizeClampToDurationAndMinimumLength` | EditorState T2 | same | same | red |
| 6 | `removeOverlayDeletesIt` | EditorState T2 | same | same | red |
| 9 | `snapshotRoundTripRestoresOverlays` | EditorState T2 | same | same | red |
| 9 | `overlayChangesAreDescribedAsAddedRemovedAdjusted` | unit T1 | `ReframedTests/Editor/HistoryChangeRulesTests.swift` | none | red |
| 2 | `centerPresetCentresThePill` (1920×1080) | unit T1 | `ReframedTests/Compositor/TextOverlayLayoutTests.swift` | none | red |
| 2 | `cornerPresetsSitAtTheMargin` (`@Test(arguments:)` over the six edge presets) | unit T1 | same | none | red |
| 2 | `offsetMovesThePillByCanvasFractions` | unit T1 | same | none | red |
| 2 | `offsetIsClampedInsideTheCanvas` | unit T1 | same | none | red |
| 2 | `fontPixelSizeScalesWithCanvasHeight` | unit T1 | same | none | red |
| 2 | `longTextWrapsWithinMaxWidthAndGrowsInHeight` | unit T1 | same | none | red |
| 2 | `resolvedInstructionCarriesPixelLayout` | unit T1 | same | none | red |
| 7 | `textOverlayIsClippedAndShiftedByTrimStart` | unit T1 | `ReframedTests/Compositor/RegionRemappingTests.swift` | none | red |
| 7 | `textOverlaySpanningTwoSegmentsIsSplitWithFreshIds` | unit T1 | same | none | red |
| 7 | `textOverlayNeedsCompositor` | unit T1 | `ReframedTests/Compositor/InstructionBuilderTests.swift` | none | red |
| 3 | `textOverlayPillCoversTheCentre` (64×36, pill and text in one colour, centre pixel dominated by it, pixel (1,1) unchanged) | golden T2 | `ReframedTests/Compositor/FrameRendererGoldenTests.swift` | none | red |
| 3 | `textOverlayIsAbsentAtTransitionProgressZero` | golden T2 | same | none | red |
| 3 | `textOverlayIsAbsentOutsideItsRange` | golden T2 | same | none | red |

## Manual checks

Only for what cannot be automated:

- The Overlays track animates in after "Add Text" and the chip text truncates with the chip width (SwiftUI layout).
- Right-click on a chip opens the popover; editing the text updates the preview live; the preview pill matches the exported frame at the same time (two render paths, compared by eye).
- Fade and slide transitions play in the preview and in the export at the same moments.
- Recorded in `planning/milestones/07-primitives/VERIFY.md`.
