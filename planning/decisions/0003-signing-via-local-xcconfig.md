# 0003. Code signing configured per developer, not hardcoded

Status: accepted
Date: 2026-09-03

## Context

`AppShow.xcodeproj/project.pbxproj` sets `DEVELOPMENT_TEAM = 5A5U3XX696` (upstream author's team) and `CODE_SIGN_STYLE = Automatic` on the app target. On any other machine `make build` fails with `No signing certificate "Mac Development" found`. The project already reads `Config.xcconfig` for version numbers.

## Decision

Remove the team id from the pbxproj. `Config.xcconfig` includes an optional, git-ignored `Local.xcconfig` where each developer sets `DEVELOPMENT_TEAM`. Without it, builds sign ad-hoc (`CODE_SIGN_IDENTITY = -`), which is enough to run locally and to prompt for Screen Recording permission.

## Consequences

- A fresh clone builds with no setup. A developer who wants a real certificate creates `Local.xcconfig` with one line.
- Release builds (`make dmg-release`) must be run with a `Local.xcconfig` that sets the Developer ID team.
- Upstream merges that touch signing settings in the pbxproj will conflict; keep ours.
