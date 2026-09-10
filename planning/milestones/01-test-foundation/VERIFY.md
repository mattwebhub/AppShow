# Verify milestone 01

| Check | Command or steps | Expected | Result |
|-------|------------------|----------|--------|
| Builds | `make build` | exit 0 | pass |
| Tests | `make test` | all green, at least 15 new suites beyond milestone 00's four | pass, 218 tests in 19 suites |
| Lint | `make lint` | exit 0 | pass |
| Format | `make format && git diff --exit-code` | no diff | pass |
| No binaries | `git ls-files AppShowTests \| grep -vE '\.swift$'` | empty | pass |
| Host is quiet | `make test` | no dialog, `~/.reframed` untouched | pass |
| Seams listed | `grep -c 'S4\|S7' planning/upstream-sync.md` | ≥ 2 | pass |
| CI | PR opened | green | pass after fixture encoder fix, https://github.com/mattwebhub/AppShow/pull/2 |

Closed on: 2026-09-04, https://github.com/mattwebhub/AppShow/pull/2
