# Feature: Image overlays

Status: in progress
Milestone: 07

## Problem

Title cards need a logo next to them, a walkthrough wants a screenshot of the finished result pinned in a corner, and a collage-style recording puts a second panel over the screen for a few seconds. Text overlays (T5) give the editor a timeline region that renders identically in the preview and in the export; the same primitive with a picture instead of a pill is what the agent tool `add_image` will drive later. The image file has to live inside the `.frm` bundle so a project stays self-contained when it is moved or reopened.

## Behavior

1. An image overlay is a timeline region with `startSeconds`/`endSeconds`, a `filename` inside the bundle, the original `sourceName` for display, the image `aspectRatio` (width over height, captured at import so layout stays pure), a `width` as a fraction of the canvas width (aspect preserved), a position preset plus a normalized offset reusing `TextOverlayPosition`, a `cornerRadius` as a fraction of the shorter side (0 to 0.5), an `opacity`, a `shadow` strength on the same 0 to 100 scale as the camera shadow, and entry/exit transitions with durations reusing `RegionTransitionType`.
2. Importing copies the file into the bundle as `image-<hash8>.<ext>` where `hash8` is the first eight hex digits of the SHA-256 of the file bytes (CryptoKit) and `ext` is the lower-cased source extension. Supported: png, jpeg/jpg, heic, tiff/tif, and gif (first frame). The same bytes imported twice map to the same file, so nothing is copied again. A file whose extension is unsupported or whose contents `ImageIO` cannot decode is rejected before anything is written. The importer also reports the pixel size so the overlay can record its aspect ratio. `ExternalAudioImporter` on the `milestone-03-music-tracks` branch uses the same hash naming for audio; once the branches merge the two importers should share one hashing and copying helper.
3. Layout is a pure function of the overlay and the canvas size: the pixel width is `width × canvasWidth`, the height follows the aspect ratio, and the size is scaled down when it would exceed the canvas. The rectangle is then anchored by the preset at the same 5 % margin as text pills, moved by `offsetX × canvasWidth` and `offsetY × canvasHeight`, and clamped inside the canvas (`TextOverlayLayout.anchoredRect`, shared with text pills). The pixel corner radius is `cornerRadius × min(width, height)`.
4. Rendering happens after text overlays and before captions in both the SDR and the HDR path: the image is clipped to the rounded rectangle, drawn at the overlay opacity, and when `shadow > 0` a black drop shadow with the camera shadow blur follows the image's own alpha through a transparency layer. Entry and exit transitions reuse the overlay transition helper: fade multiplies opacity, scale grows about the centre, slide moves in from and out to the bottom edge. At progress 0 nothing is drawn. The decoded `CGImage` is loaded once per export by the instruction builder (off the main actor), one decode per distinct file.
5. Multiple overlays may overlap in time and with text overlays; they draw in array order. Move and resize clamp to `[0, duration]` and a minimum length of 0.05 s.
6. "Add Image" (Overlays section, Effects tab) opens an `NSOpenPanel` limited to the supported image types and adds an overlay of 3 s at the playhead, pulled back when it would run past the end and clamped to the duration. Defaults: width 0.3, centre preset, zero offset, corner radius 0, opacity 1, no shadow, fade in and out of 0.3 s.
7. Text and image overlays share the one Overlays track. Chips carry the `textformat` or `photo` icon and the text or the source file name; dragging moves, dragging an edge resizes, right-click opens `TextOverlayEditPopover` or `ImageOverlayEditPopover` (thumbnail and file name, width, corner radius, opacity, shadow, position, offset, transitions, remove). The track appears when at least one overlay of either kind exists.
8. Export follows trims and cuts like text overlays: clipped and shifted on the trim path, split per kept segment with fresh ids under cuts, dropped when entirely inside removed content. An export with at least one image overlay always runs through the compositor.
9. The live preview mirrors the export with a `CALayer` per active overlay whose `contents` is the decoded image (cached per file name inside the preview container), positioned from the same layout maths inside the canvas rectangle, with the same transitions.
10. Overlays persist in `project.json` as `editorState.imageOverlays`; a file without the key opens with none, and every field but `startSeconds`, `endSeconds` and `filename` decodes with its default when missing. Snapshots carry them, so undo and redo restore them, and the history describes changes as "Image overlay added", "Image overlay removed" or "Image overlay adjusted". Removing an overlay keeps its file so undo can restore it. When a project opens and an overlay's file is missing from the bundle, that overlay is dropped and a warning is logged.

## Not doing

- Cropping, rotation, borders, animation beyond the region transitions.
- Dragging or resizing the image in the preview.
- Garbage-collecting image files that no overlay references any more.
- Blur regions (milestone 07 T7) and the agent tool wrappers (`add_image`, milestone 06).

## Touch points

Ours, new: `AppShow/Project/ImageOverlayData.swift`, `AppShow/Project/ImageOverlayImporter.swift`, `AppShow/Editor/EditorState+ImageOverlays.swift`, `AppShow/Compositor/ImageOverlayLayout.swift`, `AppShow/Compositor/FrameRenderer+ImageOverlays.swift`, `AppShow/Editor/VideoPreviewContainer+ImageOverlays.swift`, `AppShow/Editor/TimelineView+OverlayChip.swift`, `AppShow/Editor/ImageOverlayEditPopover.swift`, `AppShow/UI/OverlayPositionControls.swift`.

Ours, extended: `TextOverlayData.swift` (`OverlayRegion` protocol), `TextOverlayLayout.swift` (`anchoredRect`), `FrameRenderer+TextOverlays.swift` (`applyOverlayTransition` with opacity), `EditorState+TextOverlays.swift` (`showOverlayTrack`), `TimelineView+OverlayTrack.swift` (chips of both kinds), `TextOverlayEditPopover+Style.swift` (shared position controls), `PropertiesPanel+OverlaysSection.swift` (Add Image, image rows).

Upstream, minimal edits (merge risk, listed in `planning/upstream-sync.md`): `AppShow/Project/ProjectMetadata.swift` (`EditorStateData.imageOverlays`), `AppShow/Editor/EditorState.swift` (storage and load), `EditorState+Persistence.swift` (snapshot, restore, observe), `EditorState+Export.swift` (pass through), `History+ChangeRules.swift` (one `regions` rule), `Compositor/ExportConfiguration.swift`, `CompositionInstruction.swift` (`imageOverlays`), `VideoCompositor+InstructionBuilder.swift` (`checkNeedsCompositor`, image loading, one parameter), `VideoCompositor+RegionRemapping.swift` (one field, generic overlay remap), `FrameRenderer.swift` and `FrameRenderer+HDR.swift` (one call after text overlays), `VideoPreviewView.swift`, `VideoPreviewView+Update.swift`, `VideoPreviewContainer.swift`, `EditorView+Preview.swift` (preview mirror), `AppShow.xcodeproj/project.pbxproj` (file entries `7E57000000000000000000A2`–`AF`, `D0`… if needed).

## Coordinate note

As for text overlays, layout rectangles are in Core Graphics coordinates (origin bottom-left) for the canvas they were resolved on; the export bitmap context and the preview container's layers share that origin.
