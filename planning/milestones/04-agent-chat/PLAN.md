# Milestone 04: agent-chat

Goal: the editor has a collapsible left chat panel that runs a fresh Claude Code or Codex process per turn, streams and renders the reply, persists one conversation in the project bundle, and guides setup, without touching the project yet.

Depends on: milestone 02 (editor layout as of the Cuts track); ADR 0009 accepted.

## Tasks

- [x] T0. ADR 0009 accepted by the owner. Proof: status line in the ADR.
- [x] T1. P1 providers and parsers. Proof: provider test suites green on recorded fixtures.
- [x] T2. P2 process runner. Proof: `AgentProcessRunnerTests` including cancellation.
- [x] T3. P3 transcript and persistence. Proof: `AgentTranscriptTests`.
- [x] T4. P4 panel shell. Proof: `AgentPanelLayoutTests`, `StateServiceAgentPanelTests`, `ConfigServiceAgentTests`; manual look check remains in `VERIFY.md`.
- [x] T5. P5 rendering. Proof: `AgentMarkdownParserTests`; manual streaming check remains in `VERIFY.md`.
- [x] T6. P6 setup UI. Proof: `AgentReadinessTests` and `AgentToolchainTests`.
- [x] T7. One conversation per project and explicit clear. Proof: `AgentConversationStoreTests`, `AgentTranscriptTests`, ADR 0010.
- [x] T8. Security test forbidding bypass flags; docs (`AGENTS.md`, `docs/editor.md`, architecture map), `upstream-sync.md`. Proof: `AgentSecurityTests` and source grep.
- [x] T9. VERIFY.md, branch pushed, PR #6 refreshed. Manual rows remain open in `VERIFY.md`.

## Out of scope

Tools, MCP, skills, project mutation (milestones 05 to 07).

## Risks

- CLI protocol drift across Claude Code and Codex releases: pin recorded fixtures per version and keep parsers tolerant of unknown event types.
- Strict-concurrency port of Swift 5 code: rewrite process and session classes as actors rather than copying.
