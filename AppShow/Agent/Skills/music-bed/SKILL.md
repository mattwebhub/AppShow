---
name: music-bed
description: Place and balance a user-approved music bed in an AppShow project without obscuring narration.
---

# Music bed

Read `get_project_summary`, `get_timeline`, and `get_transcript` before choosing placement. Ask the user for the exact audio file when none has been provided; `add_music` requires in-app confirmation before copying it into the project.

Place the track with `add_music` at the start of the kept presentation. Begin conservatively around 15 to 25 percent volume and use short fade-in and fade-out values. Refine placement, mute state, level, or fades with `set_music`; remove a rejected bed with `remove_music`.

AppShow does not yet expose volume automation or looping. Do not claim to duck under speech automatically. Re-read `get_timeline` and report the track, placement, level, and fades.
