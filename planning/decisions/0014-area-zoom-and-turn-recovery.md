# ADR 0014: source-area zoom and interrupted-turn recovery

Status: accepted
Date: 2026-09-08

## Decision

Area zoom uses normalized top-left source-frame coordinates and source-time start/end values. The source aspect ratio is preserved by fitting the selected rectangle into a uniform normalized crop, capped at 8×. Keyframes carry an optional `targetRect`; absence retains the previous cursor-follow behavior. The same timeline resolver supplies native preview, agent preview, and SDR/HDR export. An area target overrides cursor following only for its own keyframes. Area zooms reject overlap rather than silently losing an edit.

The existing `add_zoom` tool gains `mode=area`, `rect`, `end`, and `transition`. Legacy calls retain their existing shape. Existing `add_blur`, `update_blur`, and `remove_blur` remain the agent interface for timed source-area blur. A shared visual source-frame picker avoids mixing canvas, webcam, crop, or padding coordinates into either effect.

Microphone removal uses the existing persisted mute state: the track disappears and is silent in playback/export, while source media and regions remain available through Undo or the Audio panel.

A provider stream ending without a terminal turn event is interrupted, not completed. Conversation checkpoints retain partial output and provider resume IDs. Reopening an interrupted message marks it failed and settles unfinished tool rows with an unknown-outcome explanation. Explicit recovery resumes the provider conversation; a fresh-session option retains local history when the remote session is unusable. Both paths ask the assistant to inspect current editor state before continuing because completed edits cannot safely be replayed blindly.

## Consequences

Old projects remain readable without migration. Recovery does not automatically resend tool calls or reset the project. Real-provider recovery and pointer interactions still require manual verification in addition to fixture-based tests.
