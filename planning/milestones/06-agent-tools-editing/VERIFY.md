# Verify milestone 06

| Check | Expected | Result |
|---|---|---|
| `make format && make lint && make build` | clean | pass (2026-09-04) |
| `make test` | all green | pass, 536 tests in 60 suites (2026-09-04) |
| Integration baseline | chat plus read-only tools build together | pass, 516 tests in 59 suites (2026-09-04) |
| Cut operations | exact kept-slice replacement and removed-range subtraction normalize and undo | pass, 24 cut tests and 10 mutation tests (2026-09-04) |
| Batch safety | one labelled undo, active timeout restore, user-history cancellation | pass, 10 mutation tests (2026-09-04) |
| Confirmation capability | pending, allow once, deny, mismatch consumption, expiry, session clear | pass, 14 mutation tests (2026-09-04) |
| Set trim | agent changes trim; timeline updates; one labeled history row; Undo restores it | |
| Zoom and spotlight | chips and preview update while the tool runs | |
| Batch | three edits create one history row and one Undo restores all | |
| Confirmation deny | external import/export does not start and no state changes | |
| Confirmation allow | exactly the shown operation runs once | |
| Provider E2E | Claude Code and Codex each read timeline and apply a reversible edit | |
| Export | user selects a destination; existing file is not overwritten without a second decision | |
