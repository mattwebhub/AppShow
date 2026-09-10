---
name: add-title-cards
description: Add clear AppShow opening, chapter, and closing titles derived from a recording's content.
---

# Add title cards

Read `get_transcript` and `get_timeline`. Draft short titles that describe outcomes or actions rather than repeating narration. Use `add_text` for two- to three-second cards at natural boundaries, staying away from the active caption position.

Apply restrained entry and exit motion with `set_transition`; prefer fade or scale for titles and use slide only when it matches the visual direction. Use `set_canvas` only when the existing canvas cannot provide a readable safe area.

Validate the opening, every chapter card, and the closing with `render_preview_frame`, then re-read `get_timeline` and report the titles and timings.
