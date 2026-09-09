# Speed regions verification

Date: 2026-09-08

## Automated evidence

- Initial `SpeedTimelineTests` failed before the model and mapping existed (`/tmp/appshow-speed-red.log`), then passed (`/tmp/appshow-speed-core.log`).
- Immediate Undo regression failed with stale player speed (`/tmp/appshow-speed-undo-red.log`). Restoring speed now synchronizes the player immediately.
- Trim regression failed because transport duration included trimmed content (`/tmp/appshow-speed-trim-red.log`). Transport and sidecar captions now share a trim-clipped speed timeline.
- Export regressions exposed intermittent extra duration in parallel exports (`/tmp/appshow-speed-exports-repeat.log`). Both writers now explicitly end at the intended duration.
- Nine gated export tests pass, including all six speed presets with encoded audio and cut/effect combinations across SDR/HDR and normal/parallel export (`/tmp/appshow-speed-exports-final.log`). Speed duration tolerance is two milliseconds.
- Full suite: 766 tests in 89 suites pass (`/tmp/appshow-speed-full.log`), including editor reopening/history, agent CRUD, subtitle/ramp time mapping, and rendered timed-blur regressions.
- Formatting, lint, project validation, whitespace checks, warning-free Debug build, and strict code-signature verification pass. AppShow was gracefully restarted on the updated Debug build.

## Manual checks

- [ ] Create regions with each preset in Video → Speed and confirm the before/after duration.
- [ ] Move/resize speed regions in source and compressed timelines, including beside cuts; check bounds and non-overlap.
- [ ] Click/right-click to edit/remove; verify Undo/Redo and reopening a real project.
- [ ] Listen to microphone, system audio, and music at speed boundaries and after seeking; check webcam synchronization with real media.
- [ ] Compare preview and export with captions, area zoom, blur, and trims. High-rate native preview can drop video frames.
- [ ] Ask either provider to add, update, and remove a region, then Undo.

Changes remain local and have not been pushed or published.


## Screen-only speed correction

The user clarified that webcam content must remain at normal speed. Preview uses the shortened output clock to locate normal-speed webcam/microphone/music source positions, including trim and kept cuts; exports preserve those tracks while scaling the screen, system audio and click audio. Normal-speed tracks finish with the shortened screen output. Microphone captions and sidecars use the narration clock. Agent frame previews use the same webcam timestamp as native preview.

- Webcam export frame regression failed in both normal and parallel modes before separating export track timing (`/tmp/appshow-webcam-export-red.log`).
- Ten gated export tests pass with the correction (`/tmp/appshow-webcam-export.log`), including the webcam frame regression and existing six-preset, cut/effect, SDR/HDR checks.
- A further gated microphone/music regression passes: audio before source 0.75 seconds remains silent even when the screen is at 2× (`/tmp/appshow-webcam-audio.log`).
- Preview rate/seek, project persistence and Undo tests pass (`/tmp/appshow-webcam-editor.log`).

Manual: compare a real talking-head recording at 1× webcam against a 2×/32× screen, including seeks, trimmed starts, and cuts. Check narration captions and note that remaining webcam footage is preserved in the source project after the shortened export ends.

The first full-suite run stalled in the unchanged `AgentReadinessTests.probeReportsUnhealthyWhenVersionCommandTimesOut` test and was interrupted. A test-host stack sample identified `AgentProbe.run` waiting for its timeout subprocess (`/tmp/appshow-webcam-test-stall.txt`). The retry passed that test.

Full-suite retry: 770 tests in 89 suites passed (`/tmp/appshow-webcam-full-retry.log`). Formatting, lint, project validation, and whitespace checks are clean.

The final Debug build is warning-free (`/tmp/appshow-webcam-build.log`), strict code-signature verification passes, and AppShow was gracefully restarted with the corrected build.
