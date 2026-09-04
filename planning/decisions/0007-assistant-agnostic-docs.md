# 0007. Documentation and guidance are assistant-agnostic

Status: accepted
Date: 2026-09-03

## Context

Upstream keeps its repository guidance in `CLAUDE.md` with `AGENTS.md` as a symlink to it, and ships `.claude/settings.json` enabling vendor plugins. The team wants to use whichever coding assistant fits at the time, and wants documentation that stays valid regardless of which tool, or which person, wrote or reads it.

## Decision

- `AGENTS.md` is the canonical guidance file (the vendor-neutral convention). `CLAUDE.md` is a symlink to it so tools that look for that name still work. Other tools that want their own filename get a symlink too, never a copy.
- Docs, plans, and ADRs never name a specific assistant or vendor. They say "developer" or "coding assistant".
- Rules live in `AGENTS.md`, `planning/`, and `docs/architecture/`, not in vendor config directories. Vendor config files may exist for convenience (`.claude/settings.json` is inherited from upstream) but must not carry rules that are absent from the neutral docs.
- Upstream edits `CLAUDE.md` as a regular file. On merge, apply their content changes to `AGENTS.md` and keep the symlink direction ours.

## Consequences

- Any assistant, or a new team member, gets the same instructions from the same file.
- Merges of upstream guidance changes need a manual step, recorded in `planning/upstream-sync.md`.
- Existing text that refers to `CLAUDE.md` is rewritten to `AGENTS.md`.
