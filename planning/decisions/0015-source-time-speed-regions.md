# ADR 0015: source-time speed regions

Status: accepted
Date: 2026-09-08

## Decision

Persist optional `SpeedRegionData` values with a UUID, source start/end, and one of six rates: 1.5, 2, 4, 8, 16, or 32. Regions cannot overlap, must fit the recording, and must be at least 50 ms long before cut/trim intersections. Missing data preserves normal playback for older projects.

`SpeedTimeline` partitions kept source ranges at speed boundaries and maps source time to output time and back. Editing continues in source seconds. Timeline compression, transport timing, and exported subtitle timestamps use this mapping. Speed edits share the editor's history and agent transactions; `add_speed`, `update_speed`, and `remove_speed` expose the same primitives.

Export first builds the existing cut/trim composition and remaps effects into that composition's clock. It then scales the screen and system/click audio tracks, applying speed ranges in reverse order. Webcam, microphone and imported music retain their cut/trim composition timing at 1× and end with the shortened output. The frame renderer maps output timestamps back into the unscaled composition clock before evaluating effects. Imported-audio gain ramps retain normal timing. Microphone captions use output time; system-audio captions use screen effect time. SDR, HDR, manual, parallel, and GIF paths share the mapping. Video writers explicitly end their session at the computed output duration so time-stretched audio tails cannot extend the result.

Native preview advances only the screen player at the active rate. Webcam uses an independent normal-speed source mapping, shared by seeking and agent frame previews. Recorded and imported audio use AVAudioUnitTimePitch, which supports the full preset range; recorded audio keeps a separate varispeed unit for small recording-clock drift corrections. Seeks reschedule each audio stream from its own source position. Speed boundaries update system audio; normal-speed cut boundaries resynchronize webcam, microphone and music.

## Consequences

Source files are never rewritten. Timing metadata remains editable without cascading changes to other regions. High-rate native video preview may drop frames, while export samples the retimed composition at the configured frame rate. Pointer behavior and audible quality with real recordings remain manual checks.
