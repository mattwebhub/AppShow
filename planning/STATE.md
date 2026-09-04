# State

Last updated: 2026-09-04

## Position

- Milestone 00 closed except the product-identity decision: PR #1 https://github.com/mattwebhub/Reframed/pull/1 (CI green).
- Milestone 01 test-foundation complete: 218 tests, PR #2 https://github.com/mattwebhub/Reframed/pull/2 (stacked on fork-setup).
- Milestone 02 lossless-cut complete on the code side: 272 tests in 27 suites plus 2 gated export tests, PR #3 https://github.com/mattwebhub/Reframed/pull/3. Manual checks in its VERIFY.md need a human with the app.
- Milestone 03 music-tracks on branch `milestone-03-music-tracks`: phases 0 to 3 in progress by a delegated worktree.
- Milestone 07 primitives started early with its first task group, silence removal, on a worktree branch stacked on milestone 02: T1 to T4 green (`planning/features/silence-removal/`), 305 tests in 30 suites. Manual rows in `planning/milestones/07-primitives/VERIFY.md` need a human with the app. T5 to T9 (text, image, blur, transitions, docs) not started.

## Verified on this machine

- `make build`, `make lint`, `make test` green on the silence-removal worktree (305 tests, 30 suites).
- `TEST_RUNNER_REFRAMED_RUN_EXPORT_TESTS=1 make test T=ExportPipelineTests` green on `milestone-02-lossless-cut`.

## Notes for the next session

- Disk filled up once during parallel worktree builds (each worktree build is about 1 GB); keep an eye on `df -h /` before spawning parallel builds.
- Silence removal keeps its settings in the panel only; `HistoryEntry.label` is the hook feature 04 planned for "one labelled snapshot per tool call".
- Upstream quirks pinned by characterization tests, candidates for fixes: audio-mix index pairing with click sounds, custom camera region border unscaled on the trim path, colour-matched solid backgrounds in the 8-bit render path, unclamped zoom hold keyframe, `FrameRenderer.visibleText` crash/loop edge cases.

## Next

1. Merge the music-tracks phases 0 to 3 worktree, then phases 4 to 8.
2. Human runs the manual rows of milestone 02's VERIFY.md and the silence rows of milestone 07's VERIFY.md.
3. Merge the silence-removal worktree into a `milestone-07-primitives` branch once milestone 02 lands on `main`.
4. Milestone 04 agent chat waits on ADR 0009 (owner authorization to copy Toone code).
5. Owner decisions still open: ADR 0005 identity, ADR 0009 Toone provenance, the 27 feature questions (assumptions in force).
