# Test plan: Lossless cut

Layers from `planning/tdd-strategy.md`. Full assertions in `docs/features/01-lossless-cut/ATTACK-PLAN.md`; this table tracks status.

| Spec # | Test | Layer | File | Fixture | Status |
|--------|------|-------|------|---------|--------|
| 1, 2 | `CutTimelineTests` split, no-op, min length, boundary, totals, flags, elapsed↔source, next slice, normalized, gaps, canCut, boundaryTimes | unit T1 | `ReframedTests/Editor/CutTimelineTests.swift` | none | green (21) |
| 5 | `RegionRemappingTests` video-cut path (camera split, 10 ms match, captions, spotlight, border scale) | unit T1 | `ReframedTests/Compositor/RegionRemappingTests.swift` | none | milestone 01 |
| 5 | `CompositionInstructionTests` sourceTime inside/outside mappings | unit T1 | `ReframedTests/Compositor/CompositionInstructionTests.swift` | none | milestone 01 |
| 7 | `ProjectMetadataTests` video regions round trip, legacy → nil | unit T1 | `ReframedTests/Project/ProjectMetadataTests.swift` | none | red |
| 7 | `HistoryChangeRulesTests` cut added/removed/adjusted, exactly one string | unit T1 @MainActor | `ReframedTests/Editor/HistoryChangeRulesTests.swift` | none | red |
| 7 | `EditorStateVideoRegionsTests` normalize on restore, undo after split, previewElapsedTime characterization, split keeps currentTime | EditorState T2 | `ReframedTests/Editor/EditorStateVideoRegionsTests.swift` | generated 2 s movie | red |
| 2 | `CutTimelineTests` showCutTrack gate | unit T1 | same as row 1 | none | green |
| 4 | `SyncedPlayerControllerTests` gapSkipDecision, observer skips gap in edit mode | T1 + T2 | `ReframedTests/Editor/SyncedPlayerControllerTests.swift` | generated 2 s movie | red |
| 4 | `EditorStatePlaybackTests` togglePlayPause from gap | T2 | `ReframedTests/Editor/EditorStatePlaybackTests.swift` | generated 2 s movie | red |
| 6 | `TimelineGeometryTests` compressed x↔source, region pieces, ruler | unit T1 | `ReframedTests/Editor/TimelineGeometryTests.swift` | none | red |
| 5 | `EditorStateExportTests` exportVideoRegions decision | unit T1 | `ReframedTests/Editor/EditorStateExportTests.swift` | none | red |
| 5 | `ExportPipelineTests` two-slice duration, camera region per segment | gated T2 | `ReframedTests/Compositor/ExportPipelineTests.swift` | generated movies | red |

## Manual checks

Only for what cannot be automated: track animation in/out, hover cursors on slice edges, visual absence of cut frames during playback, exported MP4/GIF plays with jumps where the timeline shows them. Recorded in `planning/milestones/02-lossless-cut/VERIFY.md`.
