# Feature: Agent chat panel

Status: agreed on design, blocked on ADR 0009 for code copying
Milestone: 04

## Problem

Editing a recording into a presentation is many small manual steps. The user wants to describe the outcome in a chat and have an agent runtime (Claude Code or Codex, whichever is installed and logged in) do the work in later milestones. This milestone delivers the chat itself: a collapsible left panel in the editor, a provider layer that runs the CLI, streamed transcripts, persistence, and setup guidance. It is read-only toward the project until feature 04 adds tools.

## Behavior

1. A left panel in the editor window, 320 pt wide expanded (clamped 260 to 480, draggable), a 40 pt rail collapsed, following the app's colors, radii, fonts, and button styles. Collapsed state and width persist across launches.
2. The panel detects installed runtimes (Claude Code, Codex) on the PATH and through a login shell, shows readiness (not installed, not logged in, ready) with an actionable message, and lets the user pick a provider; the preference is global.
3. Sending a message starts one CLI process per turn in the project's workspace folder next to the `.frm` bundle, streams the reply as it arrives with a visible streaming cursor, renders markdown (code fences, tables, lists), and shows tool calls as collapsible rows.
4. A turn can be cancelled; the process is terminated and the transcript marks the turn as cancelled. The panel refuses to run while an export is in progress.
5. Transcripts persist inside the `.frm` bundle under `agent/` per thread; threads can be created, renamed, switched, and deleted.
6. Runtime sessions resume by id across turns where the CLI supports it.
7. Security: the process environment is scrubbed to what the CLI needs, no permission-bypass flags are ever passed, the working directory is the workspace folder, and the runtime gets no tools until feature 04.

## Not doing

- Any project mutation, MCP tools, or skills (feature 04). Persistent processes per thread, image attachments, slash commands beyond a minimal resolver, keyboard shortcut for the panel (v1).

## Touch points

New module `Reframed/Agent/` (`AgentProvider` protocol, `ClaudeCodeProvider`, `CodexProvider`, `AgentProcessRunner` and `AgentSession` actors, `AgentTranscript` model, `AgentReadiness`, `AgentToolchain`, `AgentChatPanel` views, markdown renderer). Upstream edits per the attack plan: `EditorView.swift` (one-line panel insertion), `EditorWindow.swift`, `StateService.swift` (panel state), `ConfigService.swift` (provider preference), `ReframedProject.swift` (`agent/` folder), `EditorState.swift` (`isExporting` gate).

## Owner assumptions in force

Questions 20 to 27 in `docs/features/00-overall-plan.md`: read-only agent, workspace folder next to the bundle, transcripts in the bundle, one process per turn, global provider preference, no shortcut, ADR 0009 for provenance, refuse while exporting.
