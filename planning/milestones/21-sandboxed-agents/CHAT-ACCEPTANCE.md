# Conversation layout acceptance

## Regression reproduced before the change

Date: September 10, 2026. macOS 26.5.2; universal Release archive 0.14.7 / 26, Apple Development signed with App Sandbox enabled.

1. Copy the existing cropped demo into `dist/app-store-submission/2026-09-10-owner-approved/runtime-evidence/Release acceptance.appshow`. Preserve its multi-turn conversation and completed MCP tool rows; keep the presentation project untouched.
2. Open the copy in the exact archived `AppShowStore.app` through Finder's Open With → Other.
3. Wait for bundled Codex to show Ready. Send: “Use get_project_summary only. Reply with the project title and duration. Do not inspect images, export, or modify edits.”
4. Accept the provider-sharing prompt for this previously authorized demo.

Expected: the editor remains responsive, the MCP tool row and response appear, and the reply settles. The project edits remain unchanged.

Observed before the change: the UI stops responding; the main thread remains near 100% CPU in SwiftUI root geometry, stack measurement and lazy-stack placement. Release logs confirm that Codex starts and connects to MCP, but the persisted new reply remains empty and streaming. The test process was force-quit after collecting `runtime-evidence/release-chat-stall.sample.txt`.

The isolated SwiftUI hosting test with generated tool-heavy history passes on the original implementation. It checks finite sizing while streaming but does not reproduce this complete editor failure and must not be used to close it. The native regression above is the required before/after test.

## Verification required after a change

- Repeat the exact native case with the copied history and capture a completed response plus a usable editor control afterward.
- Send a subsequent reply, resize the conversation panel and check scrolling to old tool rows and back.
- Verify failure/cancellation recovery without losing prior project edits.
- Run focused layout/transcript tests, formatting/lint, direct and Store builds, and the normal Store artifact audit.
- Rebuild and repeat the successful native case on the final universal candidate before upload. Claude authentication remains an independent acceptance item.

## September 10 fixes and native results

Changing the transcript from LazyVStack to VStack allowed the same copied history and project-summary request to finish in Debug Store. A subsequent Codex title-only edit completed, streamed its MCP activity and left the editor responsive. The hosted smoke test is still only a bounded layout check; its NSHostingView fixture disables automatic content-size constraints so window-size assertions are deterministic. It is not evidence that the full editor regression is reproduced by a unit test.

Claude was authenticated but its first live request failed with `EPERM` creating `/tmp/claude-501`. Store runtime policy now creates private container temporary storage with mode 0700 and overrides both `TMPDIR` and Claude's documented `CLAUDE_CODE_TMPDIR`. A failing policy regression precedes the fix; all 34 focused runtime/layout/transcript tests then passed. Retrying the interrupted native Claude request completed `mcp__appshow__update_text` and a final response; Undo restored the title.

The native Undo check also exposed a separate stale history baseline: a previously changed canvas could be restored to an older style. Agent calls and explicit batches now checkpoint the actual pre-edit state. Both new parameterized regressions failed before the fix. All 32 editing tests pass after preserving the baseline and avoiding duplicate entries for handlers that already record their changes, including silence removal.

Exact updated universal-candidate checks, panel resizing/scrolling, cancellation and cold-relaunch recovery remain required. The initial September 10 archive predates these fixes and was removed after retaining its audit/receipt to make space for its replacement.
