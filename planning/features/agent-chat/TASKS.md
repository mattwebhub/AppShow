# Tasks: Agent chat panel

Blocked until `planning/decisions/0009-toone-code-provenance.md` is accepted (copying from the Toone desktop app). Phases from the attack plan:

- [ ] P1 Provider protocol and stream parsers (M): copy the two command builders and two message parsers, rewrite on `Codable` structs, recorded NDJSON fixtures.
- [ ] P2 Process runner and cancellation (M): `AgentProcessRunner` actor, scrubbed environment, fake-executable tests.
- [ ] P3 Transcript model and persistence (M): `AgentTranscript`, `agent/` folder in the bundle, round trip.
- [ ] P4 Collapsible panel shell (S): `AgentChatPanel` with no AI, `StateService` persistence, `EditorView` insertion.
- [ ] P5 Message rendering (L): markdown parser and view, tool-call rows, streaming cursor.
- [ ] P6 Provider setup and detection UI (M): readiness, toolchain resolution, provider picker.
- [ ] P7 Thread management (S): thread store, rename/switch/delete, minimal slash resolver.
