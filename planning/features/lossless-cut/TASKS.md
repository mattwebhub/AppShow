# Tasks: Lossless cut

Phases from the attack plan. Each phase is one or more commits; every commit has its tests red first.

- [x] P1 Model + remap (S): `CutTimeline` pure type, `splitVideoRegion(atTime:)`, `clearVideoCuts()`, `EditorState` delegations, `showCutTrack`.
- [x] P4 Transport button (S): `IconButton` with `hand.point.up.left`, enabled by `canCut(at:)`.
- [x] P3 Cuts track (M): `TimelineView+CutTrack.swift`, Screen track plain bar, sidebar entry, height signature.
- [x] P5 Playback jumping (M): `gapSkipDecision`, `skipsGaps`, boundary observer, edit-mode gap handling, hidden screen in gaps.
- [x] P2 Persistence + history (S): change-rule strings, normalize on restore, round-trip tests.
- [ ] P7 Export verification, unit rows (M): `exportVideoRegions` extraction, seam S3 `outputDirectory`.
- [ ] P6 Compressed timeline (L): `TimelineGeometry`, display mode toggle, all tracks through one mapping.
- [ ] P7 gated end-to-end export run; docs (`docs/editor.md`, `AGENTS.md`), `upstream-sync.md` divergences, VERIFY.md.
