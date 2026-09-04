# 0002. Planning and architecture docs live inside the repository

Status: accepted
Date: 2026-09-03

## Context

Planning could live in a sibling folder outside the git repo, in a wiki, or inside the repo. Upstream merges add and modify files under `Reframed/`, `docs/*.md`, `AGENTS.md`, and the pbxproj, but never create `planning/` or `docs/architecture/`.

## Decision

Keep `planning/` and `docs/architecture/` inside the repository. Test code lives in `ReframedTests/`.

## Consequences

- Docs are versioned with the code they describe and reviewable in PRs.
- Upstream merges never conflict on these folders.
- `AGENTS.md` is the one shared file we edit; conflicts there are expected and resolved by hand.
