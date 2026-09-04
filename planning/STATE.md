# State

Last updated: 2026-09-04

## Position

- Milestone 00 closed except the product-identity decision: PR #1 https://github.com/mattwebhub/Reframed/pull/1 (CI green).
- Milestone 01 test-foundation complete: 218 tests, PR #2 https://github.com/mattwebhub/Reframed/pull/2 (stacked on fork-setup).
- Milestone 02 lossless-cut complete on the code side: all seven phases landed, 272 tests in 27 suites plus 2 gated export tests, PR #3 https://github.com/mattwebhub/Reframed/pull/3 (stacked on milestone 01). Manual checks in its VERIFY.md need a human with the app.
- Milestone 03 music-tracks on branch `milestone-03-music-tracks` (planning docs committed, includes milestone 02): phases 0 to 3 in progress by a delegated worktree.

## Verified on this machine

- `make build`, `make lint`, `make test` green on `milestone-02-lossless-cut` after merging milestone 01.
- `TEST_RUNNER_REFRAMED_RUN_EXPORT_TESTS=1 make test T=ExportPipelineTests` green.

## Notes for the next session

- Disk filled up once during parallel worktree builds (each worktree build is about 1 GB); regenerable caches were cleared (Xcode DerivedData, npm/pnpm caches, an Electron updater cache). Keep an eye on `df -h /` before spawning parallel builds.
- Upstream quirks pinned by characterization tests, candidates for fixes: audio-mix index pairing with click sounds, custom camera region border unscaled on the trim path, colour-matched solid backgrounds in the 8-bit render path, unclamped zoom hold keyframe, `FrameRenderer.visibleText` crash/loop edge cases.

## Next

1. Merge the music-tracks phases 0 to 3 worktree, then phases 4 to 8.
2. Human runs the manual rows of milestone 02's VERIFY.md.
3. Milestone 04 agent chat waits on ADR 0009 (owner authorization to copy Toone code).
3. Owner decisions still open: ADR 0005 identity, ADR 0009 Toone provenance, the 27 feature questions (assumptions in force).
