# Webcam layouts, voice and silence cuts

Webcam sections offer fullscreen, hidden, custom PiP, left/right half and left/right third. Lateral layouts reserve the selected fraction of the canvas for a rectangular, aspect-filled webcam and fit the complete screen recording into the remaining portion. Scale/slide interpolate from the default circular PiP and shrink the screen in sync. Entry/exit timing remains source-based across cuts. Existing projects retain existing modes.

Include webcam offers clearly labeled voice capture and automatic captions. Voice uses the existing synchronized microphone track, optional existing noise reduction and local WhisperKit word timestamps. Model downloads stay explicit. Missing models and transcription failures are actionable in the captions panel. Automatic generation applies to newly recorded projects, never silently regenerates an existing transcript on reopen.

Silence detection previews audio gaps; applying creates ordinary editable keep-slices in the Cuts track and updates playback/export without changing media. Existing cuts survive, one Undo restores the previous edit, and stale/canceled previews cannot overwrite newer edits. UI and MCP share the same application path.

MCP names retain the established verb_noun convention and compatibility: set_camera; add/update/remove_camera_region; get_transcript; generate_captions; set_captions; get_silences; remove_silences. New webcam layouts are enum values of camera-region tools, not duplicate per-layout tools. Catalog titles identify the corresponding editor area.

## Spoken context for the assistant

Recorded audio transcripts persist separately from editable captions, with source, language, model and source-time word timestamps. Clearing or rewriting captions does not erase narration. Each recorded track has its own transcript. New webcam voice recordings generate this context even when visible captions are off; model acquisition remains explicit.

`get_transcript` prefers microphone narration, then system narration, then legacy captions. Its optional source selector can request microphone, system or edited captions. `generate_transcript` creates context without enabling or replacing captions. `get_project_summary` includes availability and a bounded narration excerpt; `render_preview_frame` includes narration within five seconds of the requested source frame and identifies whether that frame is kept. No transcript means an explicit generation hint, never invented context.
