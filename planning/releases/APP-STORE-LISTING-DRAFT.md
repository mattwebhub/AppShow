# App Store Connect setup and listing draft

Updated 2026-09-10. The owner approved the four revised Figma screenshots for upload and requested release preparation. The screenshots and listing copy are now saved in App Store Connect. No binary or App Review submission has been sent.

## Account and listing status

The owner signed in through Safari. The verified individual developer team is the owner's (`<team id>`), with membership renewal shown as March 25, 2027. The explicit App ID `com.mattwebhub.appshow` was registered without optional capabilities. App Store Connect created app **<app id>**, **AppShow: AI Screen Recorder**, after Apple rejected “App Show” as unavailable. No developer agreement was accepted by the agent. An earlier agreement banner did not prevent identifier or app-record creation; verify any remaining agreement requirement at distribution time.

[Open the saved listing](https://appstoreconnect.apple.com/apps/<app id>/distribution/macos/version/inflight).

| Field | Saved value or remaining decision |
| --- | --- |
| Platform / primary language | macOS / English (U.S.) |
| Name | AppShow: AI Screen Recorder |
| Bundle ID / SKU | `com.mattwebhub.appshow` / `appshow-macos` |
| Apple ID / team | `<app id>` / `<team id>` |
| Subtitle | Screen recorder & AI editor |
| Primary / secondary category | Photo & Video / Productivity |
| Keywords | `screen,recording,video,editor,AI,demo,tutorial,screencast,trim,zoom,captions,Claude,Codex` |
| Screenshots | Four processed PNGs; filenames and order verified after reload and in Media Manager |
| Pricing / availability | Owner decision pending |
| Support / privacy URLs | Owner destinations requested; no placeholders entered |
| Version / build | Listing 0.14.7 matches local configuration; build 26 is not uploaded |
| Copyright / content rights | Rights holder and A8 evidence pending |
| Age rating / export compliance | Declarations pending |
| Trader status | Existing Apple UI says this developer identified itself as a trader for this app; preserved |
| Release strategy | Manually release this version |

## Promotional text draft

Record your screen. Tell your AI what to refine. Shape the pace, style your canvas, and share a polished video—all in one native Mac app.

## Description draft

Record. Tell AI. Show.

AppShow brings screen recording, video editing and an AI assistant together on your Mac. Capture a screen, window or selected area, then refine the result in an editable project.

Edit with Claude Code or Codex. Describe a change in the built-in conversation and let the assistant work through AppShow's editing tools. Review the result, undo edits and keep the conversation with your project. AI features require an account with the selected provider and an internet connection. AppShow asks before sharing project information with that provider.

Keep the parts that matter. Trim a take, cut unwanted sections and speed up the stretches that do not need real time. Guide attention with zoom and text overlays. Make the canvas yours with backgrounds, padding and rounded corners.

Choose your output format, resolution and frame rate, then export your video. Keep the project to return to your edits later.

Built for macOS 15 and later.

## Review notes to complete on the candidate

- Attach a cleared sample project and exact steps for opening, editing and exporting it.
- Explain screen-recording permissions and the visible recording indicator. Document retained camera/microphone/device features after hardware acceptance.
- The copy describes the intended Store product; Debug Store now completes authenticated Claude and Codex MCP edits. Final universal-candidate recovery and hardware acceptance remain open. Complete the exact-candidate steps in the [submission preparation packet](SUBMISSION-PREPARATION.md) before review. Verify provider sign-in, sharing consent, one reversible MCP edit, Undo, resumption, cancellation and export confirmation with both providers.
- Explain retained model downloads, hardware limitations and reviewer access. Keep reviewer credentials outside the repository and use Apple's private review fields when required.
- Confirm Store update delivery and local shortcut behavior against the final build.
- Replace this draft's remaining decisions with verified values; match the final listing and images to the actual candidate.

## Design review

The owner-approved [design package](../../docs/app-store/README.md) has four distinct Rubik Figma frames: Record. Tell AI. Show.; Cut the waiting.; Make it yours.; Ready to share. The owner deleted the original first frame. Upload the numbered RGB PNGs from `dist/app-store-submission/2026-09-10-owner-approved/upload/` in that order.

- [x] Owner completes the current Figma edits and requests screenshot upload.
- [x] Export and visually inspect all four frames; verify dimensions, distinct files and lossless RGB upload copies.
- [x] Verify processed screenshots and saved order in App Store Connect.
- [ ] Match all advertised behavior to the final distribution candidate.
- [ ] A1–A12 pass with candidate evidence before App Review submission.
