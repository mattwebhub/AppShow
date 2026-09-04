# Test plan: blur regions

## Tier 1

- Decode defaults, normalize out-of-bounds rectangles, round-trip every field, and decode legacy projects without the field.
- Add, update, move, resize, remove, active-time filtering, snapshot restore, and shared track visibility in `EditorState`.
- History labels additions, removals, and adjustments.
- Trim and keep-slice remapping preserve the source rectangle and assign fresh IDs to split export regions.
- A blur region alone selects the compositor path.

## Tier 2

- A sharp black/white edge becomes grey only inside the selected rectangle.
- With a 2× zoom, the blurred pixels move with the source crop rather than staying at a canvas coordinate.
- Gated export renders a selected region at the expected output time.

## Manual

- Add and edit a blur from the Effects panel and Overlays track.
- Scrub while zoomed; the blur stays over the selected source content.
- Export SDR and HDR samples and compare the region against preview.
- Undo once after adding or editing and confirm the previous state returns.
