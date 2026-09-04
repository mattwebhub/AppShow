# Milestone 10 verification

## Automated

- [x] `make format` and `make lint` pass.
- [x] `make build` passes with no warnings.
- [x] Full suite: 707 tests in 78 suites pass.
- [x] `TEST_RUNNER_APPSHOW_RUN_EXPORT_TESTS=1 make test T=ExportPipelineTests`: 6 tests pass, including both SDR and HDR arguments for webcam focus across cuts. Both argument results were also verified in the xcresult artifact.
- [x] Xcode project plist and `git diff --check` pass.

## Human

- [ ] Restart the updated Debug app; enable Options → Include webcam, choose a device, record and stop.
- [ ] Confirm the recording preview and new edit show a circular bottom-right webcam at the default size.
- [ ] Change all four positions and size in Options/Settings; record again and verify those defaults. Existing edits keep their own layout.
- [ ] Add Focus webcam from the Webcam properties tab. Play through expansion, fullscreen and return, then add another focus section.
- [ ] Move and resize focus sections in source and compressed timelines. Click a section to edit start/end, transitions or remove it; check Undo.
- [ ] Export a recording and compare it with the preview, including a cut inside a focus section.
- [ ] Ask a provider to add, retime and remove a webcam region through MCP while watching the timeline.
