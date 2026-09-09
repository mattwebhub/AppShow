# App Store Connect setup and listing draft

Prepared 2026-09-09. Local draft only; account access is pending. The user requires design review before submission. Do not submit assets, metadata or a build until that review and explicit approval are recorded.

## Account setup status

App Store Connect was opened in the available browser. The page reached `/login`; its embedded sign-in form did not render. Site-scoped Apple session imports from both Chrome and Safari found no saved login. App Store Connect was opened in the system browser for the owner to authenticate directly. Membership, team, agreements, identifiers and existing app records have not been inspected. No account changes were made.

After authentication, inspect the selected team and existing records before creating anything. Reuse the intended AppShow identifier if already registered. The account owner handles identity verification, agreement acceptance and declarations that require personal or business facts.

## Proposed app record

| Field | Prepared value or decision |
| --- | --- |
| Platform | macOS |
| Name | AppShow; availability unverified |
| Bundle ID | `com.mattwebhub.appshow`; team registration unverified |
| Primary language | English (U.S.), proposed |
| SKU | `appshow-macos`, proposed; uniqueness unverified |
| Subtitle | Screen recorder & video editor |
| Primary category | Photo & Video, proposed |
| Secondary category | Productivity, proposed |
| Keywords | `capture,screencast,tutorial,demo,presentation,trim,zoom,cursor,background,export` |
| Pricing / availability | Owner decision pending |
| Support / privacy URLs | Owner destinations pending; no placeholder URLs for submission |
| Version / build | New release identity pending; current local build is 0.14.7 / 26 |
| Copyright / content rights | Rights holder and A8 evidence pending |
| Age rating / export compliance / trader status | Complete from verified product and owner facts |
| Release strategy | Owner decision pending; no automatic release selected |

## Promotional text draft

Turn screen recordings into clear, focused videos. Trim the pauses, shape the frame, guide attention with zoom, and export from one native Mac editor.

## Description draft

Screen recordings. Worth watching.

AppShow brings screen recording and video editing together on your Mac. Capture a screen, window or selected area, then refine the result in an editable project.

Keep the parts that matter. Trim a take, cut unwanted sections and speed up the stretches that do not need real time. Guide attention with zoom regions and give your video a consistent look with backgrounds, padding and rounded corners.

Choose your output format, resolution and frame rate, then export your video. Keep the project to return to your edits later.

Built for macOS 15 and later.

## Review notes to complete on the candidate

- Attach a cleared sample project and exact steps for opening, editing and exporting it.
- Explain screen-recording permissions and the visible recording indicator. Document retained camera/microphone/device features after hardware acceptance.
- Explain any retained downloaded models, hardware limitations and reviewer access. No assistant or transcription claims have been drafted while the Store feature decision and runtime checks remain open.
- Confirm Store update delivery and local shortcut behavior against the final build.
- Replace this draft's remaining decisions with verified values; match the final listing and images to the actual candidate.

## Design review

The [design package](../../docs/app-store/README.md) contains five editable screenshot layouts and a 24-second preview storyboard. The owner supplied two real Desktop screenshots for the hero and pace designs, including the assistant conversation. Both are labeled as direct-edition design review; three slots remain empty. Automated capture is still blocked by this session's macOS Screen Recording access. This draft set must not be uploaded.

- [ ] Owner reviews layout and copy.
- [ ] Engineering captures actual Store UI and completes asset evaluation.
- [ ] Owner reviews final images/video and approves submission.
- [ ] A1–A12 pass with candidate evidence before App Review submission.
