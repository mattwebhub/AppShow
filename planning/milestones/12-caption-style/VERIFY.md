# Caption style verification

Automated verification, 2026-09-05:

- The initial failing tests establish the missing font model, resolver, measurement and MCP contract.
- 733 tests in 83 suites pass, including font fallback/weight, legacy decode, color persistence, pixel rendering, project reopening, MCP styling and Undo/Redo.
- `make format`, `make lint`, `make build`, project validation and `git diff --check` pass. Debug build emits no warnings or errors.
- SDR and HDR share the tested caption drawing function; encoded-video and interactive preview comparisons remain manual for this change.
- Logs: `/tmp/appshow-caption-red.log`, `/tmp/appshow-caption-final-tests.log`, `/tmp/appshow-caption-lint.log`, `/tmp/appshow-caption-build.log`.

Manual checks:

- Open Captions before generating text and choose a font, size, weight and font color.
- Generate captions, choose a background color and opacity; verify changes immediately in preview.
- Search installed fonts, select System again, and check long captions remain draggable.
- Undo/redo styling, save/reopen the project and compare burned-in SDR/HDR exports.
- Open on a Mac missing the selected font; verify the system fallback and retained saved name.
