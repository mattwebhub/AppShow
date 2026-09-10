# Security policy

## Supported versions

Only the latest release gets security fixes. Check [Releases](https://github.com/mattwebhub/AppShow/releases) for the current version.

| Version | Supported |
| ------- | --------- |
| Latest  | Yes       |
| Older   | No        |

## Reporting a vulnerability

If you find a security issue, please don't open a public issue. Instead, use GitHub's private vulnerability reporting for this repository (Security tab, "Report a vulnerability") and include:

- A description of the vulnerability
- Steps to reproduce it
- Any relevant logs or screenshots

I'll acknowledge your report within 48 hours and work with you on a fix before any public disclosure.

## Scope

The Mac App Store edition runs in App Sandbox; the direct-download edition runs without it. Depending on the selected capture features, AppShow requests these system permissions:

- Screen Recording
- Accessibility (direct-download edition only)
- Microphone (optional)
- Camera (optional)

Security issues related to how the app handles these permissions, stores user data, or processes recordings are all in scope.

The optional assistants share messages and requested project context with the selected provider. See the [privacy policy](PRIVACY.md) for storage, sharing and deletion details.

## Disclosure

Once a fix is ready, I'll publish a new release with a note in the changelog. If you reported the issue, you'll get credit unless you prefer otherwise.
