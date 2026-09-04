# Milestone 09: AppShow identity

Goal: ship the integrated product as AppShow without breaking legacy Reframed projects or private user data.

## Phases

- [x] P1: identity constants, new defaults, legacy path migration, and project-extension compatibility tests.
- [x] P2: rename the Xcode project, app/test targets, scheme, module, products, source roots, and bundle identifiers.
- [x] P3: rename active symbols, environment variables, log labels, test harness paths, and helper metadata.
- [ ] P4: update Info.plist document registrations, permission copy, update metadata, release scripts, and packaging.
- [ ] P5: update active documentation and repository metadata while retaining explicit upstream/provenance history.
- [ ] P6: run formatting, lint, build, the full test suite, packaging checks, and compatibility tests from a clean checkout.

## Compatibility contract

- Existing `.frm` bundles open without content conversion.
- New projects use `.appshow`.
- Renaming preserves `.frm` on legacy bundles and `.appshow` on new bundles.
- `~/.reframed` moves to `~/.appshow` only when the destination is absent.
- `APPSHOW_*` variables are canonical; `REFRAMED_*` inputs remain temporary fallbacks where an external integration may still provide them.
- Project metadata version 1 and its media filenames remain unchanged.
