# Milestone 21: Sandboxed Codex, Claude and MCP

The owner requires the project assistant and MCP editing tools in the Store product, with both Codex and Claude Code integrations pursued under App Sandbox. See [ADR 0020](../../decisions/0020-retain-sandboxed-store-agents.md).

- [x] Check Apple's current sandbox/helper requirements and both providers' current integration guidance.
- [x] Build an isolated native App Sandbox probe without temporary exceptions or personal credential access.
- [x] Prove container writes succeed and an external sentinel write fails in the parent and an inherited child.
- [x] Start both bundled provider binaries and query their authentication state using fresh container directories.
- [x] Run AppShow's actual stdio MCP shim against an authenticated Unix-socket fixture; complete initialize, tools/list and tools/call.
- [x] Have Codex discover the fixture tool and Claude report the same shim connected under the sandbox.
- [ ] Settle exact runtime packages, architectures, licenses/notices and signing requirements, including Claude's unmodified-binary condition.
- [x] Add tests before replacing Store blanket process guards with bundled-runtime resolution and container-only provider state. Reject outside-bundle executable resolution and inherited user CLI configuration.
- [x] Restore the chat panel, bundle the MCP shim/resources in the Store target, and relocate ephemeral workspaces into container storage while keeping conversations portable.
- [x] Implement provider-owned sign-in and cancellation inside the sandbox, with container-local state and no copying/intermediation of existing subscription tokens.
- [ ] Exercise a live authenticated turn through each provider: inspect project, make one reversible edit through MCP, show streamed activity, undo, resume, cancel and recover after relaunch.
- [ ] Exercise denied/revoked file access, multiple projects, export confirmation, malformed/unauthenticated MCP requests and helper shutdown when the app quits.
- [x] Adapt and validate Toone's managed automatic CLI updater for the direct edition, preserving the Store-only update boundary.
- [x] Add per-edition runtime update guidance, visible versions, stable version pins, update discovery and verified staging with failure recovery (ADR 0021).
- [x] Update the Store artifact evaluator for intentionally bundled signed helpers; keep sandbox and no-updater checks enforced.
- [ ] Complete direct/Store builds, relevant tests, candidate runtime/signature checks and reviewer access before new final Store assets.

## Acceptance

The exact sandboxed Store candidate exposes its real conversation panel and supports authenticated Codex and Claude editing through the existing typed tools. All required code ships in the reviewed app, provider and filesystem boundaries hold, and the full demo is repeatable after cold relaunch. Feasibility probes and a successful MCP health check do not close this milestone.

## September 9 runtime follow-up

Pinned universal runtimes, container state, native sign-in, the restored bridge and PNG MCP content are implemented. Real sandboxed Codex login, editing, Undo/Redo, resumption and image inspection passed. A later send in the longer conversation stalls in SwiftUI layout before the provider launches. Isolated hosted conversation layout did not reproduce it; attempted scroll, host-sizing and composer changes did not resolve the live issue and were reverted. The original process sample and conversation snapshot are in ignored `dist/sandbox-agent-probe/`. Claude account verification remains pending. Do not mark this milestone complete.

The owner initially paused listing uploads for Figma editing. On September 10, the owner approved uploading the revised four-frame set and preparing the release. This supersedes the listing pause. Runtime acceptance and the no-new-recordings instruction still apply.

## Runtime update verification

The update workflow passes ten offline staging/discovery/recovery tests, nine readiness tests (including version refresh without login), five runtime-policy tests and three sandbox-hosted tests. Both Debug editions build without warnings; format/lint and all 16 checks on the rebuilt normal Store artifact pass. The first post-test audit correctly refused the Xcode-injected test host; rebuilding removed those test-only entitlements. Exact evidence lives in `dist/sandbox-agent-probe/runtime-updates/`.

The native Settings popover exposes Agents. The rest of that visual walkthrough remained manual because desktop actions were interrupted by concurrent window changes. New upstream runtime versions were discovered but not adopted or claimed compatible for Store. No new recordings were made.

## Direct automatic update acceptance

Toone's automatic-update design is adapted to AppShow's direct edition: daily checks, six-hour retries, a persisted toggle, explicit missing-provider installation, verified managed releases and newest-compatible-candidate selection. The complete Codex package switches through one release-directory pointer. Background discovery does not execute shell profiles, and provider self-update is suppressed within AppShow to preserve user-owned installations.

Verification: all 811 tests in 98 suites pass. A captured-reference warning in the new schedule fixture was corrected; all six schedule tests then passed without warnings. Formatting/lint, project validation and warning-free final direct/Store Debug builds pass. Three Store-hosted smoke tests and all 16 checks on the rebuilt normal Store artifact pass. Store symbols exclude the direct updater, installer and network classes.

An isolated executable linked to the actual AppShow debug library downloaded Claude Code 2.1.267 and the full Codex 0.153.4 package, verified their official checksums, signatures and exact versions, activated the managed pointers and selected them through the production toolchain. Its temporary runtime folders were removed afterward. Evidence is in ignored `dist/sandbox-agent-probe/automatic-runtime-updates/`.

The real direct app was opened through native UI. Settings → Agents exposes the toggle, manual check, provider versions and secondary installation help; automatic updating started at launch and completed with Claude 2.1.267 and Codex 0.154.0 in AppShow-managed release folders. The native Settings results and enabled manual-check action confirmed completion; the Codex release became available after the earlier isolated probe. Native screenshot capture still returns the toolbar's narrow window rather than the settings popover, so pixel-level appearance has not been verified. Existing Store candidate, Claude-account and long-conversation acceptance items remain open. No recording or Store submission was made.

## September 10 release preparation

Both providers completed live authenticated MCP title edits in Debug Store. The exact prior long-history request completes after eager transcript layout; Claude's global temporary-directory failure is resolved with private Store-container temporary storage. Native Undo revealed a stale history baseline, now covered by failing-then-passing individual/batch regressions and the complete 32-test editing suite. See [chat acceptance](CHAT-ACCEPTANCE.md). The final universal candidate and remaining cancellation, file/hardware and reviewer-access matrix remain open.

App Store Connect record <app id> is created for team <team id>. All four owner-approved screenshots and the listing copy are uploaded and verified in the saved draft. No new recording, binary upload, tag or App Review submission occurred.
