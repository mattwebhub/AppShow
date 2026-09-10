---
name: presentation-cut
description: Turn a raw AppShow screen recording into a concise, structured presentation with cuts, zooms, spotlights, title cards, and a consistent canvas.
---

# Presentation cut

Inspect the recording with `get_project_summary`, `get_timeline`, `get_transcript`, `get_cursor_activity`, and `get_silences`. Identify the setup, three to six meaningful steps, and the outcome. Keep enough context around speech and interactions for each step to stand on its own.

Apply the plan inside one `begin_batch` / `end_batch` transaction. Use `set_kept_slices` for the narrative cut, then add restrained `add_zoom`, `add_spotlight`, and `add_text` edits. Use `set_transition` for title-card entry and exit, and `set_canvas` only when it improves consistency.

Before finishing, call `get_timeline` again, use `render_preview_frame` at the opening, each chapter title, and the result, then create a private low-resolution review with `export_draft`. Keep chapters at least three seconds where the source permits, do not place zoom changes on cut boundaries, and report the kept duration, draft path, and edits made.
