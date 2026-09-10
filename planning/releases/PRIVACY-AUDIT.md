# Store privacy implementation audit

Date: 2026-09-10. Scope: first-party source and the local Store target with restored provider integrations. This is engineering evidence, not a completed privacy policy or App Store Connect disclosure.

## Submission follow-up

The current public policy is [PRIVACY.md](../../PRIVACY.md), with a Settings → About link in both editions. The policy distinguishes local processing from optional provider requests and model/update downloads. Its contact route is the existing public support page; App Review's private contact details are not copied into the repository.

Source inspection confirms that first-party logs rotate at 5 MiB with three retained older files. WhisperKit's default model repository is `argmaxinc/whisperkit-coreml` on Hugging Face; transcription itself uses the installed local model. Store provider state remains container-scoped, and Claude nonessential traffic is disabled.

The pinned Codex `rust-v0.153.3` source sets `DEFAULT_ANALYTICS_ENABLED` to true in `codex-rs/exec/src/lib.rs`. `core/src/config/otel.rs` defaults metrics to Statsig, and `core/src/otel_init.rs` gates this on the analytics setting. AppShow does not currently override that setting. The privacy policy therefore discloses provider usage and performance metrics; it does not claim that all integrated runtimes are telemetry-free. See the [pinned implementation](https://github.com/openai/codex/blob/rust-v0.153.3/codex-rs/exec/src/lib.rs).

Provider-side retention and model-improvement choices follow the relevant account: [Claude Code data usage](https://code.claude.com/docs/en/data-usage), [OpenAI privacy](https://openai.com/policies/privacy-policy/), and [Hugging Face privacy](https://huggingface.co/privacy). These references do not justify applying unrelated website features, such as payments or advertising, to AppShow's own flows.

App Store Connect data collection must include integrated providers under [Apple's definitions](https://developer.apple.com/app-store/app-privacy-details/). Local-only recordings are not themselves collection. Assistant messages, project text/transcripts and requested previews are transmitted to account-linked provider services; the optional-assistant feature does not justify a blanket “Data Not Collected” answer. Provider identifiers, network-derived information and diagnostics require the corresponding questionnaire details. The questionnaire was started but not completed or published before the owner stopped desktop control.

## First-party API declarations

The store resource `AppShow/PrivacyInfo.xcprivacy` declares the following observed uses. It is included only in the store target; the direct edition's broader external-assistant behavior needs its own review.

| API category | Source use | Declared reason |
| --- | --- | --- |
| File timestamps/metadata | `RotatingFileLogHandler` reads local log size; `MediaFileInfo` reads media size; recent-project enumeration requests modification metadata and computes bundle size. | `C617.1` for container files; `3B52.1` for user-authorized projects/media. |
| System boot time | `AudioWaveformGenerator` throttles progress; `ExternalAudioPreviewEngine` measures intervals between drift checks. | `35F9.1` for elapsed-time/timer calculations within the app. |

Reason selections were checked against [Apple's current API category/reason definitions](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype). They are an inference from the cited source uses, and must be revisited when behavior changes. No first-party UserDefaults, disk-capacity or active-keyboard reason was added without corresponding source evidence. This does not establish that transitive SDKs use none of those APIs.

The manifest deliberately supplies API reasons only. It does not assert completed tracking/data-collection disclosures on behalf of all dependencies and services.

## Data flow and remaining owner work

- Screen, camera, microphone and system audio become local project media. Imports are copied into project bundles; exports are local files. Projects can include captions and saved assistant conversations in both editions. A public policy must explain storage, user-controlled sharing/deletion, and what deleting the app does to documents outside the container.
- Logs include operational details and paths and remain local in the current first-party implementation. Confirm the final release's retention and support-report handling before describing either publicly. No automatic first-party analytics/crash-upload implementation was identified by this audit; this is not a blanket statement about system services or SDKs.
- WhisperKit downloads selected models over the network. Downloads inherently expose network/request metadata to the hosting services; review the actual resolved SDK, endpoints, tokenizer/model fetches, caching, licenses and privacy terms. Test explicit consent, size information, cancellation, retry, offline use and Intel limitations with the store app.
- The Store assistant is enabled. Before the first send to each provider in a conversation view, AppShow identifies OpenAI or Anthropic and asks permission to send messages, project details and assistant-requested preview images. Typed MCP tools can return project metadata, text/transcripts and image content; project-local conversation history persists in the document. Full exports have a separate confirmation. This is a first-party UI/source check, not a completed inventory of provider-side collection or retention.
- Store sign-in runs through the bundled provider's own flow. Codex and Claude state stays in dedicated container directories; AppShow does not copy external CLI credentials or configuration. The Store environment disables provider self-updates and Claude nonessential traffic, while the direct runtime updater is excluded at compilation. These controls do not establish that provider network requests contain no telemetry. Review the exact pinned provider packages and their current service terms for App Privacy answers.
- The resolved dependency tree includes privacy resources from `swift-crypto`; inspect the final archive's combined privacy report and the full inventory, including WhisperKit, swift-transformers, RNNoise, gifski, Logging and MenuBarExtraAccess. A dependency's manifest covers its own declarations, not the whole app.
- The owner must supply a public privacy-policy URL, support contact, complete App Store Connect answers and confirm the intended service relationships. These have not been published or submitted.

[A6 remains open](APP-STORE-EVAL.md). Re-audit the exact signed archive, retained feature set and pinned dependency versions before submission.
