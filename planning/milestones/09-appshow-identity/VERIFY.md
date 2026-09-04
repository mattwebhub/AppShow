# Verify milestone 09

| Check | Expected | Result |
|---|---|---|
| Identity unit tests | constants and bundle metadata use AppShow identifiers | pass: `AppShowPathsTests`, 11 tests |
| New project | generated bundle ends in `.appshow` | pass: project and conversation-store tests |
| Legacy project | `.frm` fixture opens and survives rename | pass: `legacyFrmProjectOpensAndKeepsItsExtensionWhenRenamed` |
| Private data | absent destination migrates; existing destination is never overwritten | pass: both migration branches covered |
| Build products | `AppShow.app` and `AppShowTests.xctest` build through the AppShow scheme | pass: Debug and universal Release builds |
| Formatting | `make format` leaves no diff | pass |
| Lint | `make lint` | pass locally and from a clean clone |
| Build | `make build` | pass locally and from a clean clone |
| Tests | `make test` | pass: 678 tests in 76 suites |
| MCP shim | `make test-shim` | pass: compiled stdio shim authenticates and lists editing tools |
| Export | gated `ExportPipelineTests` | pass: 5 tests, including cuts, music, exact destination, and blur |
| Presentation scenario | `make test-scenario` | pass: mutation/Undo and exported draft checks |
| Live providers | `make test-agent-skills CLAUDE_MODEL=sonnet` | pass: Claude Code and Codex discover and invoke the bundled skill through the live bridge |
| Package | DMG/appcast scripts resolve AppShow artifact names | pass: `AppShow-0.14.7.dmg`, 26,133,985 bytes, valid checksum, universal `x86_64 arm64` app |
| Package metadata | bundle and document identifiers are owned by AppShow | pass: `com.mattwebhub.appshow`, `.appshow` export, legacy `.frm` import |
| Clean checkout | build and compatibility tests do not depend on local untracked state | pass at `675c9bd`: lint, build, 11 path tests, and 17 project tests |
| Residual identity | remaining Reframed references are compatibility, upstream history, provenance, or recorded fixtures | pass |

## Distribution boundary

The verified DMG is a local development artifact. The contained app has a valid ad-hoc signature and has not been notarized. A public release still requires a Developer ID Application identity and notarization credentials through the `APPSHOW_*` release variables.

Human UI checks from milestones 02, 03, 04, 06, and 07 remain intentionally separate; this milestone verifies the identity migration and its automated compatibility contract.
