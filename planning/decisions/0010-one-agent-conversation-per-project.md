# 0010. One agent conversation per project

Status: accepted
Date: 2026-09-04

## Context

The agent chat needs a persistence model, process lifetime, and cleanup contract. A general thread list would add navigation, selection, and lifecycle states that are not required for the first product workflow.

## Decision

Each `.frm` project owns exactly one agent conversation. The conversation is persisted inside the project bundle and restored when the project is reopened. The user can clear it explicitly, which removes the persisted transcript and resets the in-memory conversation to empty.

Each user turn launches a fresh Claude Code or Codex process. Conversation continuity is supplied from the persisted project transcript rather than by keeping a CLI process alive between turns.

Ephemeral runtime state—including the Unix socket, session token, and rendered preview frames—lives in the project's sibling `.agent/` workspace and is not part of the portable conversation record.

## Consequences

- The chat UI has no thread picker, create-thread action, or selected-thread state.
- Clearing the conversation is an explicit, destructive UI action with confirmation while messages exist.
- Process cancellation affects only the active turn; the completed transcript remains persisted.
- The persistence format must decode a missing conversation for projects created by older versions.
- Multiple conversations and persistent CLI processes require a future ADR if added.
