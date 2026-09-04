# Tasks: Image overlays

Ordered red-green-refactor steps. One commit per step is the default.

- [x] 1. Planning docs: this folder and the T6 row in `planning/milestones/07-primitives/PLAN.md`.
- [x] 2. Data/import/editor: `ImageOverlayData` lenient persistence; hash-named, deduplicated ImageIO import; EditorState add/update/move/resize/remove; missing-file filtering; snapshot/restore/observation; shared track visibility; history rule. Proof: `ImageOverlayDataTests`, `ImageOverlayImporterTests`, `EditorStateImageOverlaysTests`, and `HistoryChangeRulesTests` green; format, lint, and build clean.
- [x] 3. Compositor: shared anchored layout, pure image layout, trim/cut remapping, one decode per filename, compositor selection, rounded/opacity/shadow/transition drawing in SDR and HDR. Proof: `ImageOverlayLayoutTests`, image rows in `RegionRemappingTests` and `InstructionBuilderTests`, three golden renderer tests, and the full 365-test suite green.
- [ ] 4. Preview: `Reframed/Editor/VideoPreviewContainer+ImageOverlays.swift` (`CALayer` per overlay with cached `CGImage` contents), `VideoPreviewView.imageOverlays` and `imageOverlayDirectory`, `updateImageOverlays` in `VideoPreviewView+Update.swift`, wired from `EditorView+Preview.swift`; `make build` warning-free.
- [ ] 5. Timeline and properties: `Reframed/Editor/TimelineView+OverlayChip.swift` (`OverlayChip` enum over both kinds) with `TimelineView+OverlayTrack.swift` rendering both, `ImageOverlayEditPopover.swift`, `Reframed/UI/OverlayPositionControls.swift` shared with the text popover, "Add Image" and image rows in `PropertiesPanel+OverlaysSection.swift`; `make build` warning-free; manual rows in the milestone `VERIFY.md`; divergence line in `planning/upstream-sync.md`.
