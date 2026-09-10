# Test plan: bundled agent skills

| Proof | Expected | Status |
|---|---|---|
| Frontmatter and package limits | folder/name match, non-empty description at most 1024 characters, file at most 256 KB | green |
| Catalog references | every backticked tool token exists in the read-only or editing catalog | green |
| Dual-provider materialization | identical real copies appear under `.agents/skills` and `.claude/skills` | green |
| Canonical guidance | `AGENTS.md` is written and `CLAUDE.md` points to it relatively | green |
| Idempotence | rerunning restores an edited AppShow skill copy | green |
| Package validation | every canonical source passes the bundled `quick_validate.py` validator | green |
| Runtime discovery | Codex and Claude Code each list and invoke one materialized skill | green: Codex 0.149.1 and Claude Code 2.1.260 |
| Live skill mutation | each provider invokes `add-title-cards`, calls the signed bridge, and leaves exactly one requested title | green: `make test-agent-skills CLAUDE_MODEL=sonnet` |
