# Feature: Agent editing tools

Status: code complete; manual verification pending
Milestone: 06

## Contract

1. Mutating tools are opt-in on `AgentToolDispatcher`; a read-only dispatcher continues to reject them.
2. Arguments are schema-validated before state changes. Time values are source seconds and are clamped to the recording duration; invalid ranges fail without changing the project.
3. Each successful call produces at most one history entry named `Agent: <label>`. Identical snapshots are not added. The editor's delayed snapshot cannot create a duplicate.
4. A failed call restores its pre-call snapshot and adds no history entry.
5. Each response returns the compact current timeline, allowing the agent and UI to observe the result immediately.
6. The editing catalog covers trim and cuts, zoom, spotlight, presentation settings, captions, audio, confirmed export, silence removal, text/image/blur overlay CRUD, and entry/exit transitions by target UUID. Structural additions remain separate phases so each can be verified and reverted independently.
7. The bridge advertises mutations only after the editor explicitly creates an editing dispatcher. The CLI shim and chat wiring must never silently downgrade the existing authentication boundary.

## Safety

- Draft export stays inside the ephemeral workspace. Any full export must require explicit in-app confirmation, a destination selected by the user, and a no-silent-overwrite rule.
- Reading or importing a path outside the project workspace requires confirmation.
- Silence removal requires confirmation when its analyzed result would remove more than 40% of the currently kept video.
- One confirmation authorizes one normalized operation and expires when resolved or when the session closes.
- Batch timeout or user undo restores the pre-batch state.

## Not in phase 1

- Direct filesystem mutation by the provider.
- Unbounded shell access.
- Silent overwriting of export destinations.
- More than one conversation per project.
