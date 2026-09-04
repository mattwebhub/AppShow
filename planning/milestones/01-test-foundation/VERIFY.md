# Verify milestone 01

| Check | Command or steps | Expected | Result |
|-------|------------------|----------|--------|
| Builds | `make build` | exit 0 | |
| Tests | `make test` | all green, at least 15 new suites beyond milestone 00's four | |
| Lint | `make lint` | exit 0 | |
| Format | `make format && git diff --exit-code` | no diff | |
| No binaries | `git ls-files ReframedTests \| grep -vE '\.swift$'` | empty | |
| Host is quiet | `make test` | no dialog, `~/.reframed` untouched | |
| Seams listed | `grep -c 'S4\|S7' planning/upstream-sync.md` | ≥ 2 | |
| CI | PR opened | green | |

Closed on: (date, commit, PR)
