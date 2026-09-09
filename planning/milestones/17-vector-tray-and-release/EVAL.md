# Vector tray and release-planning evaluation

Defined 2026-09-09 before implementation. Each required task row must pass; a blocked release gate never becomes a pass because this implementation is complete.

| ID | Acceptance criterion | Verification | Result |
| --- | --- | --- | --- |
| I1 | Colored SVG derives from the current icon; dark background is absent, with genuine transparent holes | Source hash, vector-only XML, source-background alpha comparison | Pass — 99.9722% background transparency; 0.1785% trace-mask disagreement |
| I2 | Menu bar asset contains only vector geometry, has transparent margins, and remains legible at 18 pt on light/dark backgrounds at 1×/2× | XML checks, native contact sheet, visual review | Pass — vector-only asset and native 1×/2× contact sheet inspected |
| I3 | Runtime loads the bundled SVG as a template, preserves 18×18 sizing and recognizable activity indicators | Hosted `MenuBarIconTests`, native state renders | Pass — 3 hosted icon tests; all activity states rendered |
| I4 | Regeneration is deterministic and leaves the original Dock icon/artwork unchanged | Regenerate twice and compare asset hashes; baseline source hashes | Pass — two identical regenerations; source/Dock assets unchanged |
| I5 | Formatting, lint, build, affected tests, and whitespace checks pass | Captured command results | Pass — format, lint, warning-free build, icon tests and whitespace checks |
| R1 | Public-release checklist covers product QA, compatibility, privacy, licenses, signing/notarization, update delivery, materials, publication and rollback | Every gate has an owner and observable completion evidence | Pass — G1–G9, D1–D6, P1–P4 define owners and evidence |
| R2 | App Store evaluation covers sandbox/runtime, assistant, file access, shortcuts, updater, privacy, licensing, signing, versioning, metadata, TestFlight and review | Source evidence plus dated primary Apple sources; explicit status for every gate | Pass — A1–A12 evaluated; current channel verdict NOT READY |
| R3 | Checklist reports release status without confusing development signatures, unit tests or unsigned packages with production readiness | Separate direct-download and App Store verdicts; missing evidence stays open | Pass — both release-channel verdicts remain NOT READY |

Release verdict rule: every required channel gate must pass against the exact candidate commit and artifact. Fail or Not tested means not ready. Not applicable requires a recorded product decision. This task prepares assets and evaluates readiness; publication is a subsequent release action.

Task result: **PASS**. Detailed evidence and remaining release checks are in [VERIFY.md](VERIFY.md). Completion of this task does not satisfy the open distribution gates.
