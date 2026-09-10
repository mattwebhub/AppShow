# September 10 distribution signing findings

Status: distribution export succeeded; no binary has been uploaded. The owner asked to set aside the vendor re-signing interpretation and continue submission preparation. It is not an owner-approval gate. The current privacy-link change needs a replacement archive before submission.

## Observed package behavior

The frozen universal archive passes all 16 local artifact checks. Xcode exports `distribution-export/AppShow.pkg` with Cloud Managed Apple Distribution signatures for the app and seven embedded executables, plus the team's Mac installer signature. The installer signature and extracted app's strict signature integrity verify.

The extracted payload passes 15 of 16 existing checks. `bundledAgentRuntimes` fails because the receipt contains pre-export full-file hashes and the evaluator requires the original Claude file hash. Distribution export changes all six provider/helper runtime files across Intel and Apple Silicon. Every compared Mach-O section retains identical contents; that comparison does not establish whole-file identity or permission to replace the signature.

The embedded receipt's `claudeSignature: vendor-original` and the staged notice saying the vendor signature is preserved are no longer accurate for the exported package. Do not rewrite a sealed package's receipts, suppress this failure, or treat code-section identity as a licensing decision. A distribution-aware integrity check must separately validate original provenance, exported code and the expected signature transformation once the permitted packaging approach is settled.

Evidence is in ignored `dist/app-store-submission/2026-09-10-owner-approved/`: `distribution-payload-audit.json`, `distribution-signing-comparison.json`, `distribution-export/DistributionSummary.plist`, and `distribution-export/package-signature.txt`.

## Provider documentation and owner direction

Anthropic's current guidance states: “The Claude Code binary must not be modified.” Preinstalling it in another product requires the Commercial Terms unless separately agreed, preserves its authentication methods, and leaves authentication and billing with each end user. [Anthropic's integration conditions](https://code.claude.com/docs/en/legal-and-compliance), checked September 10, 2026.

The owner explicitly asked to set this interpretation aside and proceed with the other declarations. No vendor rejection or definitive prohibition of Apple's signing transformation was established, and no vendor inquiry was sent. Both Claude Code and Codex remain required product features. Record the actual signing stages accurately in packaging receipts and notices; the remaining distribution integrity work is technical rather than a request for the owner to approve this interpretation again.

## Runtime evidence and limits

The development-signed app inside the exact universal archive opens the generated review project. Both authenticated providers complete real MCP text edits. Codex changes only the requested text in the saved document and Undo restores byte-equivalent decoded project data. Claude Undo restores every supplied original value; the first save also materializes the existing default caption settings, which were omitted from the generated source fixture.

Codex Stop and Retry recover successfully. After quitting, no archived AppShow/helper process remains. The exact archive cold-launches, reopens the project, preserves conversation history and completes a resumed Claude request. The sample exports as H.264, 1280 × 800, 30 fps, 210 frames, exactly seven seconds. A representative frame was visually inspected. These are development-archive results on this Apple Silicon Mac, not TestFlight results or a complete hardware/permission matrix.

The production-signed extracted payload cannot launch directly on this development Mac: taskgated reports no eligible provisioning profile and amfid rejects restricted entitlements. No protection was bypassed and the distribution payload was not re-signed for local testing. Installation and runtime acceptance through the intended distribution channel remain required.

## Review attachment

`AppShow-review-sample.zip` contains only a clean generated project (`project.json` and `screen.mp4`), the expected export and a README. Archive integrity and the four-entry allowlist pass. Provider conversation, session data and credentials are excluded. The working QA project remains separate from this attachment. No new screen recording was made.
