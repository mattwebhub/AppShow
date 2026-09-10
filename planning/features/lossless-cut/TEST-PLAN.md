# Test plan: Lossless cut

Layers from `planning/tdd-strategy.md`. Full assertions in `docs/features/01-lossless-cut/ATTACK-PLAN.md`; this table tracks status.

| Spec # | Test | Layer | File | Fixture | Status |
|--------|------|-------|------|---------|--------|
| 1, 2 | `CutTimelineTests` split, no-op, min length, boundary, totals, flags, elapsed↔source, next slice, normalized, gaps, canCut, boundaryTimes | unit T1 | `AppShowTests/Editor/CutTimelineTests.swift` | none | green (21) |
| 5 | `RegionRemappingTests` video-cut path (camera split, 10 ms match, captions, spotlight, border scale) | unit T1 | `AppShowTests/Compositor/RegionRemappingTests.swift` | none | milestone 01 |
| 5 | `CompositionInstructionTests` sourceTime inside/outside mappings | unit T1 | `AppShowTests/Compositor/CompositionInstructionTests.swift` | none | milestone 01 |
| 7 | `ProjectMetadataTests` video regions round trip, legacy → nil | unit T1 | `AppShowTests/Project/ProjectMetadataTests.swift` | none | green (milestone 01 full round trip covers video regions) |
| 7 | `HistoryChangeRulesTests` cut added/removed/adjusted, exactly one string | unit T1 @MainActor | `AppShowTests/Editor/HistoryChangeRulesTests.swift` | none | green (3) |
| 7 | `EditorStateVideoRegionsTests` normalize on restore, undo after split, previewElapsedTime characterization, split keeps currentTime | EditorState T2 | `AppShowTests/Editor/EditorStateVideoRegionsTests.swift` | generated 2 s movie | green (5) |
| 2 | `CutTimelineTests` showCutTrack gate | unit T1 | same as row 1 | none | green |
| 4 | `SyncedPlayerControllerTests` gapSkipDecision, observer skips gap in edit mode | T1 + T2 | `AppShowTests/Editor/SyncedPlayerControllerTests.swift` | generated 2 s movie | T1 green (4); the periodic-observer T2 row is covered by the boundary observer design and the manual playback check, not automated (no sleeps rule) |
| 4 | `EditorStatePlaybackTests` togglePlayPause from gap, skipsGaps sync | T2 | `AppShowTests/Editor/EditorStatePlaybackTests.swift` | generated 2 s movie | green (2) |
| 6 | `TimelineGeometryTests` compressed x↔source, region pieces, ruler | unit T1 | `AppShowTests/Editor/TimelineGeometryTests.swift` | none | green (13) |
| 5 | `EditorStateExportTests` exportVideoRegions decision | unit T1 | `AppShowTests/Editor/EditorStateExportTests.swift` | none | green (4) |
| 5 | `ExportPipelineTests` two-slice duration, full-slice duration | gated T2 | `AppShowTests/Compositor/ExportPipelineTests.swift` | generated movies | green (2, `TEST_RUNNER_APPSHOW_RUN_EXPORT_TESTS=1`); camera-per-segment pixel check deferred |

## Manual checks

Only for what cannot be automated: track animation in/out, hover cursors on slice edges, visual absence of cut frames during playback, exported MP4/GIF plays with jumps where the timeline shows them. Recorded in `planning/milestones/02-lossless-cut/VERIFY.md`.
