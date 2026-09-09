# State

Last updated: 2026-09-09

## Position

- Milestones 00 and 01 are merged into `main`: PR #1 fork setup and PR #2 test foundation.
- Milestone 02 lossless cut is code-complete on green PR #3; its manual checks remain.
- Milestone 03 music tracks is code-complete on green PR #5; its manual checks remain.
- Milestone 04 agent chat is code-complete on green PR #6: one persisted conversation per project, fresh provider process per turn with resume ids, collapsible streamed UI, Markdown/code/tool rendering, and readiness guidance. Its manual checks remain.
- Milestone 05 read-only agent tools is code-complete on green PR #7: JSON-RPC codec, MCP-shaped catalog and results, dispatcher, preview frames, authenticated Unix socket, and sibling `.agent/` workspace.
- Milestone 06 is code-complete on PR #8; it integrates milestones 03–05 and milestone 07's completed primitives. Labeled history, rollback, exact cuts, grouped transactions, single-use confirmations, provider-scoped MCP configuration, the signed stdio shim, bridge lifecycle, live activity UI, presentation settings, timed captions, workspace-only draft export, confirmed exact-path full export, silence removal, external music, transitions, text/image/blur tools, and five dual-provider skills are implemented test-first. Both providers pass the live MCP read/mutate/undo path and discover and invoke the bundled title skill; manual UI checks remain.
- Milestone 07 PR #4 contains silence removal, text overlays, image overlays, source-space blur regions, and entry/exit transitions on overlays and kept slices. T1 to T9 are code-complete; its manual checks remain.
- Milestone 08 is complete as a verified no-op: the freshly fetched `upstream/main` and the fork base are both `b6a1709` (v0.14.7), so there was nothing to merge before the identity migration.
- Milestone 09 AppShow identity is complete on green PR #10: the build graph, bundle identifiers, runtime contracts, new `.appshow` project type, safe legacy migration, release metadata, living documentation, and GitHub repository are renamed. Legacy `.frm`, `~/.reframed`, selected `REFRAMED_*` ingress values, upstream attribution, and recorded fixtures remain deliberately compatible.

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
- PR #10's first runner exposed a stale Swift-package cache missing Sparkle's XCFramework. CI now caches only portable package repositories, checkouts, and artifacts under a versioned key and resolves dependencies explicitly; the replacement run passed in 7m03s.

## Interactive testing fixes (2026-09-04)

The interactive testing fixes add cut-slice selection and Delete/Backspace/toolbar deletion with immediate Undo, shared cut-boundary repositioning, and visible drag handles. Source video remains unchanged (byte-for-byte regression test). Zoom regions can be moved/resized in source or compressed mode, with one timing calculation for preview and commit. Right-click overlays pass ordinary mouse interaction through. Complete provider messages retain paragraph boundaries, and chat renders headings, lists, paragraphs, links, quotes and code with spacing.

Verification: `make format`, `make lint`, `make build`, 690 tests in 76 suites, and 5 gated export tests pass. Human drag/selection and fresh-chat appearance checks remain pending on the updated app. These fixes are committed locally; they have not been pushed.

## Publication review

The focused review at `planning/reviews/2026-09-04-publication-review.md` patches trim/export consistency, saved trim reopening, renamed conversation persistence and bridge relocation, canceled request queues and unfinished batches, music gain after cuts, confirmation text, and export progress cleanup. The 694-test full suite, additional saved-trim regression, 8 bridge tests, 5 gated exports, format, lint and warning-free Debug build pass. Changes are committed locally, with no GitHub publication.

## Webcam presentation

Milestone 10 is code-complete on local branch `webcam-presentation-and-review`: Include webcam, saved corner/size defaults, circular new-recording layout, timed Focus webcam with animated expansion/return, source/compressed timeline editing, numeric timing, and MCP camera-region CRUD. Existing projects retain saved styling. Camera Undo, SDR/HDR fullscreen parity and cut-boundary transition timing were corrected with regressions.

Verification: 707 tests in 78 suites, 6 gated export tests (including SDR and HDR webcam-focus cases), format, lint, warning-free Debug build and project validation pass. Real camera, drag interaction and live-provider checks remain manual in milestone 10 VERIFY.md. No changes have been pushed.

## Webcam layouts, voice and spoken context

Milestone 11 is code-complete locally: left/right half and third webcam sections share animated geometry across preview, MCP preview, SDR and HDR. Include webcam exposes microphone selection, noise cleanup and automatic captions using the existing capture/RNNoise/WhisperKit pipeline. Per-track narration persists independently of caption edits and supplies project overview and source-time frame context; `generate_transcript` preserves visible captions. MCP wire names retain the verb/noun convention with editor-area catalog titles.

Silence removal commits ordinary editable cuts with immediate Undo, stale-preview rejection, cancellation, stereo phase protection and audio-drift alignment. Long analysis refuses commits after a grouped edit ends or is canceled. New state is documented in ADRs 0012/0013 and covered by persistence/history regressions.

Verification: 727 tests in 82 suites, six gated export tests covering eleven encoded cases, format, strict lint, project validation and warning-free Debug build pass. Hardware capture, real speech quality, gesture interaction and live-provider checks remain manual. Changes are local; nothing has been pushed.

## Caption typography and colors

Milestone 12 is code-complete locally: searchable installed fonts, visible style controls before transcription, font/background color controls, shared preview/export font resolution, portable system fallback and font-family persistence/history. The existing `set_captions` MCP tool now exposes font family and RGBA colors; timeline inspection returns style. Recorded narration remains independent.

Verification: 733 tests in 83 suites, format, lint, project validation and warning-free Debug build pass. Interactive font/color selection and exported-video comparisons remain manual in milestone 12 VERIFY.md. No changes have been pushed.

## Permission recovery

Milestone 13 adopts Toone's shared observable permission status, activation refresh, explicit requests, Settings links and Accessibility transition handling. The editor and toolbar remain accessible; denied capture opens the recovery screen. Continue stays visible, and Finder reveals the exact running bundle for stale-entry recovery. Global shortcuts are installed only while Accessibility is granted and refreshed after grant/revocation.

Verification: 737 tests in 84 suites, format, lint, warning-free Debug build, project and signature validation pass. Runtime confirmed both permissions denied for the signed process; only AppShow's ScreenCapture and Accessibility entries were reset through macOS, then the app was reopened for fresh user grants. Actual grants and recording remain manual. Local signing uses the developer's existing certificate via ignored Local.xcconfig. Nothing has been pushed.

The permission UI follow-up uses the existing Settings typography, spacing and monochrome controls, aligned action columns, collapsed recovery help and a fixed Continue footer. Light/dark native renders, expanded recovery, four permission tests, format, lint, build and signature checks pass; the updated app was reopened.

## Public presentation

Milestone 14's assets and documentation are complete locally: the supplied brushstroke artwork is preserved unchanged, the macOS icon fills all ten asset-catalog slots, and `make brand` regenerates the icon, README banner, and social preview. The README introduces the product workflow and source-build availability; a documentation index, contributor guide, and issue/PR templates support public contributions. Existing upstream attribution and license notices are retained.

Verification: format, lint, warning-free Debug build, signature validation, icon dimensions and pixel transparency, artwork identity, local links, SVG and issue-form syntax all pass. Local GitHub-flavored Markdown previews were inspected at desktop and mobile widths. No runtime code changed; the test suite was not rerun for this asset/documentation change. A current AppShow editor capture, Dock inspection, publication, and social-preview upload remain pending in milestone 14's verification record. Nothing has been pushed.

## Area effects and conversation recovery

Milestone 15 implements right-click microphone removal using the existing persisted mute state, immediate Undo, and preserved source media. A shared source-frame picker adds timed blur and area zoom. Area zoom persists its normalized target per keyframe, fits the selection up to 8×, and bypasses cursor following in preview and SDR/HDR export while allowing cursor-based zooms elsewhere. The existing `add_zoom` tool accepts `mode=area`; timed blur retains `add_blur`, `update_blur`, and `remove_blur`.

Assistant replies are checkpointed during streaming. Early EOF and reopened streaming messages become recoverable failures, unfinished tool rows explain their unknown outcome, and terminal provider events release a hung process. Retry preserves provider resume IDs; Start fresh retains local conversation context while opening a new provider session. Both ask the assistant to inspect current state before continuing. The full suite passes 752 tests in 87 suites, seven gated export tests pass, and six recovery tests pass again against the final build. Format, lint, warning-free build, project/signature validation pass; the updated app was reopened. Pointer interactions and real-provider recovery remain manual in milestone 15's `VERIFY.md`. Changes remain local.

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

Use the [public-release checklist](releases/PUBLIC-RELEASE-CHECKLIST.md) and its [App Store readiness evaluation](releases/APP-STORE-EVAL.md) to track distribution gates. Both channels currently remain NOT READY.

1. Restart the updated Debug build and run milestone 10’s real-webcam and interaction checks, then the remaining milestone 06 rows.
2. Human runs the manual rows for milestones 02, 03, 04, and 07.
3. Review green milestone 09 PR #10 and arrange Developer ID signing/notarization before a public release.


## Speed regions

Milestone 16 is code-complete locally: selected source-time ranges support 1.5×, 2×, 4×, 8×, 16×, and 32× with the existing region editing controls, a draggable/resizable Speed track, right-click editing/removal, project persistence, immediate Undo/Redo, and agent CRUD. Shared timing maps combine speed with cuts and trim for preview transport, exports, effects, imported-audio fades, and subtitle sidecars. Recorded and imported preview audio use pitch-preserving time stretching. Export writers explicitly end at the computed output duration, eliminating intermittent audio tails.

Verification: 766 tests in 89 suites and nine gated export tests pass, including every preset with encoded audio and speed/cut/effect combinations across SDR/HDR and normal/parallel export. Format, lint, project validation, whitespace checks, warning-free Debug build, and strict signature verification pass; the updated app was reopened. Real-media listening, gestures, and live-provider invocation remain manual in milestone 16 VERIFY.md. Changes remain local and have not been pushed.


### Screen-only speed correction

Speed now affects the screen recording, system audio and click audio. Webcam, microphone and imported music retain 1× timing, with their existing cuts/trim and a shared end at the shortened screen duration. Native seeking, agent frame previews, microphone captions and subtitle sidecars use the independent normal-speed clock. Screen effects and system-audio captions retain screen timing. This supersedes milestone 16's original all-track speed behavior.

Verification: 770 tests in 89 suites pass on a retry after an unchanged agent readiness timeout test stalled. Ten gated export tests plus a focused microphone/music export test pass, including actual webcam frame positions in normal/parallel export, all six speed presets, and SDR/HDR combinations. Real-media listening and gestures remain manual.

The corrected Debug build is warning-free, lint and strict signature verification pass, and the updated app was reopened. No changes were pushed.

## Local commit checkpoint (2026-09-09)

Milestones 14–16 and the App Store readiness assessment are committed on `webcam-presentation-and-review`. The commits separate brand assets, public documentation, assistant recovery, microphone removal, area effects, speed timing, export, playback, timeline controls, and agent tools.

Fresh verification: `make format`, `make lint`, warning-free `make build`, all 770 tests in 89 suites, and all 11 gated `ExportPipelineTests` pass. The gated cases cover the speed presets, normal-speed webcam/narration/music, cuts, area effects, and SDR/HDR exports. No changes were pushed. Existing manual interaction, real-media listening, provider recovery, and publication checks remain pending in the milestone verification records.

## Vector tray and release planning

Milestone 17 derives a transparent colored SVG and a monochrome menu bar template from the current icon, preserving the original Dock artwork. The native 18-point tray retains activity indicators and accessible state labels. The asset evaluation passes source fidelity, background removal, true-vector structure and deterministic regeneration; three hosted icon tests pass, with native light/dark 1×/2× previews inspected. Formatting, lint, warning-free Debug build, plist/signature and local-link checks pass.

The public-release checklist and App Store evaluation define owners, observable evidence and separate channel gates. Both channels are NOT READY: candidate QA/distribution work and store-specific implementation remain open. See [milestone 17](milestones/17-vector-tray-and-release/VERIFY.md) for evidence and scope. Changes are committed locally in semantic groups; nothing has been published.
