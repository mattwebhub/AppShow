---
name: spotlight-clicks
description: Emphasize meaningful recorded interactions with restrained AppShow spotlights and zooms.
---

# Spotlight clicks

Read `get_cursor_activity` and `get_timeline`. Ignore repeated clicks that express one action, clicks inside removed ranges, and low-value navigation that does not advance the presentation.

Use `set_cursor` to keep the cursor visible when spotlights are part of the result. Add one `add_spotlight` per meaningful click cluster, sized to the cluster spread with enough room to recognize the control. Add `add_zoom` only when the target would otherwise be hard to read; avoid overlapping zoom changes and cut boundaries.

Use `render_preview_frame` at representative clusters, then call `get_timeline` and report which interactions were emphasized or skipped.
