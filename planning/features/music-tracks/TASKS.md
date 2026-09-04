# Tasks: Music tracks

Phases from the attack plan; each starts red.

- [ ] P0 Pins and fixtures (S): remaining `AudioMixTests` rows, mp3 fixture with provenance.
- [ ] P1 Model and persistence (S): `ExternalAudioTrackData`, `EditorStateData` field, `ExternalAudioTrackMath`, `EditorState` storage, snapshot/restore/observe, history rules.
- [ ] P2 Import into the bundle (M): `ExternalAudioImporter`, `EditorState+ExternalAudio` add/remove, missing-file drop on open.
- [ ] P3 Waveform (S): streaming downsampler, keyed store with sidecar cache.
- [ ] P4 Timeline track and region editing (M): `TimelineView+ExternalAudioTrack`, drag/trim, sidebar rows, height signature.
- [ ] P5 Properties (S): music section in the Audio tab, effective volume, fade gains, Audio tab enabled without captured audio.
- [ ] P6 Preview playback (L): `ExternalAudioSchedule`, `ExternalAudioPreviewEngine`, controller lifecycle hooks, resync policy.
- [ ] P7 Export mixing (M): `VideoCompositor+ExternalAudio`, trackID-keyed mix parameters, `checkNeedsCompositor`, gated pipeline test.
- [ ] P8 Cuts and trims interplay (S): remap under segments, fade survival, muted omission, gap restart.
