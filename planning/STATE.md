# State

Last updated: 2026-09-04

## Position

- Milestones 00 and 01 are merged into `main`: PR #1 fork setup and PR #2 test foundation.
- Milestone 02 lossless cut is code-complete on PR #3; its manual checks remain.
- Milestone 03 music tracks is code-complete on PR #5; its manual checks remain.
- Milestone 04 agent chat is code-complete on PR #6 with one persisted, clearable conversation per project and provider-specific session resumption; its manual checks remain.
- Milestone 05 read-only agent bridge is code-complete on PR #7.
- Milestone 06 is code-complete on green PR #8, including live Claude Code and Codex MCP verification; its manual UI checks remain.
- Milestone 07 PR #4 contains silence removal, text overlays, image overlays, and source-space blur regions. T1 to T7 are code-complete; broader transition work remains. Its manual checks remain.

## Verified on this machine

- Blur-region format, lint, build, 379 tests in 39 suites, and 3 gated export tests are green.
- `TEST_RUNNER_REFRAMED_RUN_EXPORT_TESTS=1 make test T=ExportPipelineTests` green on `milestone-02-lossless-cut`.

## Notes for the next session

- Product name: AppShow. Keep inherited Reframed identifiers until the pre-release rename (ADR 0005).
- Agent conversation contract: exactly one per project, stored inside `.frm`; explicit clear; ephemeral socket/token/frame workspace in sibling `.agent`; fresh process each turn with provider-specific logical-session resumption.
- Silence removal keeps its settings in the panel only; `HistoryEntry.label` is the hook for one labelled snapshot per tool call.
- Upstream quirks pinned by characterization tests, candidates for fixes: audio-mix index pairing with click sounds, custom camera region border unscaled on the trim path, colour-matched solid backgrounds in the 8-bit render path, unclamped zoom hold keyframe, `FrameRenderer.visibleText` crash/loop edge cases.

## Next

1. Commit and push blur regions, then verify PR #4 CI.
2. Human runs the manual rows for milestones 02, 03, 04 and 07.
3. Forward-integrate blur into milestone 06 and add its agent tool.
4. Implement the remaining transition work in milestone 07.
5. Add the dedicated AppShow identity migration before the first public release.
