# State

Last updated: 2026-09-04

## Position

- Milestones 00 and 01 are merged into `main`: PR #1 fork setup and PR #2 test foundation.
- Milestone 02 lossless cut is code-complete on PR #3; its manual checks remain.
- Milestone 03 music tracks is code-complete on PR #5; its manual checks remain.
- Milestone 04 agent chat is on `milestone-04-agent-chat`: one persisted conversation per project, fresh provider process per turn with resume ids, collapsible streamed UI, Markdown/code/tool rendering, and readiness guidance are implemented. Final verification and PR refresh are next.
- Milestone 05 read-only agent bridge is code-complete on PR #7.
- Milestone 07 PR #4 contains silence removal and text overlays. Image overlays resume only after milestone 04 closes.

## Verified on this machine

- Chat P4–P6 focused tests, formatting, lint, and build are green on `milestone-04-agent-chat`.
- The last full chat run before readiness/rendering contained 391 tests in 38 suites; a fresh full gate is required before close.

## Notes for the next session

- Product name: AppShow. Keep inherited Reframed identifiers until the pre-release rename (ADR 0005).
- Agent conversation contract: exactly one per project, stored inside `.frm`; explicit clear; ephemeral socket/token/frame workspace in sibling `.agent`; fresh process each turn with provider-specific logical-session resumption (ADR 0010).
- Preserve the image-overlay worktree until chat verification and PR work are complete.
- Upstream quirks pinned by characterization tests, candidates for fixes: audio-mix index pairing with click sounds, custom camera region border unscaled on the trim path, colour-matched solid backgrounds in the 8-bit render path, unclamped zoom hold keyframe, `FrameRenderer.visibleText` crash/loop edge cases.

## Next

1. Run the full milestone 04 gate, update `VERIFY.md`, push the branch, and refresh PR #6.
2. Complete the chat manual checks with a real provider and inspect the panel in light/dark appearance.
3. Resume image overlays, then continue milestone 06 editing tools.
