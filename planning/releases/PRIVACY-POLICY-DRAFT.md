# AppShow privacy policy — unpublished draft

Drafted September 10, 2026 from the Store data-flow inventory. The owner must provide the public contact details and confirm the provider/dependency disclosures before publication. This draft has not been entered as App Store Connect's data-collection answers.

## Your recordings and projects

AppShow records the screen and optional audio or camera sources that you choose using macOS permissions. Recording media, imported files, editing settings and exported videos are stored on your Mac. Your project can include text, captions and an assistant conversation. Files you save outside AppShow's container remain in the locations you choose; removing the app does not necessarily remove those documents.

You control which projects and exported files you share with other people or services. You can delete your project bundles and exported files using Finder. Backups and files you have separately shared are controlled by their respective storage services.

## Optional AI assistants

AppShow can connect to Claude Code or Codex using an account with the selected provider. Before sending from the conversation view, AppShow identifies Anthropic or OpenAI and asks permission to share your messages, project information and preview images requested by the assistant. Editing tools may return project text, transcripts and media previews as part of your request. The assistant can change the project through AppShow's tools, and full exports require separate confirmation.

Messages and assistant activity are saved with the project. Provider authentication and runtime state are stored in AppShow's container. The provider's service may process request and account information under the terms and privacy practices applicable to your account. Deleting a local AppShow project does not delete information already held by that provider. Use the provider's account controls for provider-side requests.

## Models and network requests

Transcription features can download model resources. These downloads contact the resource host and expose the network information normally needed to serve a request. Downloaded models are stored locally for reuse. AI assistant requests require a network connection. In the Mac App Store edition, bundled assistant executables update with AppShow through App Store releases.

## Local operational data

AppShow stores preferences, recent-project access information, caches and operational logs on your Mac. Logs can include file paths and diagnostic details. Review any files before sharing them with support. The first-party implementation examined for this draft does not automatically upload these local logs as analytics or crash reports; the final provider and SDK inventory still needs review before a broader collection claim is published.

## Contact and publication checklist

- Owner: confirm the public operator/rights-holder identity.
- Contact: supply the public privacy and support email/address or web contact.
- Confirm diagnostic retention and support-report handling.
- Confirm the exact providers, model-host endpoints and applicable privacy links from the final package.
- Confirm deletion/account controls and accurate App Store Connect answers.
- Publish the approved policy at the owner-selected URL and add the in-app link before submission.

Engineering reference: [Store privacy audit](PRIVACY-AUDIT.md).
