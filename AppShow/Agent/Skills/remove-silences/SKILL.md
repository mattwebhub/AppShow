---
name: remove-silences
description: Remove dead air from an AppShow recording while protecting spoken words, clicks, and useful pacing.
---

# Remove silences

Call `get_silences`, `get_transcript` with word timings, `get_cursor_activity`, and `get_timeline` before editing. Treat detected gaps as candidates, not instructions: retain any candidate that overlaps speech, a meaningful click cluster, or the breathing room needed around a chapter boundary.

When the detector result is safe as a whole, use `remove_silences` with at least 0.15 seconds of padding. For selective removal, derive the resulting kept ranges and call `set_kept_slices`. The app asks for confirmation when removal exceeds 40 percent of currently kept video.

Re-read with `get_timeline`. Report the removed duration and any candidate gaps deliberately retained.
