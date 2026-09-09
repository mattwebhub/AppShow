# Milestone 19 verification

Date: 2026-09-09. Toolchain: Xcode 26.6, build 17F113.

## Result

The local App Store foundation evaluation passes. A separate sandboxed app builds, executes synthetic project/export tests and produces a universal local archive. **App Store submission remains NOT READY.** The archive uses Apple Development signing, not App Store distribution signing.

| Evaluation | Evidence | Result |
| --- | --- | --- |
| Store target boundaries | Regression first failed because `AppShowStore` did not exist. The target now has sandbox/bookmark entitlements, separate module/product identity, shared sources, independent resources/frameworks and no Sparkle/MCP dependency. | Pass |
| Container paths | Regression reproduced legacy migration/shared-temp behavior under the requested sandbox policy. Store defaults now use container Application Support and sandbox temp; direct locations and legacy compatibility tests still pass. | Pass |
| Persistent scope lifecycle | Three injected tests cover persistence, moved/stale URLs, balanced scope lifetime, revoked grants and failed persistence retaining the previous selection. | Pass |
| Permissions | Regression reproduced unnecessary Accessibility checks/requests and a blocked capture permission state. Five permission tests pass with an explicit store policy that skips Accessibility. | Pass |
| Bundle metadata | Hosted regression reproduced absent executable/application-type keys. Both variants now declare these and the independent configured build. | Pass |
| Direct-edition regression suite | `make test`: 789 tests in 95 suites pass on the final application implementation. | Pass |
| Encoded export regressions | All 11 gated `ExportPipelineTests` pass, including normal/parallel export, speed presets, independent narration/music/webcam timing and SDR/HDR. | Pass |
| Sandbox-hosted smoke suite | `make test-store`: 3 tests pass. The host's signing information confirms App Sandbox; test storage is isolated under sandbox temp. Native Foundation bookmark data persists/restores with actual file I/O. A synthetic project is created/reopened and a trimmed speed edit exports with the expected duration and readable frames in normal and parallel modes. | Pass |
| Style and Debug builds | `make format`, `make lint`, warning-free direct/store Debug builds, plist/project syntax, evaluator Python syntax and whitespace checks pass. | Pass |
| Universal local archive | `make store-archive` succeeds without warnings; the archive contains both `x86_64 arm64`. Version/build are `0.14.7` / `26`, minimum macOS 15.0. | Pass |
| Artifact audit | All 15 evaluator checks pass on the local archive, including all Mach-O linkage, no updater/helper payload, no temporary sandbox or runtime exceptions, no debugging entitlement, declared privacy API reasons and strict signature integrity. | Pass |
| Privacy/dependency evidence | Store archive includes the first-party API-reason manifest and `swift-crypto_Crypto.bundle` privacy resource. Source rationale and resolved dependency revisions/license evidence are recorded; full SDK/service disclosures and distribution rights remain open. | Partial |

## Artifact and logs

- Local archive: `.build/AppShowStore.xcarchive`.
- App: `.build/AppShowStore.xcarchive/Products/Applications/AppShowStore.app`.
- Archive executable SHA-256: `3e0b1dba1da8e34ecb4c67bd6c62a08ea79501dfb8673d6d682acbe12f73dafd`. This identifies the executable, not a submitted package or the entire archive.
- Local build/audit logs: `/tmp/appshow-store-direct-final-build.log`, `/tmp/appshow-store-build-final.log`, `/tmp/appshow-store-archive.log`, `/tmp/appshow-store-archive-eval.json`.
- Test logs: `/tmp/appshow-store-final-tests.log`, `/tmp/appshow-store-direct-exports.log`, `/tmp/appshow-store-smoke-final.log`. The store `.xcresult` records normal and parallel argument cases separately as passed.
- Red regressions: `/tmp/appshow-store-target-red.log`, `/tmp/appshow-store-paths-red.log`, `/tmp/appshow-bookmark-red.log`, `/tmp/appshow-store-permissions-red.log`, `/tmp/appshow-store-bundle-red.log`.

Tests used generated media, temporary storage and injected permission/external-tool boundaries. They did not record the desktop, use camera/microphone hardware, request permissions, download models or use provider accounts. The running direct-download app was not restarted. No App Store Connect record, upload, TestFlight run, review submission, Git tag, push or publication was performed.

## Remaining acceptance

- Confirm the shipping store assistant/shortcut feature set; the validation edition disables external assistants and keeps shortcuts local.
- Test each real capture/audio/device mode, denial/grant/revocation and interactive controls on the supported hardware/OS matrix.
- Exercise user-selected external folders across cold process relaunch, moved/deleted/offline locations, folder changes during asynchronous export, imported projects and rename/Save As. Native container bookmark tests do not replace those checks.
- Test real model/tokenizer downloads, consent, cancellation, retry, offline behavior and hardware restrictions.
- Complete SDK/service privacy review and the archive privacy report; provide accurate public privacy/support pages and App Store Connect disclosures.
- Resolve exact binary/model/asset distribution rights, including AGPL gifski and RNNoise provenance/notices. No blanket store licensing conclusion was made.
- Select release version/build, configure App Store distribution signing/provisioning, validate/upload the distribution archive, complete the app record, run TestFlight and obtain App Review approval.

See [implementation](../../releases/STORE-IMPLEMENTATION.md), [privacy audit](../../releases/PRIVACY-AUDIT.md), [dependency evidence](../../releases/STORE-DEPENDENCIES.md), and [A1–A12](../../releases/APP-STORE-EVAL.md).
