# Feature: Agent chat panel

Status: implemented; automated verification pending final milestone close
Milestone: 04

## Problem

Editing a recording into a presentation is many small manual steps. The user wants to describe the outcome in a chat and have an agent runtime (Claude Code or Codex, whichever is installed and logged in) do the work in later milestones. This milestone delivers the chat itself: a collapsible left panel in the editor, a provider layer that runs the CLI, streamed transcripts, persistence, and setup guidance. It is read-only toward the project until feature 04 adds tools.

## Behavior

1. A left panel in the editor window, 320 pt wide expanded (clamped 260 to 480, draggable), a 40 pt rail collapsed, following the app's colors, radii, fonts, and button styles. Collapsed state and width persist across launches.
2. The panel detects installed runtimes (Claude Code, Codex) on the PATH and through a login shell, shows readiness (not installed, not logged in, ready) with an actionable message, and lets the user pick a provider; the preference is global.
3. Sending a message starts a fresh CLI process in the project's sibling `.agent/<project-name>/` workspace, resumes the provider's logical session when an id is available, streams the reply with a visible cursor, renders markdown (including dedicated copyable code fences), and shows tool calls as collapsible rows.
4. A turn can be cancelled; the process is terminated and the transcript marks the turn as cancelled. The panel refuses to run while an export is in progress.
5. Exactly one conversation persists inside each `.frm` bundle at `agent/conversation.json`. The header exposes an explicit confirmed clear action; there is no thread picker.
6. Provider-specific runtime sessions resume by id across turns where the CLI supports it. Each turn still launches a fresh operating-system process.
7. Security: the process environment is scrubbed to what the CLI needs, no permission-bypass flags are ever passed, the working directory is the workspace folder, and the runtime gets no tools until feature 04.

## Not doing

- Any project mutation, MCP tools, or skills (feature 04). Persistent processes, multiple conversations, image attachments, slash commands, and a panel keyboard shortcut (v1).

## Touch points

New module `AppShow/Agent/` (`AgentProvider` protocol, `ClaudeCodeProvider`, `CodexProvider`, `AgentProcessRunner`, `AgentSession`, and `AgentProbe` actors, `AgentTranscript` model, `AgentConversationStore`, `AgentReadiness`, `AgentToolchain`, panel views, and markdown renderer). Upstream edits per the attack plan: `EditorView.swift` (panel insertion), `StateService.swift` (panel state), `ConfigService.swift` (provider preference), `AppShowProject.swift` (`agent/` folder), and `EditorState.swift` (transcript ownership and export gate).

## Owner assumptions in force

Questions 20 to 27 in `docs/features/00-overall-plan.md`, plus ADR 0010: read-only agent, ephemeral workspace beside the bundle, one conversation inside the bundle, a fresh process per turn with provider-specific logical session resumption, global provider preference, no shortcut, accepted Toone provenance, and refusal while exporting.
