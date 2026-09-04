# Verify milestone 05

| Check | Command or steps | Expected | Result |
|-------|------------------|----------|--------|
| Builds | `make build` | exit 0, no new warnings | pass (2026-09-04) |
| Tests | `make test` | all green | pass, 385 tests in 46 suites (2026-09-04) |
| Lint, format | `make lint && make format && git diff --exit-code` | clean | pass (2026-09-04) |
| Socket smoke | `make test T=AgentBridgeServerTests` | green | pass, 6 tests; token rejection, initialization, calls, errors, timeout, shutdown (2026-09-04) |
| Frame smoke | `make test T=AgentToolDispatcherTests` | green, PNG decodes at the requested width | pass (2026-09-04) |
| No upstream source edits | compare with `milestone-03-music-tracks` | production changes confined to `Reframed/Agent/Tools/` plus source registration in `project.pbxproj` | pass (2026-09-04) |

Closed on: pending.
