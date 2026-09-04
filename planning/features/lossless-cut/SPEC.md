# Feature: Lossless cut

Status: agreed (owner assumptions recorded)
Milestone: 02

## Problem

A recording contains dead time and detours. The user wants to keep only the good slices, see the result play as one continuous video, and export exactly that, without leaving the editor. Today the only way to make a gap is to drag a region edge on the Screen track, which nobody discovers.

## Behavior

1. A cut button (hand-with-pointing-finger icon) sits in the transport bar before the zoom-out button. Clicking it splits the slice under the playhead into two adjacent slices. The playhead does not move. The button is disabled when the playhead is in a gap or within 50 ms of a slice edge.
2. The first split reveals a Cuts track directly under Screen, animated in the same way the Zoom and Spotlight tracks appear. Each kept slice is a region with draggable edges and body; gaps are drawn dimmed. Removing a slice from its popover creates a gap. Removing the last cut animates the track out.
3. While the Cuts track is visible, the Screen track shows a plain non-interactive bar, so there is one editable copy of the slices.
4. Playback in the normal editor and in fullscreen preview plays only kept slices: from inside a slice the playhead jumps to the next slice at the slice end; from a gap, play starts at the next slice; after the last slice playback pauses. No frame of cut content is shown.
5. Export produces only the kept slices back to back; zoom, cursor, camera, spotlight, and caption timing follow the slices. A camera or spotlight region spanning a cut stays continuous in the model and is split per segment at export time.
6. Compressed timeline mode (toggle visible only when cuts exist) hides gaps from the ruler and all tracks; other tracks are read-only in that mode in v1.
7. A pre-feature project opens with no Cuts track; history entries read "Cut added", "Cut removed", "Cut adjusted"; undo restores the previous slices.

## Not doing

- Literal passthrough (no re-encode) export; every cut goes through the compositor. Optional later phase.
- Editing other tracks in compressed mode.
- Ripple-editing audio regions when slices move.

## Touch points

Upstream code, listed per phase in `docs/features/01-lossless-cut/ATTACK-PLAN.md`: `Reframed/Editor/EditorState.swift`, `EditorState+VideoRegions.swift`, `EditorState+Persistence.swift`, `EditorState+Playback.swift`, `History+ChangeRules.swift`, `SyncedPlayerController.swift`, `TimelineView.swift`, `TimelineView+ScreenTrack.swift`, `EditorView.swift`, `EditorView+TransportBar.swift`, `VideoPreviewView+Update.swift`, `EditorView+Preview.swift`, `EditorState+Export.swift`, `ExportConfiguration.swift`. New files: `Reframed/Editor/CutTimeline.swift`, `TimelineView+CutTrack.swift`, `TimelineGeometry.swift`.

## Owner assumptions in force

From `docs/features/00-overall-plan.md` questions 1–5: jumping applies to normal playback; Screen track becomes a plain bar; UX-only "lossless"; regions stay continuous across cuts; compressed mode read-only for other tracks.
