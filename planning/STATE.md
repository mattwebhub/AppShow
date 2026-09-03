# State

Last updated: 2026-09-03

## Position

- Milestone: `00-fork-setup`, 11 of 14 tasks done. Remaining: T11 (CI proven on a PR), T13 (product identity decision), T14 (commit and PR).
- Fork: https://github.com/mattwebhub/Reframed, cloned to `~/Projects/appshow/reframed`
- Upstream: https://github.com/jkuri/Reframed at v0.14.7 (commit `b6a1709`, 2026-04-16), remote `upstream`
- Toolchain verified: Xcode 26.6, Swift 6.3, macOS 26.5.2
- Working tree: all fork-setup changes are uncommitted on `main` (nothing has been committed or pushed yet).

## Verified on this machine

- `make build`, `make lint`, `make test` all exit 0. 21 tests in 4 suites (`ZoomTimelineTests`, `RegionRemappingTests`, `LaunchEnvironmentTests`, `ReframedPathsTests`).
- Fresh clone needs no signing setup (ad-hoc default via `Config.xcconfig`, ADR 0003).
- No build or test contacts upstream: Sparkle feed, About links, changelog fetch, and release scripts point at the fork (ADR 0004).

## Docs written

- `docs/architecture/00` to `07` and `planning/tdd-strategy.md`, about 2,900 lines, every cited Swift path verified to exist.
- ADRs 0001 to 0008. `AGENTS.md` is canonical guidance, `CLAUDE.md` a symlink (ADR 0007).

## Next

1. Owner decides ADR 0005 (product identity) and reads ADR 0008 (gifski licence).
2. Commit milestone 00 on a branch, open a PR to `main` of the fork, confirm CI is green (T11, T14).
3. Start milestone 01 (`test-foundation`) from the first-15-tests table in `docs/architecture/07-testability.md`; the top candidates are legacy `project.json` decoding, `EditorStateData` round trip, `SharedRecordingClock`.

## Open questions for the owner

- Product identity: keep the name Reframed and bundle id `eu.jkuri.reframed`, or rename with our own bundle id? `decisions/0005-product-identity.md`.
- Licence: the vendored `libgifski.a` (GIF export) is AGPL-3.0 with no licence text in the repo, while the app is MIT. Not a problem for private development, must be settled before distributing builds. `decisions/0008-gifski-licence.md`.
- Distribution: shipping builds to others (Developer ID + notarization, certificate is present) or local only for now?
