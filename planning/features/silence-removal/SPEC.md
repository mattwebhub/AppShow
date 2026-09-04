# Feature: Silence removal

Status: agreed (owner assumptions recorded)
Milestone: 07

## Problem

A narrated recording is full of pauses: thinking time, tab switches, waiting for a build. Cutting them by hand means scrubbing the whole recording and pressing the cut button dozens of times. The user wants the app to find the silent stretches and turn them into cuts on the existing Cuts track, so the result plays, exports, and undoes exactly like hand-made cuts.

## Behavior

1. A "Silences" section in the Video tab of the properties panel offers a source picker (Microphone, System, Both), a threshold slider in dB relative to the track's loudest window (default −40 dB), a minimum silence length (default 0.7 s), and padding kept around speech (default 0.15 s). Only sources present in the recording are offered; the section is disabled when the recording has no audio.
2. Pressing Preview analyses the chosen source off the main actor over decoded PCM and shows a line such as "3 silences, 4.2 s removed" without changing the timeline. Changing any setting clears the preview.
3. A stretch counts as silent when every analysis window inside it has an RMS below `peak × 10^(threshold / 20)`, where `peak` is the loudest window of the same source. Silences shorter than the minimum length are ignored. With Both selected, a window is silent only when both sources are silent (the louder of the two RMS values is used).
4. Each detected silence is shrunk by the padding on the side that touches speech (a silence touching the start or end of the recording keeps that edge) and the complement becomes keep-slices. Kept slices shorter than `CutTimeline.minSliceLength` are dropped, which merges the silences around them.
5. Apply intersects the new keep-slices with the current cuts: content already cut stays cut, entry and exit transitions of a slice survive on its first and last surviving piece, and the result is written to `videoRegions` so the Cuts track appears or updates as it does for a manual cut.
6. Apply pushes exactly one history entry labelled "Silences removed"; one undo restores the previous slices, and the debounced snapshot the observation loop would otherwise add is suppressed.
7. Apply is disabled when the preview found no silence or when removing them would leave no slice at all.

## Not doing

- Protecting silences that contain a click or a transcript word (the agent skill in feature 04 layers that on top).
- Persisting the detector settings in the project.
- Analysing music tracks (feature 02) or the click-sound track.
- Removing silences from the audio tracks independently of the video.

## Touch points

Ours, new: `Reframed/Editor/SilenceDetector.swift` (pure), `Reframed/Editor/SilenceAnalysis.swift` (PCM decode), `Reframed/Editor/EditorState+SilenceRemoval.swift`, `Reframed/Editor/PropertiesPanel+SilencesSection.swift`.

Upstream, minimal edits: `Reframed/Editor/History.swift` (`HistoryEntry.label`, `pushSnapshot(_:label:)`), `Reframed/Editor/HistoryPopover.swift` (prefers the label), `Reframed/Editor/PropertiesPanel.swift` (one section in the Video tab), `Reframed.xcodeproj/project.pbxproj` (four file entries). `CutTimeline`, `EditorState+VideoRegions.swift`, and the Cuts track are reused unchanged.

## Owner assumptions in force

- Analysis runs off the main actor on decoded PCM; the file is read in chunks, never loaded whole.
- Spans shorter than the minimum are ignored before padding is applied.
- Existing cuts are intersected, never re-added: silence removal cannot bring back content the user already cut.
- The threshold is relative to the track's own peak, so a quiet recording and a loud one behave the same.
- Settings live in the panel for the session only.
