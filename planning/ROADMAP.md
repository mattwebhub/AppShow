# Roadmap

| # | Milestone | Goal | Status |
|---|-----------|------|--------|
| 00 | fork-setup | Fork builds, tests, and lints on this machine and in CI; fork identity separated from upstream; architecture documented | in progress |
| 01 | test-foundation | Pure-logic layer under test (tier 1 from `docs/architecture/07-testability.md`), first seams introduced, golden-frame harness for the compositor | not started |
| 02 | first-feature | First product change delivered end to end with TDD, proving the workflow on a real feature | not started |
| 03 | upstream-sync-1 | First merge of upstream changes after divergence, exercising `upstream-sync.md` | not started |

Milestones after 02 depend on product direction and are added with `planning/milestones/_TEMPLATE`.

## Milestone rules

- A milestone closes only when its `VERIFY.md` checks all pass on a clean clone.
- Milestones are sequential. Features inside a milestone may run in parallel.
