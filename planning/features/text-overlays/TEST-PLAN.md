# Test plan: Text overlays

Written before the production code. Layers from `planning/tdd-strategy.md`.

| Spec # | Test name | Layer | File | Fixture | Status |
|--------|-----------|-------|------|---------|--------|
| 9 | `defaultsFillEveryOptionalField` (JSON with only start and end decodes with the declared defaults) | unit T1 | `AppShowTests/Project/TextOverlayDataTests.swift` | none | green |
| 9 | `roundTripPreservesEveryField` | unit T1 | same | none | green |
| 9 | `unknownPositionAndWeightFallBackToDefaults` | unit T1 | same | none | green |
| 9 | `editorStateWithoutOverlaysDecodesToNil` | unit T1 | same | `legacyV1ProjectJSON` | green |
| 5 | `addOverlayAtTimeCreatesThreeSecondRegion` | EditorState T2 | `AppShowTests/Editor/EditorStateTextOverlaysTests.swift` | `VideoFixtures.screenMovie(duration: 6)` | green |
| 5 | `addOverlayNearEndIsPulledBackAndClamped` | EditorState T2 | same | same | green |
| 4 | `overlaysMayOverlapInTime` | EditorState T2 | same | same | green |
| 6 | `updateOverlayChangesFields` | EditorState T2 | same | same | green |
| 4 | `moveAndResizeClampToDurationAndMinimumLength` | EditorState T2 | same | same | green |
| 6 | `removeOverlayDeletesIt` | EditorState T2 | same | same | green |
| 9 | `snapshotRoundTripRestoresOverlays` | EditorState T2 | same | same | green |
| 9 | `overlayChangesAreDescribedAsAddedRemovedAdjusted` | unit T1 | `AppShowTests/Editor/HistoryChangeRulesTests.swift` | none | green |
| 2 | `centerPresetCentresThePill` (1920×1080) | unit T1 | `AppShowTests/Compositor/TextOverlayLayoutTests.swift` | none | green |
| 2 | `cornerPresetsSitAtTheMargin` (`@Test(arguments:)` over the six edge presets) | unit T1 | same | none | green |
| 2 | `offsetMovesThePillByCanvasFractions` | unit T1 | same | none | green |
| 2 | `offsetIsClampedInsideTheCanvas` | unit T1 | same | none | green |
| 2 | `fontPixelSizeScalesWithCanvasHeight` | unit T1 | same | none | green |
| 2 | `longTextWrapsWithinMaxWidthAndGrowsInHeight` | unit T1 | same | none | green |
| 2 | `resolvedInstructionCarriesPixelLayout` | unit T1 | same | none | green |
| 7 | `textOverlayIsClippedAndShiftedByTrimStart` | unit T1 | `AppShowTests/Compositor/RegionRemappingTests.swift` | none | green |
| 7 | `textOverlaySpanningTwoSegmentsIsSplitWithFreshIds` | unit T1 | same | none | green |
| 7 | `textOverlayNeedsCompositor` | unit T1 | `AppShowTests/Compositor/InstructionBuilderTests.swift` | none | green |
| 3 | `textOverlayPillCoversTheCentre` (64×36, pill and text in one colour, centre pixel dominated by it, pixel (1,1) unchanged) | golden T2 | `AppShowTests/Compositor/FrameRendererGoldenTests.swift` | none | green |
| 3 | `textOverlayIsAbsentAtTransitionProgressZero` | golden T2 | same | none | green |
| 3 | `textOverlayIsAbsentOutsideItsRange` | golden T2 | same | none | green |

## Manual checks

Only for what cannot be automated:

- The Overlays track animates in after "Add Text" and the chip text truncates with the chip width (SwiftUI layout).
- Right-click on a chip opens the popover; editing the text updates the preview live; the preview pill matches the exported frame at the same time (two render paths, compared by eye).
- Fade and slide transitions play in the preview and in the export at the same moments.
- Recorded in `planning/milestones/07-primitives/VERIFY.md`.
