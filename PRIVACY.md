# AppShow Privacy Policy

Effective September 10, 2026.

AppShow is a Mac screen recorder and video editor maintained by [mattwebhub](https://github.com/mattwebhub/AppShow). This policy explains AppShow's local storage and optional network features. You do not need an AppShow account to record, edit or export.

## Recordings and local storage

AppShow uses macOS permissions to record the screen and the microphone, system audio or camera sources you select. Recordings, imported media, editing settings, captions and exports are stored on your Mac. Speech transcription runs locally with a downloaded model.

Projects can contain assistant messages and tool activity. Preferences, recent-project access bookmarks, model caches and operational logs are also stored locally. Logs may contain file paths and diagnostic details. AppShow rotates its own logs by size, keeping the current file and up to three older files; this is not a fixed time-based retention period.

AppShow does not operate a server that receives your recordings, projects or local logs automatically. Files in locations synchronized by a storage or backup service are subject to that service's settings and policies.

## Optional Claude Code and Codex assistants

The Assistant connects to Anthropic's Claude Code or OpenAI's Codex through the selected provider's own sign-in flow. A provider account and internet connection are required. Before sending from the conversation view, AppShow identifies the provider and requests permission to share project information.

When you use the Assistant, your messages and relevant conversation context are sent to that provider. AppShow's tools can return project settings, text, transcripts and requested image previews. Content visible in a preview may include personal information from your recording. Use the Assistant only with material you intend to share with the selected provider. Full exports require a separate confirmation.

Providers process authentication and account identifiers, request content, network information and service diagnostics. The bundled Codex runtime enables usage and performance metrics by default. The Mac App Store edition disables Claude Code's nonessential traffic; necessary authentication and AI service requests still occur. AppShow does not use advertising SDKs or send project data to advertising networks.

Provider retention, model improvement and account controls depend on the service, plan and preferences you select. Consult [Anthropic's privacy policy](https://www.anthropic.com/legal/privacy) and [Claude Code data usage](https://code.claude.com/docs/en/data-usage), or [OpenAI's privacy policy](https://openai.com/policies/privacy-policy/). AppShow does not change your provider's training preferences. Providers may process information in countries other than your own.

In the Mac App Store edition, provider authentication and runtime state are stored in dedicated directories inside AppShow's container. That edition does not import credentials from other CLI installations. The direct-download edition can use AppShow-managed runtimes or compatible user-installed CLIs and their account configuration.

## Downloads and external links

Installing a transcription model contacts Hugging Face and its download infrastructure for the Argmax WhisperKit model repository. Download requests expose information such as your IP address and the requested resource to the host. The download does not require uploading your recording. See [Hugging Face's privacy policy](https://huggingface.co/privacy).

The Mac App Store edition updates AppShow and its bundled assistants through Apple. The direct-download edition can check GitHub and provider distribution services for app or CLI updates and download them according to its update settings. These services receive the network information needed to handle requests. Opening support, source-code or provider links also uses the destination's privacy practices. See [GitHub's privacy statement](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement) and [Apple's privacy policy](https://www.apple.com/legal/privacy/).

## Your choices and deletion

You can use local editing without the Assistant, decline project sharing, and change capture permissions in macOS System Settings. You can remove projects and exports in Finder and delete downloaded models through AppShow's model controls. AppShow project bundles include the saved assistant conversation, so consider that history before sharing a project.

Deleting a project or uninstalling AppShow does not delete separately saved exports, backups or data already held by a provider. Local provider session caches may also remain independently of a project. Use the relevant provider's account and privacy controls to manage or request deletion of provider-held information. Contact the relevant storage service for synchronized copies.

## Contact and changes

For privacy questions about AppShow, use the [AppShow support page](https://github.com/mattwebhub/AppShow/issues). Issues are public: do not post credentials, private recordings or personal documents. Ask for a private contact route before sharing sensitive details. Support information you choose to submit is handled through that service to investigate and respond to your request.

Applicable law may give you rights concerning personal information, including access, correction, deletion and complaints to a data protection authority. AppShow's maintainer cannot access files stored only on your Mac or delete information from your provider account on your behalf.

Policy changes will be published on this page with an updated effective date.
