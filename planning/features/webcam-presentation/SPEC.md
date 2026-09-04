# Webcam presentation

Before recording, an “Include webcam” control enables the selected camera. Options and app settings expose four corner presets and size. New recordings use a circular webcam at bottom right, 20% of canvas width, constrained to fit the canvas. Camera and screen remain separate source files.

Recording-time presentation preferences travel with the new project. Reopening an existing edit always restores its saved settings; old projects retain their prior defaults. A circle uses the existing square aspect and 50% radius, preserving compositor and project compatibility.

The editor offers “Focus webcam” to create a timed fullscreen camera region. Entry and exit default to the existing animated scale transition (0.4 seconds). Outside the region the camera returns to its normal bubble. Regions can be repeated, moved, resized, edited numerically, and deleted. Existing hidden/custom regions remain supported.

MCP exposes add_camera_region, update_camera_region, and remove_camera_region with source-time bounds, stable IDs, type, and entry/exit transitions. set_camera gains circle and corner presets. Timeline inspection includes presentation settings and transitions. Every mutation uses existing validation, snapshots, batches and Undo. Missing webcam media, overlapping regions and invalid ranges produce errors without partial edits.
