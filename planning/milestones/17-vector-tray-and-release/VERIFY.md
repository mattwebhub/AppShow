# Vector tray and release evaluation results

Verified locally on 2026-09-09 on `webcam-presentation-and-review`, following base commit `5ae0ef4`.

| Check | Evidence/result |
| --- | --- |
| Red test | `/tmp/appshow-tray-red.log`: two tests failed because the new asset did not exist; existing activity behavior test passed |
| Hosted tests | `/tmp/appshow-tray-final-tests.log`: all 3 `MenuBarIconTests` pass against the built app asset |
| Actual transparency | `make eval-tray`: 99.9722% of dark/background samples fully transparent in both outputs; opaque coverage 33.3969% |
| Source fidelity | Trace mask differs from thresholded source by 0.1785%; shared exact silhouette path; mean raster alpha difference between color clipping and template is 0.1601% |
| True vectors | No embedded raster or external image references; quadratic path geometry; template metadata preserves vector representation |
| Determinism | Evaluation regenerates twice and verifies all four artifact hashes and the unchanged source master |
| Original icon | `git diff --exit-code HEAD -- AppShow/Assets.xcassets/AppIcon.appiconset docs/brand/app-icon.png docs/brand/artwork.png` passes before the new commits |
| Native visuals | `make preview-tray` renders the production `MenuBarIcon` using the compiled asset at 18 pt, 1×/2×, with light/dark template tints; [contact sheet](../../../docs/brand/tray-preview.png) visually inspected |
| Formatting/build | `make format`, `make lint`, separate preview-script Swift lint, warning-free `make build`, project plist validation and whitespace checks pass |
| Signature | Strict Debug bundle signature verification passes; this is not distribution-signing evidence |
| Documentation | 53 local links resolve across all changed Markdown files |
| Release plan | [Checklist](../../releases/PUBLIC-RELEASE-CHECKLIST.md) covers shared product QA, direct download, store evaluation, publication and recovery with owners and observable evidence |
| App Store evaluation | [A1–A12](../../releases/APP-STORE-EVAL.md) evaluated against source and current Apple documentation; NOT READY, with missing runtime/account evidence explicitly recorded |

The earlier full suite (770 tests) and 11 gated exports passed immediately before this task. They were not rerun for this menu-icon change; its three focused tests were added and run red/green. No capture/editor/export behavior was changed.

## Remaining release checks

Actual menu bar hover/highlight/open interaction, VoiceOver operation, hardware capture, real-media acceptance, signing/notarization, updates, sandbox/store implementation and store-account/submission steps remain explicit gates in the release checklist. The contact sheet simulates light/dark template tint; it is not a screenshot of the user's live menu bar. No existing recording/editor session was terminated to restart the app. No release, push, upload, repository-setting change or store submission was performed.
