# Verify milestone 00

Run on a clean clone before closing the milestone. Record the date and commit.

| Check | Command or steps | Expected | Result |
|-------|------------------|----------|--------|
| Clean clone builds | `git clone https://github.com/mattwebhub/Reframed.git /tmp/verify && cd /tmp/verify && make build` | exit 0, no `Local.xcconfig` needed | |
| Ad-hoc signed | `codesign -dv .build/Build/Products/Debug/Reframed.app 2>&1 \| grep Signature` | `Signature=adhoc` | |
| Tests | `make test` | at least one test, all green | |
| Lint | `make lint` | exit 0 | |
| Format | `make format && git diff --exit-code` | no diff | |
| No upstream feed | `grep -c jkuri Reframed/Info.plist scripts/*.sh` | 0 for every file | |
| Test host is quiet | `make test` with a fresh user account or after `tccutil reset ScreenCapture eu.jkuri.reframed` | no permission dialog, no Sparkle dialog | |
| CI | open a PR touching a Swift file | build + lint + test job green | pass, 2m44s, https://github.com/mattwebhub/Reframed/pull/1 |
| Docs | `ls docs/architecture` | 00 to 07 present | |
| Manual smoke | `make dev`, record 5 s of screen, open editor, export MP4 | file plays in QuickTime | |

Closed on: 2026-09-04, a1c5c60, https://github.com/mattwebhub/Reframed/pull/1 (T13 product identity still open, non-blocking)
