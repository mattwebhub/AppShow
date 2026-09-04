# Tasks: Lossless cut

Phases from the attack plan. Each phase is one or more commits; every commit has its tests red first.

- [x] P1 Model + remap (S): `CutTimeline` pure type, `splitVideoRegion(atTime:)`, `clearVideoCuts()`, `EditorState` delegations, `showCutTrack`.
- [x] P4 Transport button (S): `IconButton` with `hand.point.up.left`, enabled by `canCut(at:)`.
- [x] P3 Cuts track (M): `TimelineView+CutTrack.swift`, Screen track plain bar, sidebar entry, height signature.
- [x] P5 Playback jumping (M): `gapSkipDecision`, `skipsGaps`, boundary observer, edit-mode gap handling, hidden screen in gaps.
- [x] P2 Persistence + history (S): change-rule strings, normalize on restore, round-trip tests.
- [x] P7 Export verification, unit rows (M): `exportVideoRegions` extraction, seam S3 `outputDirectory`.
- [x] P6 Compressed timeline (L): `TimelineGeometry`, display mode toggle, all tracks through one mapping.
- [x] P7 gated end-to-end export run (`ExportPipelineTests`, 2 tests); docs (`docs/editor.md`, `AGENTS.md`), `upstream-sync.md` divergences. VERIFY.md automated rows recorded; manual rows need a human.

## Manual checks for a human (compressed mode)

1. Two cuts, remove the middle slice: the toggle appears after the cut button; toggling hides gaps, the ruler ends at the kept total, and playhead, waveform, zoom, camera, and spotlight regions align with the slices.
2. Scrub and drag the playhead in compressed mode: the readout never enters a gap; landing on a seam jumps to the next slice.
3. Play in compressed mode: the playhead crosses seams continuously.
4. Drag a slice edge in compressed mode: the timeline re-flows live and settles without a jump; the slice body does not move.
5. Other tracks in compressed mode: no double-click add, drag, or right-click; a region spanning a cut shows a thin seam. Back in source mode everything behaves as before.
6. Remove the last cut or undo to one slice: the track animates out, the mode returns to source, the toggle disappears.
