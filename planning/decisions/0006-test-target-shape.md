# 0006. Shape of the test target

Status: accepted
Date: 2026-09-03

## Context

All code lives in one app target; there is no Swift package to import. Unit tests of app code therefore need a hosted test bundle with `@testable import Reframed`. `ENABLE_TESTABILITY = YES` was already set for Debug. The app's launch path starts Sparkle, installs a keyboard event tap, constructs `SessionState` (which reads `~/.reframed`), and opens a permissions window when Screen Recording or Accessibility is not granted. The vendored `gifski` static library is linked into the app, and `Reframed.swiftmodule` references its module. Analysis: `docs/architecture/07-testability.md`.

## Decision

- One hosted unit-test bundle `ReframedTests` (Swift Testing), `TEST_HOST`/`BUNDLE_LOADER` on `Reframed.app`, `SWIFT_INCLUDE_PATHS` pointing at `Reframed/Libraries/gifski` and no direct `-lgifski` link. Tests mirror the `Reframed/` folder layout.
- Test host guard: `LaunchEnvironment.isTestHost` (`REFRAMED_TEST_HOST=1` or the XCTest environment) returns early from `applicationDidFinishLaunching`.
- Path seam: `ReframedPaths.home` and `ReframedPaths.temp` honor `REFRAMED_HOME` and `REFRAMED_TMP`; the scheme's TestAction sets them to `/tmp/reframed-tests/home` and `/tmp/reframed-tests/tmp` (literal, because xcodebuild does not expand macros in scheme environment values).
- `make test` wraps `xcodebuild test` with `-parallel-testing-enabled NO` and a grep filter; `make test T=Suite` runs one suite.
- A separate `ReframedCore` package for pure logic is deferred until the hosted target proves too slow.

## Consequences

- 21 tests across 4 suites pass in well under a second after the app builds; the app build dominates `make test` time.
- Four upstream files carry one-line seams; listed in `planning/upstream-sync.md` for merges.
- The host never touches `~/.reframed`, the network, permissions, or Sparkle during tests; `LaunchEnvironmentTests` and `ReframedPathsTests` pin that contract.
