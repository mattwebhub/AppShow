# 0004. Do not consume upstream's Sparkle update feed

Status: accepted
Date: 2026-09-03

## Context

`Reframed/Info.plist` set `SUFeedURL` to upstream's GitHub appcast and `SUEnableAutomaticChecks` to true. `Reframed/Utilities/SparkleUpdater.swift` additionally forces `automaticallyChecksForUpdates = true` in code, so the plist flag alone would not stop checks. `AppDelegate.applicationDidFinishLaunching` initializes `SparkleUpdater.shared` on every launch, including when a test bundle launches the app as its host. A fork build would offer to replace itself with upstream's release, signed with a key we do not own.

Sparkle 2 (`SPUStandardUpdaterController.m`) does not crash when the updater fails to start, but it can show an updater error when launched without a valid key. AppShow therefore must not start Sparkle until its own key is configured.

## Decision

- `SUFeedURL` points at AppShow's future appcast: `https://github.com/mattwebhub/AppShow/releases/download/appcast/appcast.xml` (the path `scripts/publish-release.sh` uploads to).
- `SUEnableAutomaticChecks` is false and `SparkleUpdater.swift` sets `automaticallyChecksForUpdates = false`.
- The inherited `SUPublicEDKey` is removed. `SparkleUpdater` does not construct its controller and the About button stays hidden while no key is present.
- Before enabling updates, generate an AppShow EdDSA key pair with Sparkle's `generate_keys`, add only its public key to Info.plist, and keep the private key outside the repository.
- `scripts/*.sh`, the About tab links (`AppShow/UI/SettingsAboutTab.swift`), and the changelog fetch in `AppShow/Utilities/UpdateChecker.swift` reference `mattwebhub/AppShow`.

## Consequences

- Dev and test builds never contact upstream.
- Update checks remain unavailable until AppShow's key is provisioned.
- Before enabling updates: generate the EdDSA key pair, put the public key in Info.plist, keep the private key out of the repo, publish an appcast, and set `APPSHOW_SIGNING_IDENTITY` for `make dmg-release`.
- The test host still constructs `SparkleUpdater.shared` at launch; the launch guard from `docs/architecture/07-testability.md` should skip it.
