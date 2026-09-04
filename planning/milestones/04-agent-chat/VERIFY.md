# Verify milestone 04

| Check | Command or steps | Expected | Result |
|-------|------------------|----------|--------|
| Builds, lint, tests | `make format && make lint && make build && make test` | green, no new warnings | pass: 403 tests in 40 suites on 2026-09-04 |
| No bypass flags | `make test T=AgentSecurityTests` plus source grep | green | pass: 6 tests; neither bypass flag appears under `AppShow/` |
| Panel | open the editor, collapse and expand, resize, relaunch | state persists, matches design tokens | |
| Readiness | with no CLI on PATH, then with one installed | correct messages | |
| Turn | send a message with a real CLI | streams, renders markdown, tool rows collapse | |
| Cancel | cancel mid-turn | process gone, transcript marked | |
| Export gate | start an export, try to send | refused with a message | |
| Persistence | close and reopen the project; then use Clear Conversation | the single conversation restores from `agent/conversation.json`, and clear removes messages and provider resume ids | |

Automated gate completed on 2026-09-04. The milestone remains open until the manual rows above are exercised with a disposable project and real installed providers. PR: https://github.com/mattwebhub/AppShow/pull/6
