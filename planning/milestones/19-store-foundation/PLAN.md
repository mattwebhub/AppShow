# Milestone 19: App Store foundation

- [x] Add a separate sandboxed store target and build scheme without Sparkle or the external CLI helper.
- [x] Give store builds container-local settings, scratch files and default output locations; persist user-selected folder/project grants and retain access during use.
- [x] Prevent unsupported external assistant and Accessibility operations in the validation build, pending the store feature decision; preserve usable local controls.
- [x] Audit the built store artifact with repeatable checks for entitlements, updater payload, version, architecture and signatures.
- [x] Add isolated regressions first, run affected/full tests, format/lint and build both channels.
- [x] Record evidence, remaining runtime/account/legal gates and small semantic commits.

## Evaluation

A local foundation pass requires a distinct store target with App Sandbox, no Sparkle linkage or helper payload, correct version/build metadata and container-aware paths. File-access tests must prove bookmarks persist, stale bookmarks refresh, resolved moved URLs are used and access lifetimes stay balanced. Tests use temporary fixtures and injected access operations, never real user locations, permissions or network. The separate store-hosted suite additionally verifies native bookmarks and synthetic encoded exports with App Sandbox enabled. A successful build or local artifact audit does not establish App Review eligibility, distribution signing or hardware capture acceptance.
