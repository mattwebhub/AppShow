# Planning

This folder is the working memory of the fork. It lives inside the repo so it is versioned with the code and survives upstream merges (upstream never touches `planning/`, `docs/architecture/`, or `ReframedTests/`).

## Layout

```
planning/
├── README.md              this file: how the folder works
├── STATE.md               where we are right now; read this first in every session
├── ROADMAP.md             ordered milestones with status
├── tdd-strategy.md        how we test: layers, fixtures, definition of done
├── upstream-sync.md       how and when to pull jkuri/Reframed changes
├── decisions/             architecture decision records (ADRs), numbered, immutable once accepted
├── milestones/
│   ├── NN-name/PLAN.md    tasks for one milestone, checkboxes, each task names its test
│   ├── NN-name/VERIFY.md  acceptance checks run before the milestone is closed
│   └── _TEMPLATE/         copy to start a milestone
└── features/
    ├── name/SPEC.md       what the feature does, from the user's point of view
    ├── name/TEST-PLAN.md  tests written before code, mapped to SPEC bullets
    ├── name/TASKS.md      ordered red-green-refactor steps
    └── _TEMPLATE/         copy to start a feature
```

Engineering documentation about the inherited codebase lives in `docs/architecture/` (numbered 00 to 07). Upstream's own high-level docs stay in `docs/*.md` untouched.

## Workflow loop

1. Read `STATE.md`, then the active milestone's `PLAN.md`.
2. For a feature, copy `features/_TEMPLATE` and fill `SPEC.md` first, then `TEST-PLAN.md`.
3. Write the failing test in `ReframedTests/`, run `make test`, see red.
4. Write the minimum code, run `make test`, see green. Run `make format`.
5. Tick the task in `PLAN.md` or `TASKS.md`. Update `STATE.md` at the end of the session.
6. A decision that changes structure, tooling, or a public contract gets an ADR in `decisions/`.

## Rules

- Plans name the test that proves each task, not just the task.
- `STATE.md` is overwritten, never appended forever. Keep it under one screen.
- Do not edit upstream files to make them testable unless `docs/architecture/07-testability.md` lists that seam. Prefer adding a protocol next to the type over rewriting it.
- Anything that diverges from upstream on purpose gets recorded in `upstream-sync.md` under "Intentional divergences".
- Documentation is written for people and for any coding assistant, never for one vendor. Guidance lives in `AGENTS.md`; `CLAUDE.md` is only a symlink to it. Do not name a specific assistant in docs, plans, or ADRs, and do not rely on vendor-specific config files (`.claude/`, `.cursor/`, etc.) to carry rules. See `decisions/0007-assistant-agnostic-docs.md`.
