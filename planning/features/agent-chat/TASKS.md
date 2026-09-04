# Tasks: Agent chat panel

ADR 0009 accepted 2026-09-04. Phases from the attack plan:

- [x] P1 Provider protocol and stream parsers (M): copy the two command builders and two message parsers, rewrite on `Codable` structs, recorded NDJSON fixtures.
- [x] P2 Process runner and cancellation (M): `AgentProcessRunner` actor, scrubbed environment, fake-executable tests.
- [x] P3 Transcript model and persistence (M): `AgentTranscript`, `agent/` folder in the bundle, round trip.
- [ ] P4 Collapsible panel shell (S): `AgentChatPanel` with no AI, `StateService` persistence, `EditorView` insertion.
- [ ] P5 Message rendering (L): markdown parser and view, tool-call rows, streaming cursor.
- [ ] P6 Provider setup and detection UI (M): readiness, toolchain resolution, provider picker.
- [ ] P7 Thread management (S): thread store, rename/switch/delete, minimal slash resolver.

## Deviations recorded (phases 1–3)

- Codex resume: flags go before `resume` (Codex rejects `--sandbox` after it), and `--` precedes positionals so a prompt can never be read as a flag.
- `AgentEvent` tool events carry ids; `parse` returns an array and maps unknown envelopes to `.unknown(type:)`.
- One JSON file per thread under `agent/threads/`; saves on create, rename, delete, and turn end.
- `AgentToolchain` includes a login-shell fallback.
- `FileHandle.bytes` blocks an actor's executor until EOF; the runner bridges `readabilityHandler` chunks through an `AsyncStream` and force-finishes after 2 s with SIGKILL.
- Fixtures under `ReframedTests/Fixtures/agent/` were recorded once from Claude Code 2.1.260 and Codex 0.149.1; tests never launch the CLIs.
