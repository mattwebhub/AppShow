# Verify milestone NN

Run on a clean clone before closing the milestone. Record the date and commit.

| Check | Command or steps | Expected | Result |
|-------|------------------|----------|--------|
| Builds | `make build` | exit 0, no warnings introduced | |
| Tests | `make test` | all green | |
| Format | `make format && git diff --exit-code` | no diff | |
| Manual smoke | record 5 s of screen, open editor, export MP4 | file plays | |
