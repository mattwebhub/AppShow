# Milestone 04: agent-chat

Goal: the editor has a collapsible left chat panel that runs a Claude Code or Codex session per turn, streams and renders the reply, persists threads in the bundle, and guides setup, without touching the project yet.

Depends on: milestone 02 (editor layout as of the Cuts track); ADR 0009 accepted.

## Tasks

- [x] T0. ADR 0009 accepted by the owner. Proof: status line in the ADR.
- [x] T1. P1 providers and parsers. Proof: provider test suites green on recorded fixtures.
- [x] T2. P2 process runner. Proof: `AgentProcessRunnerTests` including cancellation.
- [x] T3. P3 transcript and persistence. Proof: `AgentTranscriptTests`.
- [ ] T4. P4 panel shell. Proof: `AgentPanelStateTests`; manual look check.
- [ ] T5. P5 rendering. Proof: `AgentMarkdownParserTests`; manual streaming check.
- [ ] T6. P6 setup UI. Proof: readiness and toolchain tests.
- [ ] T7. P7 threads. Proof: `AgentThreadStoreTests`.
- [ ] T8. Security test forbidding bypass flags; docs (`AGENTS.md`, `docs/editor.md`), `upstream-sync.md`. Proof: grep.
- [ ] T9. VERIFY.md, push, PR.

## Out of scope

Tools, MCP, skills, project mutation (milestones 05 to 07).

## Risks

- CLI protocol drift across Claude Code and Codex releases: pin recorded fixtures per version and keep parsers tolerant of unknown event types.
- Strict-concurrency port of Swift 5 code: rewrite process and session classes as actors rather than copying.
