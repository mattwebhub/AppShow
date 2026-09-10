# Public presentation verification

Verified locally on September 8, 2026, on `webcam-presentation-and-review`.

| Check | Result |
| --- | --- |
| Source artwork | Byte-for-byte match with the owner-supplied PNG |
| Generation | `make brand` generates the icon sizes, README icon, SVG banner, and social-preview PNG |
| Asset catalog | All ten macOS size/scale slots resolve to PNG files with the expected dimensions |
| Transparency | All seven icon sizes have an alpha channel; native AppKit pixel checks confirm transparent corners and opaque centers |
| Repository graphics | SVG parses successfully; social preview is 1280 × 640 and below 1 MB |
| Local documentation links | 44 Markdown/HTML file targets checked and present before the verification record was added |
| Issue forms | Three YAML files parse; form IDs are unique |
| Presentation | Desktop and mobile previews rendered locally with Pandoc's GitHub-flavored Markdown reader and inspected in headless Chromium |
| Formatting | `make format` and `git diff --check` pass |
| Lint | `make lint` passes without warnings |
| Build | `make build` passes without warnings; the compiled app contains `AppIcon.icns` |
| Project and signature | `plutil` project validation and `codesign --verify --deep --strict` pass |

The local HTML and screenshot previews are under ignored `.build/brand/`. They approximate GitHub presentation; the published repository has not been visually checked. No runtime behavior changed, so no new unit tests were added and the existing suite was not rerun for this change.

## Remaining manual checks

- [ ] Restart the new build and inspect its icon in the Dock and Finder.
- [ ] Capture the current AppShow editor with a presentation-safe sample project. Replace the clearly attributed inherited Reframed reference in the README.
- [ ] Review and publish the local changes, then check the rendered GitHub README.
- [ ] Upload `docs/assets/social-preview.png` in the repository's social-preview settings.

The repository is already public, but this work has not been committed or pushed. No release was created and no repository settings were changed.
