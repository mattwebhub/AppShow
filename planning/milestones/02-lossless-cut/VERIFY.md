# Verify milestone 02

| Check | Command or steps | Expected | Result |
|-------|------------------|----------|--------|
| Builds | `make build` | exit 0, no new warnings | |
| Tests | `make test` | all green | |
| Gated export | `TEST_RUNNER_REFRAMED_RUN_EXPORT_TESTS=1 make test T=ExportPipelineTests` | green | |
| Lint, format | `make lint && make format && git diff --exit-code` | clean | |
| Pre-feature project | open a `.frm` made before this milestone | no Cuts track, no history entry | |
| Cut flow | `make dev`, record 10 s, cut twice, remove middle slice | Cuts track appears, gap dimmed, playback jumps | |
| Undo | undo twice | single slice, track animates out | |
| Export | MP4 and GIF from a three-slice project with zoom and captions | plays with jumps where shown, audio in sync | |
| Compressed | toggle compressed mode | ruler, playhead, regions aligned; no gap landing on scrub | |

Closed on: (date, commit, PR)
