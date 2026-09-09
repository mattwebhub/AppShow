# Store privacy implementation audit

Date: 2026-09-09. Scope: first-party source and the local store validation target. This is engineering evidence, not a completed privacy policy or App Store Connect disclosure.

## First-party API declarations

The store resource `AppShow/PrivacyInfo.xcprivacy` declares the following observed uses. It is included only in the store target; the direct edition's broader external-assistant behavior needs its own review.

| API category | Source use | Declared reason |
| --- | --- | --- |
| File timestamps/metadata | `RotatingFileLogHandler` reads local log size; `MediaFileInfo` reads media size; recent-project enumeration requests modification metadata and computes bundle size. | `C617.1` for container files; `3B52.1` for user-authorized projects/media. |
| System boot time | `AudioWaveformGenerator` throttles progress; `ExternalAudioPreviewEngine` measures intervals between drift checks. | `35F9.1` for elapsed-time/timer calculations within the app. |

Reason selections were checked against [Apple's current API category/reason definitions](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype). They are an inference from the cited source uses, and must be revisited when behavior changes. No first-party UserDefaults, disk-capacity or active-keyboard reason was added without corresponding source evidence. This does not establish that transitive SDKs use none of those APIs.

The manifest deliberately supplies API reasons only. It does not assert completed tracking/data-collection disclosures on behalf of all dependencies and services.

## Data flow and remaining owner work

- Screen, camera, microphone and system audio become local project media. Imports are copied into project bundles; exports are local files. Projects can include captions and, when originating from the direct edition, saved assistant conversations. A public policy must explain storage, user-controlled sharing/deletion, and what deleting the app does to documents outside the container.
- Logs include operational details and paths and remain local in the current first-party implementation. Confirm the final release's retention and support-report handling before describing either publicly. No automatic first-party analytics/crash-upload implementation was identified by this audit; this is not a blanket statement about system services or SDKs.
- WhisperKit downloads selected models over the network. Downloads inherently expose network/request metadata to the hosting services; review the actual resolved SDK, endpoints, tokenizer/model fetches, caching, licenses and privacy terms. Test explicit consent, size information, cancellation, retry, offline use and Intel limitations with the store app.
- The external assistant is disabled in the store validation build. If retained in the shipping store edition, re-evaluate authentication, prompts/media/tool transmissions, provider retention and reviewer access. The direct edition still requires that disclosure.
- The resolved dependency tree includes privacy resources from `swift-crypto`; inspect the final archive's combined privacy report and the full inventory, including WhisperKit, swift-transformers, RNNoise, gifski, Logging and MenuBarExtraAccess. A dependency's manifest covers its own declarations, not the whole app.
- The owner must supply a public privacy-policy URL, support contact, complete App Store Connect answers and confirm the intended service relationships. These have not been published or submitted.

[A6 remains open](APP-STORE-EVAL.md). Re-audit the exact signed archive, retained feature set and pinned dependency versions before submission.
