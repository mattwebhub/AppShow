# 0004. Do not consume upstream's Sparkle update feed

Status: accepted
Date: 2026-09-03

## Context

`Reframed/Info.plist` set `SUFeedURL` to upstream's GitHub appcast and `SUEnableAutomaticChecks` to true. `Reframed/Utilities/SparkleUpdater.swift` additionally forces `automaticallyChecksForUpdates = true` in code, so the plist flag alone would not stop checks. `AppDelegate.applicationDidFinishLaunching` initializes `SparkleUpdater.shared` on every launch, including when a test bundle launches the app as its host. A fork build would offer to replace itself with upstream's release, signed with a key we do not own.

Sparkle 2 (`SPUStandardUpdaterController.m`) does not crash when the updater fails to start, but it shows an "updater error" alert one second after launch if `SUFeedURL` is present without a valid `SUPublicEDKey`, or if the bundle is unsigned. Removing keys is therefore worse than pointing them somewhere harmless.

## Decision

- `SUFeedURL` points at the fork's own future appcast: `https://github.com/mattwebhub/Reframed/releases/download/appcast/appcast.xml` (the path `scripts/publish-release.sh` uploads to). It returns 404 until we publish, so a manual "Check for updates" fails gracefully.
- `SUEnableAutomaticChecks` is false and `SparkleUpdater.swift` sets `automaticallyChecksForUpdates = false`.
- `SUPublicEDKey` keeps upstream's value for now. It only verifies files downloaded from our feed, which upstream cannot write to. It must be replaced with our own key from Sparkle's `generate_keys` before the first release (tracked in milestone 00 VERIFY and in `scripts/generate-appcast.sh`).
- `scripts/*.sh`, the About tab links (`Reframed/UI/SettingsAboutTab.swift`), and the changelog fetch in `Reframed/Utilities/UpdateChecker.swift` reference `mattwebhub/Reframed`.

## Consequences

- Dev and test builds never contact upstream.
- Manual update checks show a network error until we publish an appcast.
- Before the first release: generate our EdDSA key pair, put the public key in Info.plist, keep the private key out of the repo, and set `REFRAMED_SIGNING_IDENTITY` for `make dmg-release`.
- The test host still constructs `SparkleUpdater.shared` at launch; the launch guard from `docs/architecture/07-testability.md` should skip it.
