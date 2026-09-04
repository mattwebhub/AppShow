# Verify milestone 05

| Check | Command or steps | Expected | Result |
|-------|------------------|----------|--------|
| Builds | `make build` | exit 0, no new warnings | |
| Tests | `make test` | all green | |
| Lint, format | `make lint && make format && git diff --exit-code` | clean | |
| Socket smoke | `make test T=AgentBridgeServerTests` | green | |
| Frame smoke | `make test T=AgentToolDispatcherTests` | green, PNG decodes at the requested width | |
| No upstream edits | `git diff milestone-03-music-tracks --stat -- Reframed | grep -v Agent/Tools` | only `project.pbxproj` | |

Closed on: pending.
