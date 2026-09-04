# Milestone 02: lossless-cut

Goal: a user can split the recording at the playhead, keep only chosen slices on a Cuts track, watch them play as one continuous video in the editor, and export exactly those slices.

Depends on: milestone 01 (fixtures, region-remap tests, `CompositionInstruction` tests).

## Tasks

Mirror of `planning/features/lossless-cut/TASKS.md`; tick both.

- [x] T1. P1 model + remap. Proof: `CutTimelineTests` green, `EditorState` delegations compile with no behavior change (`previewElapsedTime` characterization).
- [ ] T2. P4 transport button. Proof: `canCut` tests, manual check of enabled state.
- [ ] T3. P3 Cuts track. Proof: `showCutTrack`/`gaps` tests; manual animation check.
- [ ] T4. P5 playback jumping. Proof: `SyncedPlayerControllerTests`, `EditorStatePlaybackTests`.
- [ ] T5. P2 persistence + history. Proof: `ProjectMetadataTests`, `HistoryChangeRulesTests`, `EditorStateVideoRegionsTests`.
- [ ] T6. P7 unit rows + seam S3. Proof: `EditorStateExportTests`.
- [ ] T7. P6 compressed timeline. Proof: `TimelineGeometryTests`, manual alignment check.
- [ ] T8. P7 gated export run. Proof: `TEST_RUNNER_REFRAMED_RUN_EXPORT_TESTS=1 make test T=ExportPipelineTests`.
- [ ] T9. Docs and divergences: `docs/editor.md`, `AGENTS.md`, `planning/upstream-sync.md`, `docs/architecture/07-testability.md` seams. Proof: grep.
- [ ] T10. VERIFY.md run, branch pushed, PR opened, URL recorded.

## Out of scope

Literal passthrough export (optional phase 8), editing other tracks in compressed mode, ripple edits of audio regions.

## Risks

- Boundary observers and the 60 Hz periodic observer can both fire at a slice end; the decision function must be idempotent.
- Compressed mode touches every timeline file; land it last and behind the toggle.
