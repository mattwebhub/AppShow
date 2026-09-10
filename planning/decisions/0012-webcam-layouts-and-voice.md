# 0012. Webcam split layouts and voice workflows

Status: accepted
Date: 2026-09-05

## Decision

Extend the existing camera-region type with named left/right half/third presentations. A shared pure geometry seam computes screen and camera rectangles; preview and both export renderers consume it. Composition region metadata carries the presentation through source-to-composition remapping without changing its animation clock.

Keep the existing synchronized microphone recorder, RNNoise cleanup and offline WhisperKit transcription. Toone's desktop speech implementation uses SFSpeechRecognizer for live dictation; that is not a replacement for AppShow's timed offline caption pipeline. No Toone code is copied and no additional speech permission or network transcription service is introduced.

Silence removal uses the same keep-slice commit seam as manual cuts. Previews carry their source edit so delayed results cannot overwrite newer cuts. Existing MCP verb_noun names remain stable; related operations share editor-area catalog titles and camera variants share one typed CRUD family.

## Consequences

Legacy project defaults remain compatible; new camera type values require a current AppShow reader. Voice capture preferences must be visible before recording; caption generation remains independently cancellable. Model acquisition is explicit and missing models produce guidance. Raw media remains the source of truth.

Slow handlers that stage their work without changing persistent editor state declare `mutatesOnlyOnSuccess`. The dispatcher does not restore a stale pre-analysis snapshot if those handlers fail; this preserves concurrent user edits. The handler validates cancellation and its target immediately before its synchronous commit. Existing multi-step handlers retain snapshot rollback. Caption generation and silence application share the existing history/batch rules.

Silence levels use the loudest channel to avoid stereo phase cancellation. Audio windows are aligned to the video source clock using the same drift ratios as playback and captions before combining tracks.

Mutation batches have an ephemeral identity. Long transcription and silence work captures that identity and refuses a late commit if the batch ends, expires or is replaced during analysis. This prevents canceled grouped edits from reappearing after rollback.
