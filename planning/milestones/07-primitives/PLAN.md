# Milestone 07: primitives

Goal: the editor gains the primitives the agent tools need, each shipped first as a hand-operated feature with tests: silence removal, text overlay, image overlay, blur region, and transitions.

Depends on: milestone 02 (keep-slices and the Cuts track) for silence removal; milestones 03 to 06 for the tool wrappers, which are not part of this milestone.

## Tasks

Silence removal mirrors `planning/features/silence-removal/TASKS.md` and text overlays mirror `planning/features/text-overlays/TASKS.md`; tick both.

- [x] T1. Silence removal, pure detector. Proof: `ReframedTests/Editor/SilenceDetectorTests.swift` green.
- [x] T2. Silence removal, PCM analysis of a real file. Proof: `ReframedTests/Editor/SilenceAnalysisTests.swift` green on generated tones.
- [x] T3. Silence removal, editor wiring and labelled history entry. Proof: `ReframedTests/Editor/EditorStateSilenceRemovalTests.swift` and the `HistoryTests` label round trip green.
- [x] T4. Silence removal, Silences section in the Video tab. Proof: `make build` warning-free, manual rows in `VERIFY.md`.
- [x] T5. Text overlay primitive (`docs/features/04-agent-tools/ATTACK-PLAN.md` phase 6; `planning/features/text-overlays/`). Proof: `TextOverlayLayoutTests`, the overlay rows in `RegionRemappingTests`, `InstructionBuilderTests` and `FrameRendererGoldenTests`, `TextOverlayDataTests` (`project.json` decode), `EditorStateTextOverlaysTests`, and the overlay rule in `HistoryChangeRulesTests` green; Overlays track, popover and Effects-tab section built warning-free, manual rows in `VERIFY.md`.
- [ ] T6. Image overlay primitive (phase 7, after T5). Proof: golden-frame test, bundle copy test.
- [ ] T7. Blur region primitive (phase 8). Proof: golden-frame test that the region differs from the source and its surroundings do not.
- [ ] T8. Transitions on overlays and keep-slices. Proof: `RegionRemappingTests` and golden frames at transition midpoints.
- [ ] T9. Docs and divergences: `planning/upstream-sync.md`, `docs/architecture/07-testability.md` if a seam is added. Proof: grep.

## Out of scope

The MCP tool wrappers (`get_silences`, `remove_silences`, `add_text`, ...) belong to milestones 05 and 06. Protecting silences that contain clicks or transcript words is a skill concern, not a detector concern. Detector settings are not persisted.

## Risks

- A decoded file read whole would hold minutes of float PCM in memory; the analysis reads in chunks and keeps only one RMS value per window.
- AAC decoding pads the first frames; the tests tolerate 0.1 s at span edges so a codec change does not break them.
- Overlay primitives touch the 12 sites in `docs/architecture/06-conventions-checklist.md`; land each behind its own tests and commit series.
