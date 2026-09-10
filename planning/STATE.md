# State

Last updated: 2026-09-04

## Position

- Milestone 00 fork setup is complete and merged to `main` through PR #1.
- Milestone 01 test foundation is complete and merged to `main` through PR #2.
- Milestone 02 lossless cut is implemented with green CI on PR #3, now based on `main`; manual editor checks remain.
- Milestone 03 music tracks is implemented with green CI on PR #5, based on milestone 02; manual editor, preview-sync, and export checks remain.
- Milestone 04 agent chat phases 1–3 are implemented with green CI on PR #6: provider argument builders and stream parsers, process runner, transcript persistence, and session actor. The UI phases remain. ADR 0010 supersedes the planned thread list: one persisted, clearable conversation belongs to each project and each turn uses a fresh CLI process.
- Milestone 05 read-only agent tools is implemented on `milestone-05-agent-tools`: JSON-RPC codec, MCP-shaped catalog and results, read-only summaries, dispatcher, preview frames, authenticated Unix socket, and sibling `.agent/` workspace. Local verification is green and PR #7 is open; CI is pending.
- Milestone 07 has silence removal and text overlays on green PR #4. Image-overlay planning is committed in its worktree, with four uncommitted red-test/fixture files preserved; image production code has not started.

## Verified on this machine

- On `milestone-05-agent-tools`, `make build`, `make lint`, and `make test` pass: 385 tests in 46 suites.
- `AgentBridgeServerTests`: 6 tests pass, covering authentication, initialization, catalog and tool calls, structured errors, timeout, and shutdown.
- `AgentWorkspaceTests`: 6 tests pass, covering sibling placement, long socket paths, private session metadata, token replacement, and cleanup.

## Accepted product decisions

- Final product name: AppShow. Keep inherited names and identifiers during feature development, then perform one pre-release identity migration (ADR 0005).
- One conversation per `.frm` project, persisted in the bundle and explicitly clearable; no thread list (ADR 0010).
- One fresh Claude Code or Codex process per user turn (ADR 0010).
- Socket, token, and rendered-frame state stays in the sibling `.agent/` workspace; the conversation travels inside the project.
- Finish chat UI before resuming image overlays.

## Next

1. Verify CI on PR #7.
2. Update milestone 04 from a thread-list UI to one project conversation, then implement panel, rendering, setup, clear, and persistence UI phases test-first.
3. Integrate chat and read-only tools before adding mutating tools in milestone 06.
4. Resume image overlays from the preserved tests, then blur and transitions.
5. Complete the manual verification rows on PRs #3–#7 before merging them.
