# Roadmap

| # | Milestone | Goal | Status |
|---|-----------|------|--------|
| 00 | fork-setup | Fork builds, tests, and lints on this machine and in CI; fork identity separated from upstream; architecture documented | in progress |
| 01 | test-foundation | Pure-logic layer under test (tier 1 from `docs/architecture/07-testability.md`), first seams introduced, golden-frame harness for the compositor | not started |
| 02 | lossless-cut | Feature 01: keep-slices track, playback jumping, export of kept slices only (`docs/features/01-lossless-cut/`) | planned |
| 03 | music-tracks | Feature 02: external audio in the bundle, track UI, preview sync, export mix (`docs/features/02-music-tracks/`) | planned |
| 04 | agent-chat | Feature 03: collapsible chat panel with Claude Code / Codex providers, ported from Toone (`docs/features/03-agent-chat/`) | planned |
| 05 | agent-tools-readonly | Feature 04 part 1: MCP transport, read-only project tools, skills folder (`docs/features/04-agent-tools/`) | planned |
| 06 | agent-tools-editing | Feature 04 part 2: mutating tools for existing editor features with live feedback and undo | planned |
| 07 | primitives | Text overlay, image overlay, blur, silence detection, transitions, each shipped with its tool | planned |
| 08 | upstream-sync-1 | First merge of upstream changes after divergence, exercising `upstream-sync.md`; schedule it after milestone 02 lands, not at the end | planned |

The overall feature plan is `docs/features/00-overall-plan.md`. Milestones 02 and 03 can run in parallel; 04 can start while they finish.

## Milestone rules

- A milestone closes only when its `VERIFY.md` checks all pass on a clean clone.
- Milestones are sequential. Features inside a milestone may run in parallel.
