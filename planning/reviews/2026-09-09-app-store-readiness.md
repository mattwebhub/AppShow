# Mac App Store readiness assessment

Date: 2026-09-09. Scope: source inspection, the signed currently running Debug bundle, and current Apple documentation. No build settings, entitlements, permissions, or application behavior were changed. No App Store Connect upload or sandbox runtime trial was performed.

## Current status: App Sandbox is disabled

`AppShow/AppShow.entitlements:5` explicitly sets `com.apple.security.app-sandbox` to false. Both Debug and Release reference this file in `AppShow.xcodeproj/project.pbxproj`. The signed `.build/Build/Products/Debug/AppShow.app` also contains that false value. The running executable was this bundle, PID 6525 when inspected.

The bundle is signed with Apple Development and has the Hardened Runtime flag. Its signed entitlements also include camera, audio-input, allow-jit and get-task-allow. Hardened Runtime and App Sandbox are separate controls. The Debug signature is not evidence of an App Store distribution archive. No release archive was generated for this review.

Apple requires sandboxing for Mac App Store distribution. [Apple: App Sandbox](https://developer.apple.com/documentation/security/app-sandbox)

The repository's AGENTS.md says sandboxing is disabled because ScreenCaptureKit requires it. That explanation is incorrect as a general claim: Apple's own ScreenCaptureKit sample enables App Sandbox. I downloaded the official sample ZIP into memory and inspected `CaptureSample/CaptureSample.entitlements`, which sets app-sandbox=true and user-selected.read-only=true. ScreenCaptureKit itself is therefore not the architectural blocker. AppShow's complete capture/export flows still need a sandbox trial. [Apple sample](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-in-macos), [sample archive](https://docs-assets.developer.apple.com/published/9db8b3fae777/CapturingScreenContentInMacOS.zip)

## Engineering work, in priority order

| Area | Evidence in AppShow | Work needed |
| --- | --- | --- |
| Store configuration | Shared unsandboxed entitlements; no dedicated store configuration identified | Add an App Store configuration/entitlements file, preserve the direct build, enable sandboxing, validate all bundled executable signatures. Camera/audio-input already exist; add scoped file access and outgoing networking where needed. Review the JIT exception and ensure the submitted archive has no debugging entitlement. |
| Local assistant | `AgentToolchain.swift` discovers shell/Homebrew/user-installed tools; `AgentProcessRunner.swift` launches them through Process; providers use external login state | The existing CLI integration is a major sandbox and review risk. A store edition should initially omit it or use an in-process/provider API integration with explicitly scoped editor tools. Shipping an unsandboxed helper is not a sound assumption for solving this. Bundled sandboxed helper/XPC designs require their own feasibility checks. |
| Window control and global keys | `WindowController.swift` reads/writes other apps' AX window attributes; `SessionState+UI.swift` raises windows; `KeyboardShortcutManager.swift` installs an active keyboard event tap | Remove/replace cross-app AX window manipulation in the store edition. Prototype registered global shortcuts instead of assuming the active keyboard interception will work. Keep local controls and standard screen/window selection. |
| Storage and reopening | `AppShowPaths.swift` uses `/tmp/AppShow` and home-relative state; `FileManager+AppShow.swift` expands saved folder strings; defaults include `~/Movies/AppShow`; no security-scoped bookmark lifecycle found | Use container Application Support/Caches/temp directories. Obtain user-selected project/export folders, persist access with security-scoped bookmarks, and hold scoped access across async work. Plan consent-based import of existing settings/projects. A selected project bundle does not automatically grant access to its sibling `.agent` directory; move agent scratch data into the container or explicitly select its parent. |
| Updates | Sparkle is linked and embedded, with `SUFeedURL` and settings integration | Exclude Sparkle and its updater helpers from the store build. Current Debug updater is inactive because SUPublicEDKey is absent; that runtime guard should not be the store distribution design. |
| Privacy | Camera/mic/screen purpose strings exist; no first-party PrivacyInfo.xcprivacy found; the built bundle contains a swift-crypto dependency manifest | Audit required-reason APIs and every dependency, add accurate app declarations, publish a privacy policy and support page, and complete App Store Connect privacy disclosures. Explicitly account for data sent to AI providers and downloaded transcription models. The dependency manifest does not cover the app's own API use. |
| GIF licensing | Root LICENSE is MIT, but the linked `AppShow/Libraries/gifski/LICENSE` is AGPL v3 | Confirm the distribution rights for the exact linked binary and its dependencies. Obtain an appropriate alternative license, satisfy a confirmed compatible licensing arrangement, replace the encoder, or omit GIF export. No definitive legal incompatibility conclusion is made here. |
| Release metadata | `Info.plist:14` uses MARKETING_VERSION for CFBundleVersion, producing 0.14.7 despite CURRENT_PROJECT_VERSION=26 | Use CURRENT_PROJECT_VERSION for the build identifier; establish monotonically increasing uploads. Create the app record, archive with App Store distribution signing/provisioning, validate, then test through TestFlight. Prepare screenshots, description, age rating, support/privacy URLs, export-compliance answers, review instructions, and any necessary reviewer access. |

Process children inherit the app sandbox, so spawning a locally installed tool does not escape it. This supports the assistant-risk assessment above; exact provider compatibility has not been tested under sandboxing. [Apple: Process](https://developer.apple.com/documentation/foundation/process)

Apple identifies cross-app accessibility operations among sandbox restrictions and recommends container-aware standard directories. The window-control and storage recommendations follow from that documented boundary and the local call sites. [Apple: Protecting user data with App Sandbox](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox)

Mac App Store rules also require self-contained installation and App Store-delivered updates, and restrict downloaded code that changes functionality. Those requirements drive the store-specific updater removal and assistant redesign assessment. [App Review Guidelines, 2.4.5](https://developer.apple.com/app-store/review/guidelines/#hardware-compatibility)

Apple documents scoped file/bookmark entitlements separately from camera/audio capabilities. Grants should be selected for actual flows, rather than adding broad exceptions in advance. [Apple entitlement reference](https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/EnablingAppSandbox.html)

Required-reason API declarations must reflect actual usage. [Apple: Required reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api), [privacy disclosure setup](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)

Gifski's author explicitly offers alternative commercial licensing alongside AGPL. No such license was established by this repository review. [Gifski licensing](https://github.com/ImageOptim/gifski#license)

Release submission requires an Apple Developer Program team and the App Store Connect distribution workflow. The installed Xcode is 26.6; toolchain age is not an obvious obstacle, but final archive validation is still necessary. Account membership, agreements, app-name availability, certificates, and store records were not checked. [Apple distribution guide](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases), [upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)

## Recommended sequence

1. Resolve GIF licensing and decide whether the first store edition includes a redesigned assistant.
2. Create an isolated App Store configuration and prove native screen/window capture, webcam, microphone, system audio, editing and export in the sandbox. Include permission denial/recovery, device capture if retained, and reopening user-selected projects after relaunch.
3. Complete container storage/bookmarks, remove store-incompatible features and updater packaging, and verify model downloads and caches.
4. Finish privacy/release metadata and signing; archive validation and TestFlight should precede submission.

A dedicated store edition is a practical option alongside the existing direct-download edition. Preserving every current feature unchanged is not a one-checkbox change. This is an engineering assessment, not an App Review approval or a complete dependency-license audit.
