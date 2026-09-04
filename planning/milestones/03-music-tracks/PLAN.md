# Milestone 03: music-tracks

Goal: a user can add audio files to a project, position and trim them on their own timeline rows, set volume and fades, hear them in sync in the preview, and get them mixed into the export; projects survive save and reopen.

Depends on: milestone 01 (fixtures, `AudioMixTests`), milestone 02 (`CutTimeline`, `VideoSegment` remap) for phase 8.

## Tasks

Mirror of `planning/features/music-tracks/TASKS.md`.

- [ ] T1. P0 pins and fixtures. Proof: `AudioMixTests`, `AudioFixturesTests` green.
- [ ] T2. P1 model and persistence. Proof: `ExternalAudioTrackDataTests`, `ExternalAudioTrackMathTests`, history rule tests.
- [ ] T3. P2 import. Proof: `ExternalAudioImporterTests`, `EditorStateExternalAudioTests`.
- [ ] T4. P3 waveform. Proof: downsampler and store tests.
- [ ] T5. P4 timeline track. Proof: manual drag check plus math tests.
- [ ] T6. P5 properties. Proof: `ExternalAudioScheduleTests` fade rows, effective volume.
- [ ] T7. P6 preview playback. Proof: schedule tests; gated engine test; manual sync check.
- [ ] T8. P7 export mixing. Proof: `ExternalAudioRemapTests`, `AudioMixTests` external rows, gated `ExportPipelineTests` music row.
- [ ] T9. P8 cuts and trims interplay. Proof: remaining remap and export-config tests.
- [ ] T10. Docs and divergences: `docs/editor.md`, `AGENTS.md`, `planning/upstream-sync.md`. Proof: grep.
- [ ] T11. VERIFY.md run, branch pushed, PR opened, URL recorded.

## Out of scope

Ducking, looping, equal-power fades, lane packing, orphan cleanup, fixing the upstream audio-mix pairing beyond keying our parameters by `trackID`.

## Risks

- Preview drift between `AVPlayer` and `AVAudioEngine` clocks: resync on play/seek/gap-skip and a periodic delta check; anchor to the player timebase later if audible.
- Large files decoded whole by the upstream waveform generator: never reuse it for music; stream per bucket.
