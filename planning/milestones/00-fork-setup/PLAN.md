# Milestone 00: fork-setup

Goal: a fresh clone of `mattwebhub/Reframed` builds, runs, tests, and formats on this machine with one command each, never talks to upstream's update feed, and a new developer can learn the codebase from `docs/architecture/` without reading all 33k lines.

Depends on: none.

## Tasks

- [x] T1. Fork `jkuri/Reframed` to `mattwebhub/Reframed`, clone to `~/Projects/appshow/reframed`, add `upstream` remote. Proof: `git remote -v` shows both.
- [x] T2. Baseline build on this machine. Proof: `make build` exits 0. Found and fixed: hardcoded upstream `DEVELOPMENT_TEAM` (ADR 0003).
- [x] T3. Signing per developer via `Config.xcconfig` + ignored `Local.xcconfig`. Proof: `make build` exits 0 without `Local.xcconfig`; `codesign -dv` shows `Signature=adhoc`.
- [x] T4. Neutralize upstream Sparkle feed (ADR 0004). Proof: `grep SUFeedURL Reframed/Info.plist` shows the fork URL, `SUEnableAutomaticChecks` is false, `SparkleUpdater.swift` no longer forces automatic checks.
- [x] T5. Release scripts, About tab links, and the changelog fetch reference the fork repo. Proof: `grep -rn jkuri scripts/` and `grep -rn 'github.com/jkuri' Reframed/` return nothing.
- [x] T6. Planning folder structure with README, STATE, ROADMAP, ADRs, templates. Proof: `planning/README.md` describes every file that exists.
- [x] T7. Architecture documentation `docs/architecture/00`–`07`. Proof: each file exists, cites real paths, and `06-conventions-checklist.md` has a checklist per change type.
- [x] T8. `ReframedTests` hosted unit-test target using Swift Testing, with a launch guard so the test host does not start Sparkle or request permissions (ADR 0006). Proof: `make test` runs 21 tests in 4 suites and exits 0.
- [x] T9. `make test` target in the Makefile, documented in AGENTS.md. Proof: `make test` works from a clean `.build`.
- [x] T10. Lint in the loop: `make lint` using `swift format lint` (Xcode toolchain) with the existing `.swift-format`. Proof: `make lint` exits 0 on `main`.
- [ ] T11. GitHub Actions workflow running build, lint, and test on a macOS runner on every PR. Workflow written at `.github/workflows/ci.yml`; unproven until a PR runs it. Proof: green check on a PR to `main`.
- [x] T12. `AGENTS.md` fork section: TDD workflow, planning folder, upstream sync, and the test/lint commands. Proof: file mentions `planning/STATE.md`, `make test`, and `upstream-sync.md`.
- [ ] T13. Owner decides product identity (ADR 0005). Proof: ADR status is `accepted` or `rejected`.
- [ ] T14. Commit the milestone on a branch and open a PR to `main` of the fork. Proof: PR URL recorded in `VERIFY.md`.

## Out of scope

- Any behavior change to recording, editing, or export.
- Writing the tier-1 test suite (milestone 01). T8 only proves the harness works.
- Extracting a `ReframedCore` Swift package.
- Renaming the product (waits on T13).

## Risks

- Hosted test bundles launch the full app; `AppDelegate` starts Sparkle and the app may request Screen Recording permission at launch. Mitigation: environment-based guard in `AppDelegate`, chosen in `docs/architecture/07-testability.md`.
- The vendored `gifski` static library may need explicit linking for the test bundle. Mitigation: the test target links only against the host app, not the library.
- Upstream pbxproj churn will conflict with our test target block. Mitigation: keep the test target block self-contained and documented in `upstream-sync.md`.
