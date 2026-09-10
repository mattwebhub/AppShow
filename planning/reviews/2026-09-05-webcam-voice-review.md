# Webcam and voice implementation review

The feature follows the existing camera-region timeline, recording coordinator, local audio processing, editor persistence and MCP dispatcher boundaries. It adds no capture session, remote transcription service, separate cut timeline or renderer-specific layout model. Larger touched preview/caption views were split and existing controls/styles reused.

Findings patched with regressions:

- Silence analysis could apply stale cuts, lose an immediately preceding edit on Undo, or mutate during export. It now validates its source slices and uses the manual-cut commit path.
- Averaging opposite-phase stereo channels classified audible content as silence. Analysis now preserves the loudest channel and aligns tracks to video source time before combining them.
- Transcription used mutable source settings after suspension and an unsafe shared progress variable. Requests capture source timing and use generation identity; callbacks are synchronized, and stale/canceled results cannot commit.
- Slow failures could restore a snapshot over newer user edits. Staged handlers declare that they mutate only on success; active batch identity prevents late commits after rollback.
- Model download errors left the UI in a downloading state. Isolated injected-downloader tests now cover cleanup and retry.
- MCP previews had a separate camera configuration path that omitted split metadata. It now carries the same presentation type as export; preview-layer and SDR/HDR pixel tests verify split geometry and proportional corner radius.
- Caption text was the only narration store. Separate per-track transcripts now survive caption edits and reopening; project summaries and rendered frames expose that source-time context.

Validation is recorded in ../milestones/11-webcam-voice/VERIFY.md. This is a focused review of the changed paths; real-device and live-provider behavior remains in the manual checklist.
