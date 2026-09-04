# Verify milestone 02

| Check | Command or steps | Expected | Result |
|-------|------------------|----------|--------|
| Builds | `make build` | exit 0, no new warnings | pass |
| Tests | `make test` | all green | pass, 272 tests in 27 suites |
| Gated export | `TEST_RUNNER_REFRAMED_RUN_EXPORT_TESTS=1 make test T=ExportPipelineTests` | green | pass (2) |
| Lint, format | `make lint && make format && git diff --exit-code` | clean | pass |
| Pre-feature project | open a `.frm` made before this milestone | no Cuts track, no history entry | |
| Cut flow | `make dev`, record 10 s, cut twice, remove middle slice | Cuts track appears, gap dimmed, playback jumps | |
| Undo | undo twice | single slice, track animates out | |
| Export | MP4 and GIF from a three-slice project with zoom and captions | plays with jumps where shown, audio in sync | |
| Compressed | toggle compressed mode | ruler, playhead, regions aligned; no gap landing on scrub | |

Manual rows (pre-feature project, cut flow, undo, export audition, compressed alignment) need a human with the app; steps for compressed mode are in the P6 report summarized in `planning/features/lossless-cut/TASKS.md`.

CI: pass on PR #3.

Closed on: pending manual checks; PR https://github.com/mattwebhub/Reframed/pull/3
