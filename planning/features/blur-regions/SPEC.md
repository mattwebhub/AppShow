# Blur regions

## Outcome

A project can hide sensitive screen content with a timed rectangular blur. The rectangle is stored in normalized source-video coordinates, so it follows the same source pixels through zoom, canvas resizing, preview, trimming, cuts, and export.

## Behavior

- Effects > Add Blur creates a three-second region at the playhead and reveals the shared Overlays track.
- A region stores `startSeconds`, `endSeconds`, normalized top-left `x`/`y`/`width`/`height`, and a source-pixel blur radius.
- Rectangles clamp to the unit square, keep at least one percent width and height, and radius clamps to 0–100.
- The Overlays track supports move, edge resize, right-click editing, removal, and compressed-mode read-only behavior.
- The compositor applies blur to the source image before the zoom crop. Trim and keep-slice export remap only time; the source rectangle is unchanged.
- The live preview places masked Core Image backdrop filters over the same source coordinates and follows the player layer's zoom transform.
- Old project JSON decodes with no blur regions. Snapshot restore and History include the field.

## Non-goals

- Motion tracking, automatic sensitive-content detection, feathered masks, arbitrary polygons, and keyframed rectangle movement.
- Agent tool wrapping on the primitive branch; that lands on the agent-editing integration branch.
