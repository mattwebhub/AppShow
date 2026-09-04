# Feature documentation

One folder per feature, numbered in build order. Each folder holds:

| File | Written when | Contents |
|------|--------------|----------|
| `SPIKE.md` | before any code | What exists in the codebase today for this feature, with file paths and line numbers; gaps; recommended design; risks; questions for the owner |
| `ATTACK-PLAN.md` | after the spike is read | Phased plan. Every phase starts with the failing tests to write, then the production change, then a manual check. Sizes are relative (S/M/L). |

`00-overall-plan.md` ties the features together: the product goal, the dependency order, and how the features map onto milestones in `planning/ROADMAP.md`.

When a feature moves from planning to building, copy `planning/features/_TEMPLATE` to `planning/features/<name>/` and fill `SPEC.md`, `TEST-PLAN.md`, `TASKS.md` from the attack plan. The attack plan stays as the design reference; the planning folder tracks execution.

Documents here are written for developers and for any coding assistant; they name no vendor except where a product (Claude Code, Codex) is itself the subject.
