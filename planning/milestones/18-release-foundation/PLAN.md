# Milestone 18: direct-release foundation

- [x] Write failing hosted/version and isolated release-script tests before implementation.
- [x] Use the independent build number in the app and signed appcast; validate metadata against the built bundle.
- [x] Make update delivery explicit and support preparation without publishing or requiring unused updater credentials.
- [x] Separate preparation, clean-candidate tagging and publication; provide a read-only publication preview and fail before external writes on invalid candidates.
- [x] Verify affected tests, formatting, lint and a warning-free Debug build and a universal Release build; record Release warnings; inspect version and architecture outputs.
- [x] Record actual evidence in the release checklist and keep signing, installation QA and App Store implementation gates open.
- [x] Commit changes in small semantic groups.

## Evaluation

Pass requires independent compiled version/build values, feed values matching the built app, no feed replacement on invalid metadata/signing, and a publication dry run that performs no remote writes. Candidate tags must identify clean, already-committed source. Manual download and signed-update delivery must have distinct artifact requirements. Commands are tested against disposable fixtures with fake external tools; no user account, network, or signing key is used by tests. Real publication and credential-dependent release acceptance are outside this implementation checkpoint.
