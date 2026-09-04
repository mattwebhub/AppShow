# Feature: Text overlays

Status: done (manual rows pending in `planning/milestones/07-primitives/VERIFY.md`)
Milestone: 07

## Problem

A recording becomes a presentation only when it can carry title cards and callouts: "Step 1: open Settings", a chapter title over the first seconds, a note pointing at a dialog. Today the only text the editor can burn in is the transcript captions. The user wants free text that lives on the timeline as a region, looks the same in the preview and in the export, and undoes like every other edit. The same primitive is what the agent tool `add_text` will drive later.

## Behavior

1. A text overlay is a timeline region with `startSeconds`/`endSeconds`, a `text` (single- or multi-line), a font size relative to the canvas height, a weight (`CaptionFontWeight`), a text colour, an optional background pill (colour, opacity, corner radius as a fraction of the pill height), a position preset (top-left, top, top-right, center, bottom-left, bottom, bottom-right) plus a normalized offset (fractions of the canvas width and height, positive down), and entry/exit transitions with durations reusing `RegionTransitionType`.
2. Layout is a pure function of the overlay and the canvas size. The font pixel size is `fontSize × canvasHeight` (at least 8 px). The pill pads the text by 0.5 × font size horizontally and 0.25 × font size vertically. Text wraps so the pill is at most 80 % of the canvas width. A preset anchors the pill at a margin of 5 % of the canvas height from the touching edges, or at the canvas centre. The offset then moves the pill by `offsetX × canvasWidth` and `offsetY × canvasHeight`, and the result is clamped inside the canvas.
3. Rendering happens after the screen, spotlight and webcam stages and before captions, in both the SDR and the HDR path: the pill is a rounded rectangle filled with the background colour at the background opacity, the text is drawn with Core Text centred line by line. The entry and exit transitions use the existing region transition helpers: fade multiplies opacity, scale grows about the pill centre, slide moves the pill in from and out to the bottom edge. At progress 0 nothing is drawn.
4. Multiple overlays may overlap in time; they draw in array order. Move and resize only clamp to `[0, duration]` and a minimum length of 0.05 s.
5. "Add Text" (Overlays section, Effects tab) or a double-click on empty space of the Overlays track adds an overlay of 3 s at the given time, pulled back when it would run past the end and clamped to the duration. Defaults: text "Title", font size 0.06, bold, white text, black pill at 60 % with corner radius 0.25, centre preset, zero offset, fade in and out of 0.3 s.
6. The Overlays track (label "Overlays", icon `textformat`) appears when at least one overlay exists, like the Spotlight track. A chip shows the `textformat` icon and the text truncated to the chip width; dragging moves it, dragging an edge resizes it, right-click opens `TextOverlayEditPopover` (text, font size, weight, text colour, background toggle, colour, opacity, corner radius, position, offset, transitions, remove). The track positions through the timeline geometry pair and is read-only in the compressed display mode like the other tracks.
7. Export follows trims and cuts like spotlight regions: on the trim path an overlay is clipped to the trim and shifted; under cuts it is split per kept segment with fresh ids, and an overlay entirely inside removed content is dropped. An export with at least one overlay always runs through the compositor.
8. The live preview mirrors the export with Core Animation text layers positioned from the same layout maths inside the canvas rectangle, at the playhead's source time, with the same transitions.
9. Overlays persist in `project.json` as `editorState.textOverlays`; a file without the key opens with none, and every field but `startSeconds`/`endSeconds` decodes with its default when missing. Snapshots carry them, so undo and redo restore them, and the history describes changes as "Text overlay added", "Text overlay removed" or "Text overlay adjusted".

## Not doing

- Per-word timing, rich text, custom fonts, rotation, shadows.
- Dragging the overlay in the preview (position comes from the preset and offset sliders).
- Image overlays and blur regions (milestone 07 T6 and T7).
- Agent tool wrappers (`add_text`, milestone 06).

## Touch points

Ours, new: `AppShow/Project/TextOverlayData.swift`, `AppShow/Editor/EditorState+TextOverlays.swift`, `AppShow/Compositor/TextOverlayLayout.swift`, `AppShow/Compositor/FrameRenderer+TextOverlays.swift`, `AppShow/Editor/VideoPreviewContainer+TextOverlays.swift`, `AppShow/Editor/TimelineView+OverlayTrack.swift`, `AppShow/Editor/TextOverlayEditPopover.swift`, `AppShow/Editor/TextOverlayEditPopover+Style.swift`, `AppShow/Editor/PropertiesPanel+OverlaysSection.swift`.

Upstream, minimal edits (merge risk, listed in `planning/upstream-sync.md`): `AppShow/Project/ProjectMetadata.swift` (`EditorStateData.textOverlays`), `AppShow/Editor/EditorState.swift` (storage and load), `EditorState+Persistence.swift` (snapshot, restore, observe), `EditorState+Export.swift` (pass through), `History+ChangeRules.swift` (one `regions` rule), `Compositor/ExportConfiguration.swift`, `CompositionInstruction.swift` (`textOverlays`), `VideoCompositor+InstructionBuilder.swift` (`checkNeedsCompositor`, one parameter), `VideoCompositor+RegionRemapping.swift` (one field and one function), `FrameRenderer.swift` and `FrameRenderer+HDR.swift` (one call before captions), `VideoPreviewView.swift`, `VideoPreviewView+Update.swift`, `VideoPreviewContainer.swift`, `EditorView+Preview.swift` (preview mirror), `TimelineView.swift`, `EditorView.swift` (track gating), `PropertiesPanel.swift` (one section), `AppShow.xcodeproj/project.pbxproj` (file entries `7E5700000000000000000090`–`A1`).

## Coordinate note

Layout rectangles are in Core Graphics coordinates (origin bottom-left) for the canvas they were resolved on. The export renders into a bitmap context with that origin and the preview container's layers use AppKit's unflipped layer geometry, so the same rectangle serves both.
