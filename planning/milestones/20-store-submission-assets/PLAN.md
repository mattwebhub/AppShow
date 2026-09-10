# Milestone 20: Store submission assets and account setup

2026-09-10: The owner approved the edited four-frame Figma set for listing upload and asked to prepare the release. Chat, MCP and both provider integrations remain required. [Milestone 21](../21-sandboxed-agents/PLAN.md) tracks runtime acceptance; design approval does not close those checks.

- [x] Check current Apple image/video specifications and inspect the suggested Desktop footage.
- [x] Attempt account access and record the authentication boundary without storing credentials.
- [x] Prepare editable screenshot copy/layouts, a local review gallery, icon reference and listing draft.
- [x] Prepare an independent presentation project from the suggested export.
- [x] Export and visually inspect all four owner-approved Figma frames with distinct feature views.
- [ ] Verify advertised UI behavior against the exact final Store candidate; current capture provenance includes the Direct edition.
- [x] Inspect the authenticated team, agreements, identifiers and existing app records; prepare the app record where authorized and facts are available.
- [x] Complete native image checks and record the owner's approval to upload the edited set.
- [x] Upload the four images and verify processing and saved order in App Store Connect.
- [ ] Record final evidence and update the App Store evaluation without treating design preparation as submission readiness.

## Evaluation

Local asset preparation passes when the four approved layouts export at the documented Mac dimensions with verified order, image identity and provenance. Final release acceptance additionally requires candidate behavior, rights and review access checks. Account setup requires observed authenticated state, not inferred access from local signing certificates.

## Earlier owner handoff

The owner will record videos and make further Figma changes. No new recordings or App Store submission are requested. The design handoff is complete: five distinct native views, editable Rubik text and explicit Claude Code + Codex labeling, five visually reviewed 2880 × 1800 PNG exports, a local review gallery and a ZIP containing the native stills.

General MCP calls still hit the plan allowance, but native Figma controls and image uploads completed the work. Native inspection found the owner’s current hero/agent image nodes (`17:3` and `17:5`) and preserved the updated hero headline. Four feature stills now use the cropped project in the Direct build; the real earlier Store conversation remains on the agent slide. Every final frame was refreshed, visually checked and exported in the native client. Assets and exact provenance are under `dist/app-store-submission/2026-09-09-rubik/`; open `final-exports/index.html` for review.

Final Store candidate capture and owner acceptance remain separate from this completed design handoff. The Store build failed to open the external working project through Finder during this pass; Direct opening succeeded. The longer-conversation layout stall and authenticated Claude acceptance are still tracked in milestone 21.

## Approved upload pack and archive

The owner deleted the first original frame and moved the hero copy into the agent frame. September 10 native exports preserve all four remaining frames without Figma content changes. The current `dist/app-store-submission/2026-09-10-owner-approved/upload/` pack contains four 2880 × 1800 RGB PNGs without alpha. Decoded pixel hashes match the owner exports exactly. The adjacent manifest records all hashes, order and approval.

App Store Connect record **<app id>**, **AppShow: AI Screen Recorder**, is created under the verified owner team **<team id>**. The explicit App ID is registered. All four images are processed in the correct order, and the description, promotional text, keywords, subtitle and categories are saved. The draft uses version 0.14.7 with manual release. Support/privacy URLs, review contact, pricing/availability and remaining declarations are pending.

The first universal archive passed all 16 checks but reproduced a conversation stall. Debug Store fixes now allow both providers to complete real MCP edits and preserve the actual pre-edit Undo baseline. That pre-fix archive was removed after retaining its evidence; its replacement is being validated. No new recording, binary upload or App Review submission occurred. See the [submission packet](../../releases/SUBMISSION-PREPARATION.md).
