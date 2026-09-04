# Agent NDJSON fixtures

One file per scenario, one JSON envelope per line, exactly as the CLI writes it to stdout. Files named with a CLI version were recorded on 2026-09-04 from that installed CLI in a scratch directory containing `note.txt`; the working directory was rewritten to `/Users/example/Movies/Reframed/demo.frm`, the `system/init` lists (`tools`, `mcp_servers`, `slash_commands`, `agents`, `skills`, `plugins`, `memory_paths`) were shortened, and per-message `usage`/`modelUsage` blocks were dropped. Nothing else was edited. Budget: 20 KB per file.

| File | Origin |
| --- | --- |
| `claude-2.1.260-turn.ndjson` | `claude -p "<prompt>" --output-format stream-json --verbose --permission-mode default --allowedTools Read --allowedTools Glob --allowedTools Grep`; one `Read` tool call, then a text reply |
| `claude-2.1.260-resume.ndjson` | same flags plus `--resume <session_id>` from the turn above |
| `claude-2.1.260-tool-error.ndjson` | same flags; `Read` of a missing file returns `is_error: true` |
| `codex-0.149.1-turn.ndjson` | `codex exec --json --skip-git-repo-check --sandbox read-only -- "<prompt>"`; one `command_execution`, then a text reply |
| `codex-0.149.1-resume.ndjson` | `codex exec --json --skip-git-repo-check --sandbox read-only resume -- <thread_id> "<prompt>"` |
| `codex-0.149.1-command-error.ndjson` | same as the first turn; the command exits 1 with `status: "failed"` |
| `claude-toone-literals.ndjson` | Converted from the Toone desktop app test literals and parser comments: `TooneTests/Services/ChatProgressSafetyTests.swift:112-118` (structured output wins over `result`), `Toone/Core/Services/AIService/Claude/ClaudeMessageParser.swift:129-137` (`is_error` / non-`success` subtype), `:148-153` (`type: "error"` envelope), and the envelope shapes listed in `docs/features/03-agent-chat/SPIKE.md` §3.3 |
| `codex-toone-literals.ndjson` | Converted from `TooneTests/Services/CodexCommandBuilderTests.swift:130` (`thread.started`), `:142` (`function_call` with `request_user_input`), `TooneTests/Services/ThreadTitleServiceTests.swift:114-115` (`agent_message`), `Toone/Core/Services/AIService/Codex/CodexMessageParser.swift:1043-1048` (`turn.completed` with `"error": null`), `:1070-1074` (`turn.failed`), `:1088-1092` (`error`), and the `command_execution` shape from `SPIKE.md` §3.3 |

Toone paths are relative to `/Users/matheusparanhos/Projects/toone/apps/toone-desktop/Toone`. Provenance: `planning/decisions/0009-toone-code-provenance.md`.
