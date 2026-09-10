# Preparing a direct-download release

This workflow implements candidate preparation and publication controls from D1, D4 and P2 in the [release checklist](PUBLIC-RELEASE-CHECKLIST.md). It does not close the signing, installation, product QA or App Store gates.

## Version and delivery mode

`MARKETING_VERSION` is the three-part public version, and `CURRENT_PROJECT_VERSION` is an independent positive integer that increases for each distributed build. The compiled `CFBundleShortVersionString` and `CFBundleVersion` must match those values before an appcast or candidate can be produced. The appcast takes its minimum macOS version from the actual built bundle.

Delivery follows the compiled app's configuration:

| Compiled `SUPublicEDKey` | Mode | Candidate artifacts |
| --- | --- | --- |
| Absent or empty | Manual downloads | Versioned DMG, release notes and receipt; no feed or Sparkle credential required |
| Valid base64 Ed25519 public key | Signed in-app updates | Same artifacts plus a signed appcast matching the app's version, build, minimum OS and key |

The current app remains in manual-download mode. About → Releases opens the public download page. This preserves the existing behavior while the first-release update preference is pending. Enabling signed in-app updates requires committing the intended public key, supplying its private signing key through `APPSHOW_SPARKLE_KEY`, and completing D4's real update tests. These changes do not enable automatic installation or background update checks.

## Freeze and prepare

1. Select an unused public version and increase the build number in `Config.xcconfig`. The inherited `v0.14.7` tag already identifies an older commit, so it cannot identify the new release.
2. Complete the applicable checklist checks, update the changelog with `make changelog`, review it, and commit all source and documentation changes. `make tag` no longer edits the changelog.
3. Configure Developer ID Application signing and the existing notarization environment: `APPSHOW_SIGNING_IDENTITY`, `APPSHOW_APPLE_ID`, `APPSHOW_TEAM_ID`, and `APPSHOW_APP_PASSWORD`. Keep credentials outside the repository and logs. Sparkle-enabled builds additionally require `APPSHOW_SPARKLE_KEY`.
4. Run `make prepare-release`. It requires clean source, builds Release, packages/signs/notarizes with the existing DMG script, verifies distribution, generates an appcast only when enabled, and writes the candidate receipt and notes. It creates no tag and performs no GitHub operation.
5. Review `dist/release-notes.md`, `dist/release.json`, the artifact and the remaining checklist evidence. Generated notes summarize commits since the preceding reachable tag. Edit the committed changelog/source and reprepare if the candidate needs changes; changing a recorded artifact invalidates the receipt.
6. Run `make tag`, then `make release-preview`. The preview validates the local tag/commit, clean working tree, built metadata, expected artifact set and SHA-256 hashes. It does not contact GitHub, push, sign or mutate artifacts.

`make prepare-release` uses the existing packaging implementation; its inside-out signing review and real clean-machine acceptance still belong to D3/D5. A receipt records which bytes and commit were prepared. It is not a substitute for release approval or proof that manual QA was completed.

## Publish the reviewed candidate

After the selected-channel checklist passes and the candidate is approved, run `make publish`. This command consumes the prepared receipt and existing tag. It does not rebuild or create a tag. It repeats distribution checks, pushes only that release tag to the AppShow repository, creates the release with notes from a file, and updates the Sparkle feed after release creation when enabled. Manual-download releases never require or upload a feed.

Calling `scripts/publish-release.sh` directly defaults to preview mode; `--publish` explicitly enables remote writes. An existing public version is never overwritten. Dirty source, changed artifacts/notes, stale built metadata or a tag that points elsewhere fail before any GitHub operation.

If publication fails after the release is created but before the feed is uploaded, keep the signed release artifact immutable and inspect the actual GitHub state. Complete the feed upload using the reviewed `dist/appcast.xml`, or restore the previous feed according to the rollback plan. Re-running publication deliberately refuses to overwrite an existing release. Do not delete and recreate a version to hide a partial failure.

## Verification

```sh
make test T=ReleaseMetadataTests
make test T=ReleaseScriptTests
make test T=ReleaseWorkflowTests
```

Script tests run in disposable repositories, including paths with spaces, using fixture signing/build/publication tools. Tests cannot use a real GitHub account or push to a network remote. Hosted metadata tests inspect the actual built app. Developer ID/notarization and end-user update acceptance require separate evidence from the real candidate.

References: [Sparkle's version and signing contract](https://sparkle-project.org/documentation/publishing/), [Apple bundle build identifier](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleversion).
