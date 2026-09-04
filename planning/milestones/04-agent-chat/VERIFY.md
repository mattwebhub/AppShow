# Verify milestone 04

| Check | Command or steps | Expected | Result |
|-------|------------------|----------|--------|
| Builds, lint, tests | `make build && make lint && make test` | green, no new warnings | |
| No bypass flags | `make test T=AgentSecurityTests` | green | |
| Panel | open the editor, collapse and expand, resize, relaunch | state persists, matches design tokens | |
| Readiness | with no CLI on PATH, then with one installed | correct messages | |
| Turn | send a message with a real CLI | streams, renders markdown, tool rows collapse | |
| Cancel | cancel mid-turn | process gone, transcript marked | |
| Export gate | start an export, try to send | refused with a message | |
| Persistence | close and reopen the project | threads and messages restored from `agent/` | |

Closed on: (date, commit, PR)
