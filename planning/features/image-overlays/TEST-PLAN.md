# Test plan: Image overlays

Written before the production code. Layers from `planning/tdd-strategy.md`.

| Spec # | Test name | Layer | File | Fixture | Status |
|--------|-----------|-------|------|---------|--------|
| 10 | `defaultsFillEveryOptionalField` (JSON with start, end and filename decodes with the declared defaults) | unit T1 | `ReframedTests/Project/ImageOverlayDataTests.swift` | none | red |
| 10 | `roundTripPreservesEveryField` | unit T1 | same | none | red |
| 10 | `unknownPositionAndTransitionFallBackToDefaults` | unit T1 | same | none | red |
| 10 | `editorStateWithoutImageOverlaysDecodesToNil` | unit T1 | same | `legacyV1ProjectJSON` | red |
| 2 | `importCopiesTheFileUnderItsHashName` (generated PNG, name matches `image-<hash8>.png`, pixel size reported) | integration T2 | `ReframedTests/Project/ImageOverlayImporterTests.swift` | PNG drawn with `CGContext` | red |
| 2 | `importingTheSameBytesTwiceReusesTheFile` | integration T2 | same | same | red |
| 2 | `importRejectsAFileThatIsNotAnImage` | integration T2 | same | text file named `.png` | red |
| 2 | `importRejectsAnUnsupportedExtension` | integration T2 | same | none | red |
| 4 | `loadImageDecodesTheFirstFrame` | integration T2 | same | same PNG | red |
| 6 | `addOverlayFromFileCreatesThreeSecondRegionWithTheFileInTheBundle` | EditorState T2 | `ReframedTests/Editor/EditorStateImageOverlaysTests.swift` | `ReframedProject.create(..., cleanupTemp: false)` | red |
| 6 | `addOverlayNearEndIsPulledBackAndClamped` | EditorState T2 | same | same | red |
| 6 | `addOverlayFromAnUnreadableFileAddsNothing` | EditorState T2 | same | same | red |
| 7 | `updateOverlayChangesFields` | EditorState T2 | same | same | red |
| 5 | `moveAndResizeClampToDurationAndMinimumLength` | EditorState T2 | same | same | red |
| 10 | `removeOverlayKeepsTheFile` | EditorState T2 | same | same | red |
| 10 | `snapshotRoundTripRestoresOverlays` | EditorState T2 | same | same | red |
| 10 | `reopeningDropsOverlaysWhoseFileIsMissing` | EditorState T2 | same | same | red |
| 7 | `overlayTrackShowsForImageOverlaysAlone` | EditorState T2 | same | same | red |
| 10 | `imageOverlayChangesAreDescribedAsAddedRemovedAdjusted` | unit T1 | `ReframedTests/Editor/HistoryChangeRulesTests.swift` | none | red |
| 3 | `widthFractionAndAspectGiveThePixelSize` (1920×1080) | unit T1 | `ReframedTests/Compositor/ImageOverlayLayoutTests.swift` | none | red |
| 3 | `tallImageIsScaledDownToFitTheCanvas` | unit T1 | same | none | red |
| 3 | `centerPresetCentresTheImage` | unit T1 | same | none | red |
| 3 | `cornerPresetsSitAtTheMargin` (`@Test(arguments:)` over the six edge presets) | unit T1 | same | none | red |
| 3 | `offsetMovesAndClampsTheImage` | unit T1 | same | none | red |
| 3 | `resolvedInstructionCarriesPixelLayout` | unit T1 | same | none | red |
| 8 | `imageOverlayIsClippedAndShiftedByTrimStart` | unit T1 | `ReframedTests/Compositor/RegionRemappingTests.swift` | none | red |
| 8 | `imageOverlaySpanningTwoSegmentsIsSplitWithFreshIds` | unit T1 | same | none | red |
| 8 | `imageOverlayNeedsCompositor` | unit T1 | `ReframedTests/Compositor/InstructionBuilderTests.swift` | none | red |
| 4 | `imageOverlayCoversTheCentre` (64×36, solid 8×8 generated image at the centre, centre pixel dominated by it, pixel (1,1) unchanged) | golden T2 | `ReframedTests/Compositor/FrameRendererGoldenTests.swift` | none | red |
| 4 | `imageOverlayIsAbsentAtTransitionProgressZero` | golden T2 | same | none | red |
| 4 | `imageOverlayIsAbsentOutsideItsRange` | golden T2 | same | none | red |

## Manual checks

Only for what cannot be automated:

- "Add Image" opens the file panel limited to images; cancelling adds nothing; choosing a PNG with transparency shows it over the video with the transparent parts see-through, in the preview and in the export.
- The chip on the Overlays track shows the `photo` icon and the source file name beside text chips; right-click opens the image popover; width, corners, opacity, shadow and position update the preview live.
- Fade, scale and slide play in the preview and in the export at the same moments; the exported frame matches the preview.
- Copy the `.frm` to another folder and reopen: the image still shows. Delete the `image-*.png` from the bundle and reopen: the overlay is gone and the log carries a warning.
- Recorded in `planning/milestones/07-primitives/VERIFY.md`.
