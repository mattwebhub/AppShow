# Roadmap

| # | Milestone | Goal | Status |
|---|-----------|------|--------|
| 00 | fork-setup | Fork builds, tests, and lints on this machine and in CI; fork identity separated from upstream; architecture documented | complete |
| 01 | test-foundation | Pure-logic layer under test (tier 1 from `docs/architecture/07-testability.md`), first seams introduced, golden-frame harness for the compositor | complete |
| 02 | lossless-cut | Feature 01: keep-slices track, playback jumping, export of kept slices only (`docs/features/01-lossless-cut/`) | code complete; PR #3 |
| 03 | music-tracks | Feature 02: external audio in the bundle, track UI, preview sync, export mix (`docs/features/02-music-tracks/`) | code complete; PR #5 |
| 04 | agent-chat | Feature 03: collapsible chat panel with Claude Code / Codex providers, ported from Toone (`docs/features/03-agent-chat/`) | code complete; PR #6 |
| 05 | agent-tools-readonly | Feature 04 part 1: MCP transport and read-only project tools (`docs/features/04-agent-tools/`) | code complete; PR #7 |
| 06 | agent-tools-editing | Feature 04 part 2: mutating tools for existing editor features with live feedback and undo | code complete; PR #8; manual checks remain |
| 07 | primitives | Text overlay, image overlay, blur, silence detection, transitions, each shipped with its tool | code complete; PR #4; manual checks remain |
| 08 | upstream-sync-1 | First upstream comparison after divergence, exercising `upstream-sync.md` | complete; upstream still at fork base |
| 09 | appshow-identity | Rename the app, identifiers, paths, release metadata, and user-facing copy to AppShow before public release (ADR 0005) | in progress |

The overall feature plan is `docs/features/00-overall-plan.md`. The product name is AppShow; inherited Reframed identity remains until the pre-release rename (ADR 0005).

## Milestone rules

- A milestone closes only when its `VERIFY.md` checks all pass on a clean clone.
- Milestones are sequential. Features inside a milestone may run in parallel.
