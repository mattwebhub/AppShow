# ADR 0014: portable caption font selection

Status: accepted, 2026-09-05.

Caption settings persist a font family string alongside the existing size, weight and colors. Missing fields decode as `System`, preserving old projects. The UI lists locally installed font families with search. Fonts are not embedded or downloaded; unavailable families retain their saved name and render with the system font.

A shared `CaptionFont` resolver supplies the same AppKit font to SwiftUI preview, CoreText measurement and the shared SDR/HDR caption compositor. Export configuration and composition instructions carry the family explicitly, including agent preview configuration. History snapshots include it.

The existing `set_captions` MCP tool gains `fontFamily`, `textColor` and `backgroundColor`. Colors use required normalized `r`, `g`, `b` channels and optional `a` (default 1); background alpha multiplies the existing backgroundOpacity. Timeline inspection returns these styles. Existing tool names and arguments remain compatible.

These settings affect visible captions only. Recorded audio transcripts and agent spoken context are independent.
