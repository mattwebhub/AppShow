# Spike: Lossless cut (keep-slices)

Status: spike, no code written. Working tree: upstream `v0.14.7` plus milestone-00 (`ad8f460`). Every path below was read for this spike; line numbers are from that tree.

## Goal

Let the user mark slices of the recording to keep, LosslessCut-style: a transport-bar button cuts at the playhead, the kept slices live on their own timeline track under "Screen" (appearing on the first cut, like the Zoom and Spotlight tracks), preview playback jumps from slice to slice, and export contains only the kept slices. Optional: a compressed-timeline mode that hides the cut-out parts.

## What exists today

The headline: **upstream's "video regions" are already keep-based slices with playback skipping, export compression, region remapping, persistence and undo.** `docs/editor.md:9` ("segments to cut out of the timeline") is wrong; the code keeps what is inside a region and drops what is outside.

| Capability | Type / function | File:line | Notes |
| --- | --- | --- | --- |
| Slice model | `VideoRegionData { id, startSeconds, endSeconds, entry/exitTransition(+Duration) }` | `Reframed/Project/ProjectMetadata.swift:144-152` | `Codable, Sendable, Identifiable, Equatable`; synthesized Codable, all extras optional |
| Slice storage | `EditorState.videoRegions: [VideoRegionData]` | `Reframed/Editor/EditorState.swift:19` | Sorted by start, non-overlapping by construction |
| Default = keep everything | `videoRegions = [VideoRegionData(startSeconds: 0, endSeconds: dur)]` | `EditorState.swift:254`, `EditorState+Persistence.swift:217` | One full-length region is the "no cuts" state |
| Keep semantics (derived) | `videoRegionsTotalDuration`, `hasVideoRegionCuts` (`abs(total - dur) > 0.01`) | `EditorState.swift:138-146` | "Cuts exist" means the kept total is shorter than the source |
| Compressed ⇄ source time | `previewElapsedTime`, `sourceTimeForPreviewElapsed(_:)` | `EditorState.swift:148-176` | Already the mapping a compressed timeline needs |
| Create a slice (UI) | double-click on the Screen track → `addVideoRegion(atTime:)` | `TimelineView+ScreenTrack.swift:22-25`, `EditorState+VideoRegions.swift:5-40` | Inserts a ≤10 s region into the *gap* around `time`; returns early if `time` is inside a region (`:6`). With the default full region a double-click does nothing; the only way to make a gap today is to drag a region edge |
| Resize / move / remove | `updateVideoRegionStart/End`, `moveVideoRegion`, `removeVideoRegion` | `EditorState+VideoRegions.swift:42-74` | Clamped to neighbours and `[0, duration]`; min length 0.01 s |
| Slice handles (UI) | `videoRegionView` drag: `.resizeLeft/.resizeRight/.move` from an 8 px edge threshold; `effectiveVideoRegion` for live preview; `commitVideoDrag` | `TimelineView+ScreenTrack.swift:93-120, 138-179` | Identical pattern to `spotlightRegionView` (`TimelineView+SpotlightTrack.swift:119-206`) and the camera track; `RegionDragType` in `ZoomRegion.swift:110` |
| Slice popover | `VideoRegionEditPopover(region:canRemove:onUpdateTransition:onRemove:)` | `Reframed/Editor/VideoRegionEditPopover.swift:3-68`, opened from `TimelineView+ScreenTrack.swift:62-92` | Entry/exit transition + Remove (only when `count > 1`) |
| Player skips gaps | `SyncedPlayerController.videoRegions`, `previewMode`, `handlePreviewGapSkip(at:)` | `SyncedPlayerController.swift:21-22, 183-185, 191-207` | Only when `previewMode`; from the 60 Hz periodic observer; seeks to `next.start`, pauses after the last slice. `boundaryObserver` (`:17`) is declared and never used |
| Player sync | `syncVideoRegionsToPlayer()` from the observation loop | `EditorState+AudioRegions.swift:108-110`, `EditorState+Persistence.swift:426-427` | `previewMode` mirrors `isPreviewMode` |
| Play from a gap | `togglePlayPause()` seeks to the next slice start (or the first) | `EditorState+Playback.swift:8-27` | Only when `isPreviewMode && hasVideoRegionCuts` |
| Preview hides gaps | `isScreenHidden = isPreviewMode && !videoRegions.isEmpty && videoRegion == nil` | `VideoPreviewView+Update.swift:113-141`, `VideoPreviewContainer+Layout.swift:66-68` | Edit mode still shows the cut-out frames |
| Transport time readout | elapsed `/ total` in preview; `(total)` suffix in edit mode; preview progress bar seeks through `sourceTimeForPreviewElapsed` | `EditorView+TransportBar.swift:17-38, 112-171` | |
| Export: segment build | `VideoCompositor.export` inserts each region ∩ trim back-to-back, records `VideoSegment(sourceRange:compositionStart:)`, `compositionDuration = Σ` | `Reframed/Compositor/VideoCompositor.swift:37-61` | `hasVideoRegions` forces the compositor path (`+InstructionBuilder.swift:39`), never passthrough |
| Export: config gate | `isSingleFullRange` → `videoRegions: nil`, `trimRange = 0…duration` when cuts exist | `Reframed/Editor/EditorState+Export.swift:100-121, 147-154` | |
| Export: webcam | webcam track inserted per segment | `VideoCompositor+InstructionBuilder.swift:95-101` | |
| Export: audio | `addAudioTracks` intersects audio regions with each segment | `VideoCompositor+Audio.swift:26-38`; caller `VideoCompositor.swift:171-181` | |
| Export: click sounds | clicks remapped per segment | `VideoCompositor+AudioPreprocessing.swift:47-56` | |
| Export: camera/spotlight/caption remap | `remapAllRegions` → `RemappedRegions`; `remapRegion` splits a region per segment; `remapCaptionSegments` clips words | `VideoCompositor+RegionRemapping.swift:20-63, 65-117, 255-318` | Pinned for the trim path in `ReframedTests/Compositor/RegionRemappingTests.swift`; the cut path has no test yet |
| Export: screen transitions | `remapVideoRegions` matches regions to segments within 0.01 s | `+RegionRemapping.swift:223-253`, consumed by `FrameRenderer.swift:116-124` | |
| Export: zoom + cursor | `CompositionInstruction.sourceTime(for:)` over `videoSegmentMappings`; `resolveZoomRect` uses it | `CompositionInstruction.swift:27-31, 283-292`, `FrameRenderer+Helpers.swift:79-92` | Zoom keyframes and cursor samples stay in source time |
| Persistence | `EditorStateData.videoRegions?` ; snapshot omits when empty; restore falls back to full region | `ProjectMetadata.swift:490`, `EditorState+Persistence.swift:122, 213-218`, `EditorState.swift:326-328` | |
| Undo | `_ = self.videoRegions` in `observeChanges`; rule "Video region added/removed/adjusted" | `EditorState+Persistence.swift:403`, `History+ChangeRules.swift:259-264`, `History.swift:145-163` | |
| Trim range | `trimStart/trimEnd` reset to `0…duration` at the end of `setup()`; `trimHandleOverlay`/`trimBorderOverlay` have no call sites | `EditorState.swift:351-353`, `TimelineView+Overlays.swift:5-55` | Trim is dead UI; video regions replaced it. "Trim bounds" are always the full source |
| Track appear/disappear | `showSpotlightTrack`, `visibleTrackCount`, sidebar + content `if` blocks with `.transition(.trackTransition)`; `EditorView.timelineTrackSignature` drives the animation | `TimelineView.swift:85-97, 110-141, 157-209`; `EditorView.swift:18-25, 77` | Zoom track is gated by the stored `zoomEnabled` (`PropertiesPanel+CursorZoomTab.swift:225`); spotlight by `spotlightEnabled && cursorMetadataProvider != nil` |
| Transport-bar buttons | `IconButton(systemName:color:action:)` over `PlainCustomButtonStyle` | `Reframed/UI/IconButton.swift:3-19`, `EditorView+TransportBar.swift:42-96` | Zoom in/out/reset, history, undo, redo, fullscreen |
| Editor key handling | local `NSEvent` monitor: space/return, esc, arrows; undo/redo via `ShortcutAction` | `Reframed/Editor/EditorWindow.swift:98-146`, `Reframed/Utilities/KeyboardShortcut.swift:113-121` | |
| Icons | `hand.point.up.left`, `hand.point.up`, `scissors`, `hand.tap` | verified with `NSImage(systemSymbolName:)` on this machine | all resolve |

### Evidence that regions are keep-slices

The default state is one region covering the whole recording (`Reframed/Editor/EditorState.swift:254`):

```swift
    videoRegions = [VideoRegionData(startSeconds: 0, endSeconds: dur)]
```

Export inserts only what is inside a region and concatenates it (`Reframed/Compositor/VideoCompositor.swift:46-57`):

```swift
    if hasVideoRegions, let vRegions = config.videoRegions {
      var insertTime = CMTime.zero
      for region in vRegions {
        let overlapStart = CMTimeMaximum(region.timeRange.start, effectiveTrim.start)
        let overlapEnd = CMTimeMinimum(region.timeRange.end, effectiveTrim.end)
        guard CMTimeCompare(overlapEnd, overlapStart) > 0 else { continue }
        let segmentRange = CMTimeRange(start: overlapStart, end: overlapEnd)
        try compScreenTrack?.insertTimeRange(segmentRange, of: screenVideoTrack, at: insertTime)
        videoSegments.append(VideoSegment(sourceRange: segmentRange, compositionStart: insertTime))
        insertTime = CMTimeAdd(insertTime, segmentRange.duration)
      }
      compositionDuration = insertTime
```

The player already jumps from the end of one slice to the start of the next, but only in preview mode (`Reframed/Editor/SyncedPlayerController.swift:183-185, 191-207`):

```swift
        if self.previewMode && self.isPlaying {
          self.handlePreviewGapSkip(at: CMTimeGetSeconds(time))
        }
  ...
    let inRegion = regions.contains { time >= $0.start && time < $0.end }
    if !inRegion {
      if let next = regions.first(where: { $0.start > time }) {
        let seekTime = CMTime(seconds: next.start, preferredTimescale: 600)
        seek(to: seekTime)
        screenPlayer.play()
```

Per-frame lookups in the compositor go back to source time, so zoom keyframes and cursor samples never need rewriting (`Reframed/Compositor/CompositionInstruction.swift:283-292`):

```swift
  func sourceTime(for compositionTime: CMTime) -> Double {
    let t = CMTimeGetSeconds(compositionTime)
    for seg in videoSegmentMappings {
      let compEnd = seg.compositionStart + seg.duration
      if t >= seg.compositionStart && t < compEnd {
        return seg.sourceStart + (t - seg.compositionStart)
      }
    }
    return t + trimStartSeconds
  }
```

The one piece of arithmetic the feature is missing is a split; today's creation path only fills gaps (`Reframed/Editor/EditorState+VideoRegions.swift:5-8`):

```swift
  func addVideoRegion(atTime time: Double) {
    if videoRegions.contains(where: { time >= $0.startSeconds && time <= $0.endSeconds }) {
      return
    }
```

## Gaps

1. **No "cut at playhead".** `addVideoRegion` inserts into a gap; there is no split of the region under the playhead, which is the LosslessCut gesture.
2. **No dedicated track.** Slices are drawn on the Screen track itself; nothing appears or disappears on the first cut.
3. **Gap skipping is preview-mode only.** In edit mode (`isPreviewMode == false`) playback runs through the gaps and the cut-out frames are visible (`SyncedPlayerController.swift:183`, `VideoPreviewView+Update.swift:141`).
4. **Skip uses the periodic observer**, so up to one 60 Hz tick of cut content can play before the seek; `boundaryObserver` exists but is unused.
5. **No compressed timeline**; every track positions `time / totalSeconds * width` in source time (`TimelineView.swift:40-42`, `+Ruler.swift:5-42`, `+Overlays.swift:57-93`).
6. **The cut path of `remapAllRegions` and the composition builder are untested** (`RegionRemappingTests` covers `hasVideoRegions: false` only).
7. **Not lossless in the literal sense**: any cut forces re-encoding (`checkNeedsCompositor`, `+InstructionBuilder.swift:39`); the passthrough branch would also be wrong with segments (`VideoCompositor.swift:230-247` uses `effectiveTrim.duration`, not `compositionDuration`, and passes no segments to `addAudioTracks`).
8. Undo labels say "Video region added" rather than "Cut".
9. `EditorState+VideoRegions.swift` region math is `@MainActor` and reads `duration` from `AVPlayer` (seam S6 in `07-testability.md`), so the pure logic is T2 until extracted; `ReframedTests/` has no `Fixtures/` or `Support/` yet and `scripts/make-fixtures.swift` does not exist.

## Recommended approach: (a) a UX layer over existing video regions

The data model needs no new persisted type. A "kept slice" **is** a `VideoRegionData`; a "cut" **is** the boundary between two adjacent regions or between a region and a gap. Mapping:

| Feature concept | Existing model | Operation |
| --- | --- | --- |
| No cuts | one region `[0, duration]` | `isSingleFullRange` (`EditorState+Export.swift:102-107`) |
| Cut at playhead `t` | region `[s, e]` containing `t` becomes `[s, t]`, `[t, e]` | **new** `splitVideoRegion(atTime:)` |
| Remove a slice | `removeVideoRegion(regionId:)` (creates a gap) | existing |
| Adjust a slice | `updateVideoRegionStart/End`, `moveVideoRegion` | existing |
| Re-add a slice into a gap | `addVideoRegion(atTime:)` | existing (double-click) |
| Clear all cuts | `videoRegions = [full]` | **new** `clearVideoCuts()` |
| Kept total / elapsed | `videoRegionsTotalDuration`, `previewElapsedTime` | existing |
| Track visible | `videoRegions.count > 1 || hasVideoRegionCuts` | **new** derived `showCutTrack` (no stored flag, no persistence, no history rule) |

Put the arithmetic in a new value type, `Reframed/Editor/CutTimeline.swift` (working name; `struct CutTimeline { var slices: [VideoRegionData]; let duration: Double }`), with `split(at:minLength:)`, `remove(id:)`, `totalDuration`, `elapsed(forSource:)`, `source(forElapsed:)`, `nextSliceStart(after:)`, `contains(_:)`, `normalized()` (sort, clamp to `[0, duration]`, drop `< minLength`, merge overlaps). `EditorState` methods delegate to it in one-liners, which is exactly seam S6 phase 2 and makes everything T1. Existing `EditorState.previewElapsedTime`/`sourceTimeForPreviewElapsed` become delegations (pin their current output first, rule 3 of `planning/tdd-strategy.md`).

Edge cases and the rule for each:

| Case | Rule | Where enforced |
| --- | --- | --- |
| Split point outside any slice (in a gap) | no-op; the button is disabled when the playhead is in a gap | `CutTimeline.split` returns unchanged; transport bar reads `contains(currentTime)` |
| Split within `minLength` of a slice edge | no-op (`minLength = 0.05`, the constant `addVideoRegion` already uses at `+VideoRegions.swift:28-33`) | `CutTimeline.split` |
| Overlapping slices (only reachable from a hand-edited `project.json`) | `normalized()` merges on restore | `restoreFromSnapshot` and `setup()` call sites |
| Slice touching 0 or `duration` | allowed; trim is always the full source (`EditorState.swift:351-353`), so no trim interaction | none needed |
| Zero-length after a resize | already prevented by the 0.01 s clamps (`+VideoRegions.swift:50, 59`); `normalized()` drops any that slip through | `CutTimeline` |
| Split inside a camera region | export splits the camera region per segment and re-runs its entry transition at the second piece (`+RegionRemapping.swift:71-101`); preview is unaffected (source time) | document as known; pin with a test |
| Split inside a zoom region | zoom stays in source time via `sourceTime(for:)`; a zoom easing across the gap jumps at the boundary | known; optional later "snap zoom keyframes to cut" |
| Split inside a spotlight / caption | remapped per segment, captions word-clipped (`:188-221, 255-318`) | existing |
| Split inside an audio region | `addAudioTracks` intersects per segment (`+Audio.swift:26-38`) | existing |
| Cursor metadata timestamps | never rewritten; export reads through `sourceTime(for:)`, preview uses `currentTime` | existing |

## Playback design

- **Edit mode and preview mode both skip gaps once cuts exist.** Replace the `previewMode` gate in `SyncedPlayerController.setupTimeObserver` (`:183`) with `skipsGaps` set from `hasVideoRegionCuts` (edit mode) or always in preview mode; `togglePlayPause` (`EditorState+Playback.swift:12`) drops its `isPreviewMode &&` condition. Seeking (ruler scrub, playhead drag, arrows) still lands anywhere in source time so the user can inspect cut-out material; playing from a gap jumps to the next slice as today.
- **Jump precision.** Install `addBoundaryTimeObserver(forTimes: sliceEnds)` in the unused `boundaryObserver` (`SyncedPlayerController.swift:17`) and seek from there; keep the periodic check as the fallback. Pure part: `CutTimeline.nextSliceStart(after:)`; the observer itself is T3.
- **Scrubber mapping (dimmed mode, default).** Timeline stays in source time; the Cuts track draws gaps as dimmed bands; the Screen track becomes a plain full-width bar when `showCutTrack` (its slice views move to the Cuts track, same `videoRegionView` code and handles).
- **Compressed mode.** A `TimelineView` display mode (view state next to `timelineZoom`, not persisted). `totalSeconds` becomes `totalDuration`; every x-position goes through `elapsed(forSource:)`; the ruler labels compressed time; the playhead maps `currentTime` through the same function; scrub inverse-maps with `source(forElapsed:)`. Other tracks' regions that span a gap are drawn as split pieces (mirror of `remapRegion`) and are read-only in compressed mode in v1. The Cuts track shows slices back-to-back with cut markers instead of gaps.

## Export design

Nothing in `Compositor/` changes for the core feature: `EditorState.export` already emits `videoRegions` whenever the slices are not the single full range, and `VideoCompositor.export` builds the segmented composition, remaps every region family, audio, clicks, zoom and cursor. The work is verification: characterization tests for the `hasVideoRegions: true` branch of `remapAllRegions`, `sourceTime(for:)`, and an env-gated `ExportPipelineTests` run on a two-slice project asserting the output duration equals the kept total. Optional later phase: a true passthrough for "cuts only, no effects" (fix `VideoCompositor.swift:230-247` to use `compositionDuration` and pass segments to `addAudioTracks`, and drop `hasVideoRegions` from `checkNeedsCompositor`); AVFoundation passthrough cuts at non-keyframe positions is a real risk (see below).

## Interactions with other tracks

| Track / data | Preview | Export | Change needed |
| --- | --- | --- | --- |
| Zoom keyframes | source time, unaffected | `resolveZoomRect` via `sourceTime(for:)` (`FrameRenderer+Helpers.swift:83`) | none; compressed-mode drawing only |
| Spotlight regions | `isSpotlightActive(at:)` in source time | `remapSpotlightRegion` per segment | none |
| Camera regions | source time | `remapRegion`/`remapCustomRegion` per segment, transitions re-run | none; document |
| Captions | source time overlay | `remapCaptionSegments` word-clipped | none |
| Audio regions | `updateAudioMuting` in source time | `addAudioTracks` per segment | none |
| Cursor metadata / click sounds | `currentTime` lookups | `sourceTime(for:)`, `generateClickSound` remap | none |
| Screen transitions on slices | `updateScreenVisibility` | `remapVideoRegions` (0.01 s match) | none; keep `VideoRegionEditPopover` |

## Persistence and history

Already complete for the model: `videoRegions` is in `EditorStateData` (optional, omitted when empty), restored in `setup()` and `restoreFromSnapshot`, observed for autosave and undo snapshots. The only additions are `normalized()` on restore and, optionally, better labels in the existing `regions(\.videoRegions, …)` rule (`History+ChangeRules.swift:259-264`; edit the strings in place, do not add a second rule for the same keypath because rules are `flatMap`ped and both would print). The display mode (dimmed/compressed) is view state, not project data. Old projects load unchanged: a missing or single full region means "no cuts".

## Risks and unknowns

- **T2 test infrastructure does not exist yet.** `EditorState` tests need `ReframedTests/Fixtures/screen-2s.mov` and `Support/Fixtures.swift` (`07-testability.md` §T2, `planning/tdd-strategy.md` "Fixtures"). Phases 2 and 5 depend on milestone 01 delivering them; phase 1 does not.
- **Upstream merge surface.** `EditorState+VideoRegions.swift`, `EditorState.swift:138-176`, `SyncedPlayerController.swift`, `TimelineView*.swift`, `EditorView+TransportBar.swift` are upstream files. Keep edits to delegations and additive `if` blocks; list each in `planning/upstream-sync.md`.
- **Frame flash at cut boundaries** in edit mode until the boundary observer lands; preview mode already hides the screen layer.
- **Passthrough "lossless" export** would cut at non-sync samples; AVFoundation may produce glitches at segment starts. Keep re-encoding as the default and treat passthrough as an opt-in experiment.
- **Compressed mode geometry** touches every track's positioning code (six files); the risk is drift between tracks. Mitigate by one shared `xPosition(forSource:)` helper on `TimelineView` used by all tracks.
- `videoRegions.count > 1` with equal total (a split without a removal) shows the Cuts track while `hasVideoRegionCuts` is false; export still emits `videoRegions` (two exact segments), forcing the compositor path with no visual change. Acceptable, but note the extra encode.

## Questions for the owner

1. "Preview playback" means the editor's normal playback too, not only the fullscreen preview mode? (Design assumes yes; changes the `previewMode` gate.)
2. When the Cuts track is visible, should the Screen track stop showing the slices (become a plain bar) to avoid two editable copies of the same regions?
3. Is "lossless" literal (no re-encode when there are no effects) or the LosslessCut-style UX only? Literal changes export scope and adds the passthrough risk above.
4. Split inside a camera or spotlight region: keep the region continuous across the cut (current export behaviour re-runs the entry transition at the second piece) or split it into two independent regions in the model at cut time?
5. Compressed mode: v1 read-only for other tracks' regions, or full editing in compressed coordinates?
