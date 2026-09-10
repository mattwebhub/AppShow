# September 10 Store submission preparation

Status: **listing and four screenshots saved; release validation in progress**. The owner requested the updated assets in App Store Connect and preparation toward release. No new recording is authorized or made.

## Saved App Store record

[AppShow: AI Screen Recorder — <app id>](https://appstoreconnect.apple.com/apps/<app id>/distribution/macos/version/inflight) is registered under the owner's team **<team id>**, explicit bundle ID **com.mattwebhub.appshow**, SKU **appshow-macos**, English (U.S.). Membership renewal is March 25, 2027. The agent accepted no developer agreement. An initial agreement banner did not prevent app creation; distribution-time requirements still need checking.

The four current Figma screenshots are processed and appear in the numbered order after reload and in Media Manager. The description, promotional text, keywords, subtitle and Photo & Video / Productivity categories are saved. Version **0.14.7** matches the local build configuration; **manual release** is selected. Existing trader status is preserved. Pricing and availability have no starting configuration.

Support/privacy URLs and reviewer contact have been requested from the owner. Pricing, territories, copyright/content rights, age rating, encryption answers, privacy disclosures and reviewer provider access remain unresolved. No binary or App Review request is submitted.

## Artifact package

Ignored directory: `dist/app-store-submission/2026-09-10-owner-approved/`.

| Artifact | Evidence / use |
| --- | --- |
| `upload/01-record-tell-ai-show.png` | First screenshot; Figma `5:2` |
| `upload/02-cut-the-waiting.png` | Second screenshot; Figma `6:2` |
| `upload/03-make-it-yours.png` | Third screenshot; Figma `7:2` |
| `upload/04-ready-to-share.png` | Fourth screenshot; Figma `7:12` |
| `screenshot-manifest.json` | Pixel identity, dimensions, hashes, owner approval and App Store receipt |
| `AppShow-four-screenshots.zip` | Four numbered RGB PNGs and current manifest; archive integrity verified |
| `runtime-evidence/app-store-listing-saved.txt` | Saved fields and four ordered filenames after reload |
| `pre-fixes-archive-audit.json` / `pre-fixes-archive-receipt.json` | Historical development archive that reproduced the chat stall; superseded and removed |
| `archive-source-before.json` | Production/build input hashes for the replacement universal archive |
| `ExportOptions.plist` | Local App Store distribution export for team <team id>, preserving version/build |
| `review-sample/` | Generated eight-second test-pattern project and reviewer steps, without private media/accounts/conversation; native validation pending |

## Code and runtime validation

The prior exact universal development archive opened the external cropped project but reproduced a long-conversation SwiftUI stall. Logs confirm Codex started and connected to MCP while the UI remained in layout. Changing the transcript from LazyVStack to VStack allowed the identical request and a subsequent Codex MCP title edit to complete responsively in Debug Store. The isolated hosted smoke test does not reproduce the full-editor failure and is not used to close it.

Authenticated Claude initially failed creating `/tmp/claude-501`. Store runtime policy now creates private container temporary storage (0700) and overrides `TMPDIR` and Claude's documented `CLAUDE_CODE_TMPDIR`. A failing policy test preceded the fix. Retrying the native interrupted request completed the real Claude MCP title edit and final response.

Undo exposed a separate stale baseline: pending prior editor changes could be lost when undoing an agent edit. Individual calls and explicit batches now preserve their actual before-state without duplicating history already recorded by editing helpers. Both parameterized regression cases failed before the fix; all 32 editing tests pass afterward.

The latest full run passes **819 tests in 101 suites**, including the concurrently added panel tests. Three sandbox-hosted tests pass. Format/lint and normal direct/Store Debug builds are warning-free; the rebuilt Store artifact passes all 16 local checks. An earlier full run's six issues were five duplicate assertions from automatic NSHostingView window sizing and an MP3 fixture missing during a concurrent build. The layout fixture now fixes its sizing behavior; the subsequent full run passes. Build concurrency and source changes must still be excluded from final candidate evidence.

The initial replacement archive attempt ran out of disk while copying runtimes. Superseded generated Release products/intermediates and the Debug Store product were removed; source, media and screenshot exports were retained. The universal archive retry is in progress. These builds use Apple Development signing; distribution signing/export has not yet been validated.

## Remaining release sequence

1. Finish the replacement universal archive, compare production inputs, audit all bundled code and repeat live provider/Undo/relaunch checks on that exact app.
2. Validate the generated review sample and export, then package it with precise reviewer instructions. No new recording is needed for these checks.
3. Select a clean source checkpoint and final release identity, export with App Store distribution signing/provisioning and inspect the exported package. Do not upload the superseded pre-fix archive.
4. Complete the remaining owner facts, support/privacy destinations, rights, disclosures and reviewer access from verified information.
5. Complete TestFlight and required capture/hardware/file-access acceptance, then obtain a final review decision. See [A1–A12](APP-STORE-EVAL.md), [listing](APP-STORE-LISTING-DRAFT.md) and [chat acceptance](../milestones/21-sandboxed-agents/CHAT-ACCEPTANCE.md).
