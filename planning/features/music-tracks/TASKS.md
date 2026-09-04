# Tasks: Music tracks

Phases from the attack plan; each starts red.

- [x] P0 Pins and fixtures (S): remaining `AudioMixTests` rows, mp3 fixture with provenance.
- [x] P1 Model and persistence (S): `ExternalAudioTrackData`, `EditorStateData` field, `ExternalAudioTrackMath`, `EditorState` storage, snapshot/restore/observe, history rules.
- [x] P2 Import into the bundle (M): `ExternalAudioImporter`, `EditorState+ExternalAudio` add/remove, missing-file drop on open.
- [x] P3 Waveform (S): streaming downsampler, keyed store with sidecar cache.
- [x] P4 Timeline track and region editing (M): `TimelineView+ExternalAudioTrack`, drag/trim, sidebar rows, height signature.
- [x] P5 Properties (S): music section in the Audio tab, effective volume, fade gains, Audio tab enabled without captured audio.
- [x] P6 Preview playback (L): `ExternalAudioSchedule`, `ExternalAudioPreviewEngine`, controller lifecycle hooks, resync policy.
- [x] P7 Export mixing (M): `VideoCompositor+ExternalAudio`, trackID-keyed mix parameters, `checkNeedsCompositor`, gated pipeline test.
- [x] P8 Cuts and trims interplay (S): remap under segments, fade survival, muted omission, gap restart.

## Deviations recorded

- Fades under cuts are timeline-based (the preview engine's `gain(at:)` and the export ramps agree); the attack plan's phase 7 row asserting a ramp continuing across a cut was superseded by the phase 8 row.
- `segment(track:at:sampleRate:)` returns nil before the track starts; `upcomingSegment(track:at:sampleRate:)` carries the delayed form.
- Fade in/out use `SliderRow` (0–5 s); no stepper component exists.
- Gap-skip resync flows through `seek(to:)`; the screen player never changes rate so there is no rate hook.
- Import errors from the panel or drop are logged, not shown inline (follow-up).

## Manual checks for a human

1. Open a silent recording: the Audio tab is enabled; Add Audio File… (mp3/m4a/wav/aiff/caf/flac, multi-select) places a track at the playhead with an "Audio" row under Mic, waveform and name.
2. Drop an MP3 from Finder onto the timeline (dashed accent border while targeted).
3. Drag body and edges; right-click → popover with mute, volume, fades, Remove; history labels read "Audio track …".
4. Play from before, inside, and after a track; scrub across a fade; with two cuts in preview mode the music jumps with the video; over a long play the resync log stays quiet.
5. Export MP4 (parallel and normal) and ProRes MOV: music level, position, and fades match the preview; GIF unaffected.
6. Reopen the project: tracks, waveforms, settings intact; a muted track shows at half opacity and is omitted from export.
