# Webcam presentation verification

Automated tests use generated recording fixtures, isolated ConfigService files, and offscreen preview/render surfaces. They never access a real camera or request permissions.

- WebcamPresentationTests: persistent defaults, four corners on landscape/portrait/wide canvases, square circle geometry, capture preferences carried through project creation, legacy style preservation, saved edit precedence, immediate Undo, region CRUD/persistence and invalid/missing-camera rejection.
- WebcamRenderingTests: circle/partial/fullscreen HDR and SDR pixels, plus matching native preview frame and radius at transition progress 0, 0.5 and 1.
- RegionRemappingTests: source-time animation progress survives a cut without an extra collapse/expansion.
- ExportPipelineTests: actual SDR and HDR video exports containing webcam focus and a removed middle slice; output duration, video track and frame decoding checked.
- Existing mutation, project, bridge, history and rendering suites cover shared paths.

Red runs exposed missing feature APIs, camera Undo failing to clear the last region, HDR transition/fit mismatch, SDR ignoring fullscreen Fill for Original aspect, and animation restarts at cut boundaries. Each behavioral failure was patched before green verification.

Human checks remain in the milestone VERIFY.md.
