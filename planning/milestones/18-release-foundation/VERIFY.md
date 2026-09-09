# Milestone 18 verification

Date: 2026-09-09

## Result

The direct-release foundation evaluation passes its automated implementation criteria. The public-download and App Store channels remain NOT READY; this checkpoint does not approve a distribution candidate.

| Evaluation | Evidence | Result |
| --- | --- | --- |
| Independent compiled version/build | Hosted regression first reproduced `0.14.7` where build `26` was expected. Debug test and Release metadata inspection now agree on public version `0.14.7`, build `26`, minimum macOS `15.0`. | Pass |
| Valid signed feed | Disposable fixture covers paths with spaces, actual compiled metadata, missing public key, stale built version and a signature from the wrong key. CryptoKit validates the archive signature against the app public key before atomic feed replacement. | Pass |
| Preparation boundary | Fake build/package/distribution tools prove build-before-package order, receipt creation only after validation, no tagging or GitHub calls, and no feed requirement for manual downloads. | Pass |
| Publication boundary | Preview succeeds without a feed or external calls. Dirty source, replaced archive, changed notes, moved tag and changed HEAD fail before external calls. | Pass |
| Tag boundary | The original command tagged dirty source and changed the changelog; the regression now passes with clean-source enforcement and unchanged committed notes. | Pass |
| Full hosted suite | `make test`: 782 tests in 93 suites pass. Release metadata, scripts and workflow contribute nine tests, including parameterized failure cases. | Pass |
| Style and Debug build | `make format`, `make lint`, standalone Swift signature-helper formatting/lint, and `make build` pass. Debug build has no warnings. | Pass |
| Universal Release build | `make release` exits successfully; `lipo -archs` reports `x86_64 arm64`. The build emits 11 missing `.build/ModuleCache.noindex/*.pcm` warnings. These require investigation before claiming a warning-free release build. | Pass with follow-up |
| Static validation | Shell syntax, Python compilation, local documentation links and `git diff --check` pass. | Pass |

Local logs: `/tmp/appshow-release-metadata-red.log`, `/tmp/appshow-release-workflow-red.log`, `/tmp/appshow-release-signature-red.log`, `/tmp/appshow-release-workflow-final.log`, `/tmp/appshow-release-foundation-build.log`, `/tmp/appshow-release-foundation-full.log`, and `/tmp/appshow-release-foundation-universal.log`.

## Still required

- Select an unused release version and increase its build number; inherited `v0.14.7` identifies older source.
- Confirm the first-release update preference. Existing manual-download behavior remains provisional; no public key was added.
- Investigate the Release module-cache warnings and verify a fresh distribution build.
- Review nested signing, prepare the real Developer ID/notarized candidate, and perform Gatekeeper, clean installation, permission, recording, export and update acceptance checks.
- Implement and validate the separate App Store requirements in [the store evaluation](../../releases/APP-STORE-EVAL.md).
- Publish only after applicable checklist evidence and owner acceptance are complete.

No real candidate was prepared or notarized, no credentials were used, and no repository tag or remote release was created by this verification. Test tags and keys exist only inside disposable fixtures. The current app was not restarted during this work.
