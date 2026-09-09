# 0018. Store target and persistent file access

Status: accepted implementation boundary; shipping feature decisions remain pending
Date: 2026-09-09

## Context

The owner authorized all feasible local App Store readiness work. The direct-download application embeds Sparkle and an external-assistant helper, assumes home-relative file paths, and uses Accessibility for cross-app controls and global shortcut interception. These cannot be treated as a validated sandboxed store application.

## Decision

Add an independent `AppShowStore` target and scheme, sharing the source build phase so future application files remain common. Keep framework and resource phases separate to exclude Sparkle, updater metadata/UI, the MCP executable and external-assistant resource payloads. `APP_STORE` selects the store behavior. The local product filename is `AppShowStore.app`, with the existing AppShow display name and bundle identifier.

The validation edition disables the external assistant panel, bridge and process/probe launch while its shipping design is pending. It excludes cross-app AX resize/centering/raising and the global event tap; local shortcuts and visible recording controls remain. No unsandboxed escape helper or temporary sandbox exception is introduced. This does not decide permanent feature removal or store distribution rights.

Store defaults use container Application Support and system-provided temporary storage. User folder and project selections use a container-local bookmark database. Resolve persisted URLs before I/O, refresh stale bookmarks under an active scope, persist atomically, and propagate failed resolution. Retain persistent grants for the process lifetime to cover concurrent editors/exports; release transient import scopes at operation completion. Dependency injection allows bookmark tests without user files or real permission grants. The direct-download edition retains its current locations and migration behavior.

Keep a store-only first-party privacy manifest grounded in observed API use. Audit the exact built artifact with a local Python evaluator. Local builds/archives and automated tests are evidence for implementation, not proof of sandbox runtime behavior, rights, distribution signing, store metadata completeness or App Review approval.

## Consequences

Both channels must continue to build. Store resource/framework and Info.plist changes require parity review where relevant; source files are shared. Every final candidate must be re-evaluated and manually exercised under sandbox enforcement. The owner still decides the retained assistant/global-shortcut feature expectations, distribution rights, service disclosures and release identity. No upload or publication is part of this milestone.
