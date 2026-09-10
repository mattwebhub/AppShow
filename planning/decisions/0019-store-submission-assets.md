# ADR 0019: Reproducible Store screenshot layouts

Status: accepted for local design preparation, 2026-09-09.

## Decision

Keep Store screenshot copy and capture direction in JSON, layout in HTML/CSS, and render with an installed Chromium executable using a temporary browser profile. Use authentic captures of the intended Store edition as unchanged image inputs. Existing brand artwork is reused; app UI is not generated or reconstructed.

Keep private footage, native captures, render output and the independent presentation project under ignored `dist/app-store-submission/`. Commit only the design sources, renderer and release documentation.

Missing captures render as labeled proofs. Strict capture mode refuses missing inputs. The output report checks dimensions, RGB format and hashes but never claims submission readiness from those technical checks. Candidate parity, content rights, interaction acceptance and owner review are separate evidence requirements.

## Rationale and consequences

The owner requested submission assets and review before anything is submitted. Native capture currently lacks macOS permission, while layout work can proceed independently. This workflow makes that boundary visible and allows real captures to replace empty slots without redesigning the package. It introduces an optional Chromium rendering dependency, not a dependency for building AppShow.
