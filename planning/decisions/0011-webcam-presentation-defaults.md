# ADR 0011: recording defaults and webcam focus

Status: accepted, 2026-09-04.

Store corner and relative size in ConfigService and RecordingOptions. Snapshot them when capture begins, carry them in RecordingResult and optional ProjectMetadata.webcamPresentation, and seed editor layout only when no saved edit exists. Optional metadata keeps older projects compatible and avoids consulting mutable global preferences when reopening a project.

Represent circles with existing cameraAspect.ratio1x1 and cameraCornerRadius = 50. Focus uses existing fullscreen CameraRegionData and scale entry/exit transitions, keeping preview, SDR/HDR rendering, export remapping and Undo on the same model. Add typed MCP region operations rather than a separate presentation timeline.

Export region membership and animation timing are separate: optional RegionTransitionInfo.transitionTimeRange retains the original region clock after trimming/cut remapping. This transient field is not persisted. The renderer uses it to avoid replaying a focus transition at every retained segment. Native preview, SDR and HDR use shared rectangle interpolation; Original fullscreen aspect respects Fill in both export paths.
