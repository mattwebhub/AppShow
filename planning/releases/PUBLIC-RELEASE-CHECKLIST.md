# AppShow public-release checklist

Evaluated: 2026-09-09. Release owner: Matheus. Engineering and QA owners are roles to assign before freezing a candidate.

**Direct download: NOT READY. Mac App Store: NOT READY.** The repository is public; this checklist governs publishing installable binaries. A green development build does not approve either distribution channel. The [App Store evaluation](APP-STORE-EVAL.md) is a required part of this checklist when targeting the store. Implementation commands and candidate handling are documented in the [release workflow](RELEASE-WORKFLOW.md).

## Evaluation rules and candidate record

Use **Pass**, **Fail**, **Not tested**, or **Not applicable (decision linked)** for every gate. A release requires all applicable gates to pass against the same commit and artifact; scores are never averaged. Every checked item needs evidence, an owner, date, and candidate SHA. Re-run affected gates after changes. Historical milestone evidence is a starting point, not a substitute for candidate testing.

| Candidate field | Current value |
| --- | --- |
| Channel | Direct download planned; App Store needs a dedicated implementation and evaluation |
| Commit/tag | Not frozen; development branch `webcam-presentation-and-review` |
| Marketing version/build | Current source: `0.14.7` / `26`; release version not selected |
| Artifact/SHA-256 | No candidate artifact nominated |
| Signing/notarization or store upload | Not evaluated for a current release candidate |
| Source archive, dependency versions, license notices | Must match the frozen artifact |
| Release decision | Hold until the selected channel's gates pass |

## Shared product and repository gates

- [ ] **G1 — Engineering:** freeze the candidate, resolve open changes into reviewed semantic commits, and obtain green CI on that SHA. Evidence: commit, PR/CI URLs, clean checkout and dependency lockfile. Current local baseline: 770 tests and 11 gated export tests passed before the tray change; see [state](../STATE.md).
- [ ] **G2 — Engineering:** run the commands below on the candidate and retain logs. Evidence: warning-free build, strict lint, unit suite, shim, deterministic scenario and encoded exports; failures are fixed or the affected feature is removed from the release.
- [ ] **G3 — QA:** capture display/window/area/device with the supported camera/system-audio/microphone combinations. Test permission denial, later grant and revocation, countdown, pause/resume, cancel, repeated recording, long recording, sleep/wake, display changes and disk-full failure. Evidence: OS/hardware matrix and test recordings; no lost source media.
- [ ] **G4 — QA:** test real project create/save/reopen/rename/move, `.frm` migration, cuts, trim, overlays, blur, cursor/area zoom, camera layouts, captions/fonts, music, Undo/Redo, and speed presets. Compare native preview with SDR/HDR and normal/parallel exports, including normal-speed webcam/microphone/music and SRT/VTT timing. Evidence: checked manual rows in milestones [10](../milestones/10-webcam-presentation/VERIFY.md), [11](../milestones/11-webcam-voice/VERIFY.md), [12](../milestones/12-caption-style/VERIFY.md), [15](../milestones/15-area-effects-and-recovery/VERIFY.md), [16](../milestones/16-speed-regions/VERIFY.md), plus remaining earlier milestones.
- [ ] **G5 — QA:** test optional assistant setup with both supported providers, unavailable/expired credentials, no provider installed, read-only mode, editing, grouped Undo, export confirmation, cancel, interrupted reply, retry and fresh session. Evidence: disposable-project runs and provider versions. Run live-provider tests only against dedicated test projects/accounts; normal recording/editing must work offline without an assistant.
- [ ] **G6 — QA:** test the declared minimum and current supported macOS on Apple silicon and Intel, or narrow supported hardware explicitly. Verify the stated Apple-silicon transcription limitation, model download/cancel/retry, missing fonts, audio drift and export performance. Evidence: hardware/OS matrix, download size and elapsed-time notes.
- [ ] **G7 — QA/design:** inspect the new menu icon in the actual menu bar, highlighted/open state, light/dark appearances and Retina/non-Retina; inspect recording/paused/pulse feedback, VoiceOver labels, keyboard navigation, Dock/Finder icon and editor controls. Evidence: screenshots and interaction notes. Native tray renders and automated alpha tests are supporting evidence; they do not replace interaction testing.
- [ ] **G8 — Owner/engineering:** complete the privacy and dependency inventory. Cover captured media, transcripts, assistant prompts/tool frames sent to providers, local logs, retention/deletion, downloaded models and network endpoints. Publish accurate privacy/support pages, verify permission purpose strings, and remove secrets or personal content from examples and release materials. Evidence: reviewed policy and data-flow inventory.
- [ ] **G9 — Owner:** ship upstream credits and exact dependency license notices plus corresponding source/build instructions for the binary, including vendored gifski. The fully open-source decision in [ADR 0008](../decisions/0008-gifski-licence.md) remains in force. Evidence: release source archive and packaged notices; store-specific rights are evaluated separately in A8 below.

```sh
make format
make lint
make build
make test
make test-shim
make test-scenario
TEST_RUNNER_APPSHOW_RUN_EXPORT_TESTS=1 make test T=ExportPipelineTests
make eval-tray
git diff --check
```

Record the optional live-provider run separately: `make test-agent-skills CLAUDE_MODEL=<available-model>`. Re-run all relevant acceptance checks after final signing/packaging if the artifact changes behavior or resources.

## Direct-download gates

- [ ] **D1 — Engineering:** choose the AppShow release version and unique build number. The source fix now resolves `CFBundleVersion` from `CURRENT_PROJECT_VERSION`; appcast generation reads and validates the actual Release bundle version, build and minimum OS. Regression tests pass. Selecting the final unused public version and increasing its build number before distribution remain open. Evidence: packaged Info.plist and appcast agree, with monotonically increasing versions. [Sparkle version contract](https://sparkle-project.org/documentation/publishing/)
- [ ] **D2 — Engineering:** make a clean Release build and verify `arm64 x86_64` if both are advertised. Inspect every embedded framework/helper and dependencies. Evidence: `make release`, `lipo -archs`, release logs, bundle contents and deployment targets. The milestone 18 universal build succeeds for both architectures, but emits 11 missing module-cache warnings; investigate these and complete nested-bundle inspection before closing this gate. An old DMG in `dist/` is not the candidate.
- [ ] **D3 — Release owner:** sign all nested code and the final bundle with Developer ID Application, verify hardened runtime and distribution entitlements, then package, notarize and staple. Development/ad-hoc signatures cannot satisfy this gate. Evidence: strict signature verification, accepted notarization submission, stapler validation and Gatekeeper assessment of the exact DMG and installed app. The current packaging script uses broad `codesign --deep` signing; verify or replace this with correct inside-out signing for the embedded helpers before relying on it. [Apple notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution), [packaging](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution)
- [ ] **D4 — Release owner/QA:** decide whether updates ship enabled. For Sparkle, configure the app's public EdDSA key, protect the signing key, validate the signed enclosure and HTTPS feed, and test an actual older-install-to-candidate update. `SUPublicEDKey` is currently absent, so the updater stays inactive. The candidate workflow now derives manual/Sparkle delivery from the built app: manual releases need no feed or updater credential, and Sparkle feeds are cryptographically verified against the app public key. The current manual-download behavior is preserved provisionally; the first-release preference and end-user update acceptance remain open. Evidence: successful update/tampered-download rejection or an explicit no-updater release decision. [Sparkle publishing](https://sparkle-project.org/documentation/publishing/)
- [ ] **D5 — QA:** download the candidate through a browser to a clean Gatekeeper-enabled Mac; install, launch with quarantine intact, grant permissions, record/edit/export, quit/relaunch and reopen a project. Test without a network connection after installation. Evidence: install/uninstall and offline-launch results, including no developer-machine dependencies. [Apple distribution testing](https://help.apple.com/xcode/mac/current/en.lproj/dev033e997ca.html)
- [ ] **D6 — Owner/design:** replace the attributed upstream editor screenshot with a current AppShow sample, review the README/download instructions, versioned changelog, supported platforms, known issues, source/license links, screenshots and social preview. Evidence: draft release and checked links, using presentation-safe media.

Local artifact checks after a candidate exists (replace the path with that exact candidate):

```sh
lipo -archs .build/Build/Products/Release/AppShow.app/Contents/MacOS/AppShow
codesign --verify --deep --strict .build/Build/Products/Release/AppShow.app
codesign -d --entitlements :- .build/Build/Products/Release/AppShow.app
spctl --assess --type execute --verbose .build/Build/Products/Release/AppShow.app
xcrun stapler validate dist/AppShow-X.Y.Z.dmg
spctl --assess --type open --context context:primary-signature --verbose dist/AppShow-X.Y.Z.dmg
shasum -a 256 dist/AppShow-X.Y.Z.dmg
```

## Mac App Store gates

Complete the [App Store readiness evaluation](APP-STORE-EVAL.md), attach its evidence and record its verdict before submission. The existing unsandboxed direct-download app is not a store candidate.

- [ ] **A1 — Engineering:** dedicated sandboxed store configuration and validated capture/export runtime.
- [ ] **A2 — Owner/engineering:** store-compatible optional assistant design and tested provider behavior.
- [ ] **A3 — Engineering/QA:** container storage, scoped bookmarks, project reopening and migrations.
- [ ] **A4 — Engineering/QA:** compatible window control and global shortcuts.
- [ ] **A5 — Engineering:** Sparkle and its updater helpers excluded from the store artifact.
- [ ] **A6 — Owner/engineering:** privacy manifests, API/dependency audit, disclosures and public policy.
- [ ] **A7 — Engineering/QA:** transparent model downloads and offline/failure behavior.
- [ ] **A8 — Owner:** documented store distribution rights for the exact app and dependencies.
- [ ] **A9 — Release owner:** versioning, distribution signing, archive validation and successful upload.
- [ ] **A10 — Owner/design:** complete App Store Connect record, metadata, screenshots, age rating, pricing/availability and applicable agreements/disclosures.
- [ ] **A11 — QA/owner:** TestFlight acceptance, review instructions and reviewer access to all advertised features.
- [ ] **A12 — Owner:** Apple review approval and an explicit store-release decision.

## Publication and follow-through

- [ ] **P1 — Release owner:** verify all shared and selected-channel gates, record the final SHA/version/checksum/evidence and approve the concrete release candidate. The existence of this checklist is not release approval.
- [ ] **P2 — Release owner:** publish the reviewed source/tag/artifact and release notes; update the feed only after the download URL resolves. Check the downloadable checksum, signatures, README links and social preview from a logged-out session. `make prepare-release`, `make tag`, `make release-preview` and `make publish` are now separate. Preparation records the clean source commit and artifact hashes; publication requires that receipt and matching tag, with no rebuild or unrelated tag pushes. The actual publication and post-download checks remain open.
- [ ] **P3 — Owner/engineering:** retain the previous signed artifact and feed, define how to stop rollout or withdraw a bad release, and record a forward-fix process that preserves user projects. For the store, record the release/availability controls in App Store Connect. Evidence: a reviewed rollback runbook and named responder.
- [ ] **P4 — Owner/QA:** smoke-test the published download/store build, monitor installation failures, crashes and incoming issues for 24–48 hours, and triage with a documented support contact. Never overwrite a versioned binary silently; issue a new build.

Current disposition: asset work can complete independently; signing, real-device acceptance, update delivery and store implementation remain open release work. See the task's [evaluation](../milestones/17-vector-tray-and-release/EVAL.md) for what was completed during this session.
