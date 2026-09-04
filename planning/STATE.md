# State

Last updated: 2026-09-03

## Position

- Milestone `00-fork-setup`: 11 of 14 tasks done, committed on branch `fork-setup` (commit `ad8f460`). Remaining: T11 (CI proven on a PR), T13 (product identity), T14 (PR).
- Feature planning complete for the four product features: `docs/features/00-overall-plan.md` plus `SPIKE.md` and `ATTACK-PLAN.md` for `01-lossless-cut`, `02-music-tracks`, `03-agent-chat`, `04-agent-tools` (about 1,800 lines, all cited paths verified).
- Roadmap milestones 02 to 08 map the features; see `planning/ROADMAP.md`.
- Fork: https://github.com/mattwebhub/Reframed, cloned to `~/Projects/appshow/reframed`; upstream `jkuri/Reframed` v0.14.7, remote `upstream`. Nothing pushed yet.

## Verified on this machine

- `make build`, `make lint`, `make test` exit 0; 21 tests in 4 suites.

## Scheduled

- Execution kickoff timer set for 2026-09-03 23:11 local (milestone 00 leftovers, then 01, 02, 03 in order with TDD).

## Next

1. Owner answers the questions in `docs/features/00-overall-plan.md` (27, each with a stated assumption) and decides ADRs 0005 (identity), 0008 (gifski licence), 0009 (Toone code provenance).
2. Push `fork-setup`, open the PR, confirm CI (milestone 00 T11, T14).
3. Milestone 01 `test-foundation`: first-15-tests table in `docs/architecture/07-testability.md`, plus the characterization test for the audio-mix index pairing bug found in `docs/features/02-music-tracks/SPIKE.md`, plus `ReframedTests/Fixtures` and `Support/Fixtures.swift` which the attack plans depend on.
4. Milestone 02 `lossless-cut`: start from `docs/features/01-lossless-cut/ATTACK-PLAN.md` phase P1 (`CutTimeline` pure model, split at playhead).

## Open questions for the owner

- Product identity (ADR 0005), Toone provenance (ADR 0009). ADR 0008 accepted: fully open source, gifski kept under AGPL.
- The 27 feature questions in `docs/features/00-overall-plan.md`.
