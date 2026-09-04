# State

Last updated: 2026-09-04

## Position

- Milestone 00 closed except the product-identity decision: PR #1 https://github.com/mattwebhub/Reframed/pull/1 (CI green).
- Milestone 01 test-foundation complete: 218 tests, PR #2 https://github.com/mattwebhub/Reframed/pull/2 (stacked on fork-setup).
- Milestone 02 lossless-cut on branch `milestone-02-lossless-cut`: phases P1, P2, P3, P4, P5, P7 landed with tests (257 tests, plus 2 gated export tests). P6 compressed timeline in progress by a delegated worktree. Remaining after P6: VERIFY.md manual checks, push, PR.
- Milestone 03 music-tracks: not started; attack plan in `docs/features/02-music-tracks/ATTACK-PLAN.md`.

## Verified on this machine

- `make build`, `make lint`, `make test` green on `milestone-02-lossless-cut` after merging milestone 01.
- `TEST_RUNNER_REFRAMED_RUN_EXPORT_TESTS=1 make test T=ExportPipelineTests` green.

## Notes for the next session

- Disk filled up once during parallel worktree builds (each worktree build is about 1 GB); regenerable caches were cleared (Xcode DerivedData, npm/pnpm caches, an Electron updater cache). Keep an eye on `df -h /` before spawning parallel builds.
- Upstream quirks pinned by characterization tests, candidates for fixes: audio-mix index pairing with click sounds, custom camera region border unscaled on the trim path, colour-matched solid backgrounds in the 8-bit render path, unclamped zoom hold keyframe, `FrameRenderer.visibleText` crash/loop edge cases.

## Next

1. Land P6, run `planning/milestones/02-lossless-cut/VERIFY.md` (manual checks need a human with the app), push, open PR #3 stacked on milestone 01.
2. Milestone 03 music tracks from phase 0 of its attack plan.
3. Owner decisions still open: ADR 0005 identity, ADR 0009 Toone provenance, the 27 feature questions (assumptions in force).
