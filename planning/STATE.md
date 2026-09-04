# State

Last updated: 2026-09-04

## Position

- Milestones 00 and 01 are merged into `main`: PR #1 fork setup and PR #2 test foundation.
- Milestone 02 lossless cut is code-complete on green PR #3; its manual checks remain.
- Milestone 03 music tracks is code-complete on green PR #5; its manual checks remain.
- Milestone 04 agent chat is code-complete on green PR #6: one persisted conversation per project, fresh provider process per turn with resume ids, collapsible streamed UI, Markdown/code/tool rendering, and readiness guidance. Its manual checks remain.
- Milestone 05 read-only agent tools is code-complete on green PR #7: JSON-RPC codec, MCP-shaped catalog and results, dispatcher, preview frames, authenticated Unix socket, and sibling `.agent/` workspace.
- Milestone 06 integrates milestones 03–05 on `milestone-06-agent-tools-editing`; labeled/deduplicated history, rollback, explicit mutation opt-in, `set_trim`, `add_zoom`, and `add_spotlight` are implemented test-first. Batches, confirmations, shim wiring, broader tools, and live activity UI remain.
- Milestone 07 PR #4 contains silence removal, text overlays and image overlays with green CI. T1 to T6 are code-complete; blur regions and broader transition work remain. Its manual checks remain.

## Verified on this machine

- Agent chat: format, lint, build, and 403 tests in 40 suites pass on `milestone-04-agent-chat`; PR #6 is green.
- Read-only agent tools: build, lint, and 385 tests in 46 suites pass on `milestone-05-agent-tools`; PR #7 is green.
- Image overlays: format, lint, build, and 366 tests in 37 suites pass on `milestone-07-primitives`; PR #4 is green.
- Milestone 06 transaction foundation: format, lint, build, and 523 tests in 60 suites pass on `milestone-06-agent-tools-editing`.
- `TEST_RUNNER_REFRAMED_RUN_EXPORT_TESTS=1 make test T=ExportPipelineTests` is green on `milestone-02-lossless-cut`.

## Accepted product decisions

- Final product name: AppShow. Keep inherited names and identifiers during feature development, then perform one pre-release identity migration (ADR 0005).
- Each `.frm` owns exactly one persisted, explicitly clearable conversation; there is no thread list (ADR 0010).
- Each turn launches a fresh Claude Code or Codex process and resumes through that provider's stored logical-session id (ADR 0010).
- Socket, token, and rendered-frame state stays in the sibling `.agent/` workspace; the conversation travels inside the project.
- The agent may mutate the project and trigger exports through typed tools, with confirmation for sensitive file access and one labelled undo step per call or batch.

## Notes

- Manual verification is deliberately not inferred from automated tests; the pending rows live in each milestone's `VERIFY.md`.
- Silence removal keeps its settings in the panel only; `HistoryEntry.label` is the hook for one labelled snapshot per agent tool call.
- Upstream quirks pinned by characterization tests, candidates for fixes: audio-mix index pairing with click sounds, custom camera region border unscaled on the trim path, colour-matched solid backgrounds in the 8-bit render path, unclamped zoom hold keyframe, `FrameRenderer.visibleText` crash/loop edge cases.

## Next

1. Continue milestone 06 with cut semantics, grouped undo, confirmations, shim wiring, broader mutating tools, and live activity UI.
2. Human runs the manual rows for milestones 02, 03, 04, and 07.
3. Implement blur regions and remaining transition work in milestone 07.
4. Add the stdio shim, skills, and end-to-end presentation flow after the editing tool surface is stable.
5. Perform the AppShow identity migration before the first public release.
