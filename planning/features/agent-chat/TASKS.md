# Tasks: Agent chat panel

ADR 0009 accepted 2026-09-04. Phases from the attack plan:

- [x] P1 Provider protocol and stream parsers (M): copy the two command builders and two message parsers, rewrite on `Codable` structs, recorded NDJSON fixtures.
- [x] P2 Process runner and cancellation (M): `AgentProcessRunner` actor, scrubbed environment, fake-executable tests.
- [x] P3 Transcript model and persistence (M): `AgentTranscript`, one `agent/conversation.json` inside the bundle, migration from the abandoned multi-thread draft, round trip.
- [x] P4 Collapsible panel shell (S): `AgentChatPanel`, `StateService` persistence, `EditorView` insertion.
- [x] P5 Message rendering (L): markdown block parser, copyable code fences, collapsible tool-call rows, streaming cursor.
- [x] P6 Provider setup and detection UI (M): bounded readiness probes, toolchain resolution, provider picker, actionable setup states.
- [x] P7 Conversation lifecycle (S): exactly one project conversation with a confirmed clear action and provider-scoped resume ids.

## Deviations recorded

- Codex resume: flags go before `resume` (Codex rejects `--sandbox` after it), and `--` precedes positionals so a prompt can never be read as a flag.
- `AgentEvent` tool events carry ids; `parse` returns an array and maps unknown envelopes to `.unknown(type:)`.
- One canonical `agent/conversation.json` per project; it saves on user append, turn completion/cancellation, provider change, and explicit clear. Legacy draft files under `agent/threads/` migrate once.
- `AgentToolchain` includes a login-shell fallback.
- `FileHandle.bytes` blocks an actor's executor until EOF; the runner bridges `readabilityHandler` chunks through an `AsyncStream` and force-finishes after 2 s with SIGKILL.
- Fixtures under `AppShowTests/Fixtures/agent/` were recorded once from Claude Code 2.1.260 and Codex 0.149.1; tests never launch the CLIs.
- The renderer uses Foundation Markdown for prose and a pure local parser only to split fenced code, avoiding a new package dependency.
