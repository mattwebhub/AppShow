# State

Last updated: 2026-09-04

## Position

- Milestones 00 and 01 are merged into `main`: PR #1 fork setup and PR #2 test foundation.
- Milestone 02 lossless cut is code-complete on green PR #3; its manual checks remain.
- Milestone 03 music tracks is code-complete on green PR #5; its manual checks remain.
- Milestone 04 agent chat is code-complete on green PR #6: one persisted conversation per project, fresh provider process per turn with resume ids, collapsible streamed UI, Markdown/code/tool rendering, and readiness guidance. Its manual checks remain.
- Milestone 05 read-only agent tools is code-complete on green PR #7: JSON-RPC codec, MCP-shaped catalog and results, dispatcher, preview frames, authenticated Unix socket, and sibling `.agent/` workspace.
- Milestone 06 is code-complete on PR #8; it integrates milestones 03–05 and milestone 07's completed primitives. Labeled history, rollback, exact cuts, grouped transactions, single-use confirmations, provider-scoped MCP configuration, the signed stdio shim, bridge lifecycle, live activity UI, presentation settings, timed captions, workspace-only draft export, confirmed exact-path full export, silence removal, external music, transitions, text/image/blur tools, and five dual-provider skills are implemented test-first. Both providers pass the live MCP read/mutate/undo path and discover and invoke the bundled title skill; manual UI checks remain.
- Milestone 07 PR #4 contains silence removal, text overlays, image overlays, source-space blur regions, and entry/exit transitions on overlays and kept slices. T1 to T9 are code-complete; its manual checks remain.
- Milestone 08 is complete as a verified no-op: the freshly fetched `upstream/main` and the fork base are both `b6a1709` (v0.14.7), so there was nothing to merge before the identity migration.
- Milestone 09 AppShow identity is implementation-complete and locally verified: the build graph, bundle identifiers, runtime contracts, new `.appshow` project type, safe legacy migration, release metadata, living documentation, and GitHub repository are renamed. Legacy `.frm`, `~/.reframed`, selected `REFRAMED_*` ingress values, upstream attribution, and recorded fixtures remain deliberately compatible.

## Verified on this machine

- Agent chat: format, lint, build, and 403 tests in 40 suites pass on `milestone-04-agent-chat`; PR #6 is green.
- Read-only agent tools: build, lint, and 385 tests in 46 suites pass on `milestone-05-agent-tools`; PR #7 is green.
- Image overlays: format, lint, build, and 366 tests in 37 suites pass on `milestone-07-primitives`; PR #4 is green.
- Milestone 06 integrated editing surface: format, lint, build, and 669 tests in 76 suites pass; 5 gated export tests, 2 gated presentation-scenario tests, the gated real-process shim test, and both gated live-provider skill cases pass.
- Provider E2E: Codex 0.149.1 passed with its configured model; Claude Code 2.1.260 passed with `sonnet` because the configured Fable quota was exhausted. The first Claude attempt exposed and led to a fix for missing `USER`/`LOGNAME` in the scrubbed child environment.
- Skill E2E: Codex expanded `$add-title-cards`; Claude listed and invoked `/add-title-cards`; both called the signed AppShow bridge and left exactly one requested title overlay in a fresh project. The gated command is `make test-agent-skills CLAUDE_MODEL=sonnet`.
- Presentation scenario: `make test-scenario` replays a checked-in multi-tool batch, proves persistence and one-step Undo, and exports a private 640 px/15 fps draft with the 12-second kept duration.
- Blur-region format, lint, build, 379 tests in 39 suites, and 3 gated export tests pass on `milestone-07-primitives`.
- `TEST_RUNNER_APPSHOW_RUN_EXPORT_TESTS=1 make test T=ExportPipelineTests` is green on `milestone-02-lossless-cut`.
- Milestone 09: format, lint, Debug build, 678 tests in 76 suites, shim, 5 export tests, 2 presentation-scenario tests, and live Claude Code/Codex skill invocation all pass. A clean clone at `675c9bd` also passes lint, build, 11 identity/path tests, and 17 project tests. `dist/AppShow-0.14.7.dmg` contains a universal `x86_64 arm64` AppShow app with the correct identifiers and a valid image checksum; it is ad-hoc signed and not notarized.

## Accepted product decisions

- Final product name: AppShow. Keep inherited names and identifiers during feature development, then perform one pre-release identity migration (ADR 0005).
- Each project bundle (`.appshow`, or legacy `.frm`) owns exactly one persisted, explicitly clearable conversation; there is no thread list (ADR 0010).
- Each turn launches a fresh Claude Code or Codex process and resumes through that provider's stored logical-session id (ADR 0010).
- Socket, token, and rendered-frame state stays in the sibling `.agent/` workspace; the conversation travels inside the project.
- The agent may mutate the project through typed tools, with confirmation for sensitive file access and one labelled undo step per call or batch. Draft exports stay in the ephemeral workspace; any full-export tool must be explicitly confirmed in-app.

## Notes

- Manual verification is deliberately not inferred from automated tests; the pending rows live in each milestone's `VERIFY.md`.
- Silence removal keeps its settings in the panel only; `HistoryEntry.label` is the hook for one labelled snapshot per agent tool call.
- Upstream quirks pinned by characterization tests, candidates for fixes: audio-mix index pairing with click sounds, custom camera region border unscaled on the trim path, colour-matched solid backgrounds in the 8-bit render path, unclamped zoom hold keyframe, `FrameRenderer.visibleText` crash/loop edge cases.

## Next

1. Run the remaining human UI rows for milestone 06 and review its stacked PR.
2. Human runs the manual rows for milestones 02, 03, 04, and 07.
3. Review milestone 09's stacked PR and arrange Developer ID signing/notarization before a public release.
