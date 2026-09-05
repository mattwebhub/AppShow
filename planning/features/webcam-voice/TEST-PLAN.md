# Verification

## Automated

- WebcamSplitTests: left/right half/third fractions, source aspect preservation, persistence, interpolated screen geometry, source-clock remapping and scaled screen corners.
- WebcamRenderingTests: actual preview layers and SDR/HDR pixels at entry, settled state and exit for all four split presentations.
- WebcamPresentationTests: camera-region MCP CRUD, saved sections and MCP preview configuration.
- CaptionGenerationTests: isolated recording preferences, failed model download retry state, processed voice selection, one-step Undo, canceled/stale generation and one-shot recording setup.
- WebcamVoiceToolTests: stable catalog names and area titles, caption MCP one-step Undo and preservation of concurrent edits on analysis failure.
- EditorStateSilenceRemovalTests: editable keep-slices, stale preview rejection, export exclusion, immediate Undo and no delayed duplicate history entry.
- SilenceAnalysisTests: generated audio, stereo phase preservation, both-track protection and audio drift alignment.
- ExportPipelineTests: real encoded SDR/HDR videos with fullscreen, left-half and right-third webcam regions spanning cuts.

## Manual

- Enable Include webcam, verify selected microphone and Capture voice/Reduce background noise/Generate captions options before recording. Check microphone permission handling and unplugging a device.
- Record speech and pauses. Confirm the separate voice track plays cleanly, captions stay in sync, and original media is retained. If no model is installed, follow the Captions panel's explicit download action; check cancellation and retry.
- Add each left/right half/third section. Scrub/play entry and exit, resize/move its source and compressed timeline range, and reopen the project.
- Preview silence cuts in Video, choose Create cuts, select/move/delete resulting slices, and Undo. Compare playback, captions and exported audio/video around the gaps.
- Ask each live provider to add a right-third webcam section, generate captions, preview silences and apply cuts. Verify its preview frame agrees with the editor.

SpokenContextTests verifies transcript-only generation, caption preservation, independent narration after clearing captions and reopening, exact source selection, project overview and the actual rendered-frame tool's nearby speech payload.
