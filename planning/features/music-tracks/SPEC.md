# Feature: Music tracks

Status: agreed (owner assumptions recorded)
Milestone: 03

## Problem

A screen recording with only system audio and a microphone sounds bare. Users want to add a music bed or sound effects from their own audio files, place them on the timeline, trim and fade them, hear them in the preview, and have them mixed into the export, without leaving the app.

## Behavior

1. In the editor the user adds an audio file (mp3, m4a, aac, wav, aiff, caf, flac) through an Add button in the Audio properties tab or by dropping onto the timeline. The file is copied into the `.frm` bundle as `audio-<hash>.<ext>`; importing the same bytes twice reuses the copy.
2. Each track appears as its own timeline row labelled "Audio" (icon `music.note`) below Mic, with a region chip showing the file's waveform for the used portion and the display name when wide enough.
3. The region can be moved (timeline start), and its edges trimmed (which shift `fileIn`/`fileOut` so audio stays anchored). Tracks are clamped to the recording length. Import places the track at the playhead.
4. Properties per track: volume, mute, fade in, fade out (linear, clamped to half the track length). Changes are undoable with readable history labels.
5. Preview playback plays the track in sync with the screen video through the audio engine, following seeks, play/pause, gap skips from cuts, and the fade gains.
6. Export mixes every unmuted track into the output at its timeline position, clipped to trims and cuts, with fades as volume ramps; the compositor path is forced whenever tracks exist.
7. Persistence: tracks survive save and reopen; a project referencing a missing file drops that track with a logged warning; pre-feature projects open unchanged.
8. The Audio tab is enabled for recordings with no captured audio so music can still be added.

## Not doing

- Auto-ducking under the microphone, looping short files, equal-power fades, lane packing, cleanup of orphaned media, size warnings (v1 documents the 200 MB guidance only).

## Touch points

Per `docs/features/02-music-tracks/ATTACK-PLAN.md`: new `Reframed/Project/ExternalAudioTrackData.swift`, `ExternalAudioImporter.swift`, `Reframed/Editor/ExternalAudioTrackMath.swift`, `ExternalAudioSchedule.swift`, `ExternalAudioPreviewEngine.swift`, `ExternalAudioWaveformStore.swift`, `AudioWaveformDownsampler.swift`, `TimelineView+ExternalAudioTrack.swift`, `PropertiesPanel+MusicSection.swift`, `EditorState+ExternalAudio.swift`, `Reframed/Compositor/VideoCompositor+ExternalAudio.swift`, `ExternalAudioExportTrack.swift`. Upstream edits: `ProjectMetadata.swift` (one field), `EditorState.swift`, `EditorState+Persistence.swift`, `History+ChangeRules.swift`, `SyncedPlayerController.swift` lifecycle hooks, `VideoCompositor.swift`, `VideoCompositor+InstructionBuilder.swift`, `ExportConfiguration.swift`, `TimelineView.swift`, `EditorView.swift`, `EditorView+Sidebar.swift`, `PropertiesPanel+AudioTab.swift`.

## Owner assumptions in force

From `docs/features/00-overall-plan.md` questions 6–13: one row per file, clamped to the recording, placed at the playhead, linear fades, no ducking, no looping, Audio tab enabled without captured audio, orphaned media kept.
