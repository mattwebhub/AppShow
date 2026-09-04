# Overall plan

## Product goal

Turn a raw screen recording into a polished presentation with as little manual work as possible. The end state: the user records a flow, opens the editor, and tells an in-app agent "make an awesome presentation of this". The agent cuts dead time, keeps the interesting slices, adds spotlights and zooms on the clicks, lays a music bed, adds title cards and images, blurs sensitive areas, and the user watches every step land on the timeline and in the preview, able to undo any of it.

Everything before that end state is a feature the user can also drive by hand, so each one ships on its own.

## Features

| # | Feature | One-line scope | Depends on | Docs |
|---|---------|----------------|------------|------|
| 01 | Lossless cut | Keep-slices on a new timeline track under Screen; preview and export play only the kept slices; optional compressed timeline | nothing | `01-lossless-cut/` |
| 02 | Music tracks | Import audio files into the `.frm` bundle, position and trim them on their own track, volume/mute/fades, mixed into preview and export | nothing | `02-music-tracks/` |
| 03 | Agent chat | Collapsible left panel in the editor hosting a chat with a Claude Code or Codex session, ported from the Toone desktop app, in this app's design language | nothing for the shell; 04 for usefulness | `03-agent-chat/` |
| 04 | Agent tools | MCP tools and skills that let the agent edit the open project with live feedback; new editor primitives the agent needs | 01, 02, 03, plus the primitives below | `04-agent-tools/` |

### What the spikes found

| Feature | Finding that changes the plan | Consequence |
|---------|-------------------------------|-------------|
| 01 | Upstream's video regions are already keep-based: default is one full-length region, export concatenates only regions, the player already jumps gaps in preview mode, persistence and history exist (`docs/features/01-lossless-cut/SPIKE.md`). `docs/editor.md` describes them wrongly as cuts. | Feature 01 is a UX layer: split-at-playhead, a dedicated Cuts track under Screen, jumping in normal playback, a compressed timeline. Size drops from L to M. |
| 02 | AVFoundation decodes every common format through the existing audio-mix reader, so no conversion step. The export mix pairs tracks and sources by index and is already off by one when click sounds are on (`docs/features/02-music-tracks/SPIKE.md`). | Characterization test for the existing bug goes into milestone 01. Biggest risk is preview drift between the player clock and the audio engine clock; mitigations are in the attack plan. |
| 03 | The Toone desktop app already has stream parsers for both runtimes, command builders with tests, readiness detection, and a markdown renderer (`docs/features/03-agent-chat/SPIKE.md`). It is Swift 5 without strict concurrency, and `apps/toone-desktop` has no LICENSE file though both repos share an owner. | Copy the parsers, command builders, and markdown view; rewrite process and session classes as actors. The editor layout has a one-line insertion point for a left panel (320 pt expanded, 40 pt rail collapsed). Record provenance of copied code in an ADR before the first copy. |
| 04 | Editing `project.json` on disk cannot give live feedback (read once at open, rewritten by autosave every second). A small Swift stdio shim forwarding JSON-RPC over a Unix socket to a main-actor dispatcher does (`docs/features/04-agent-tools/SPIKE.md`). | The dispatcher is transport-agnostic, so an HTTP MCP endpoint can replace the shim later. One history snapshot per tool call with a label, plus explicit batches. |

### Editor primitives the agent needs that do not exist yet

These surface in feature 04's spike but are real editor features in their own right. Each becomes its own small feature folder when scheduled.

| Primitive | Why the agent needs it | Likely home in the code |
|-----------|------------------------|-------------------------|
| Text overlay (title cards, callouts) | "add texts" | new `CompositionInstruction` field, `FrameRenderer+Text`, new timeline track |
| Image overlay (logos, collage panels) | "add images, collages" | same path as text, image stored in the bundle |
| Blur region | hide sensitive content | `FrameRenderer` mask pass, region on a track |
| Silence detection | "remove silent gaps" | audio analysis feeding keep-slices from feature 01 |
| Transitions / simple animations | polish between slices and for overlays | extends the entry/exit transitions camera regions already have |

## Order and rationale

1. **01 Lossless cut first.** Smallest surface, touches the region model that everything else reuses, and immediately useful by hand. Its remap logic is pure and a good first TDD exercise on real product code.
2. **02 Music tracks second.** Independent of 01, can run in parallel with a second developer. Establishes "external media inside the bundle", which text and image overlays reuse.
3. **03 Agent chat third.** The panel shell, provider detection, and stream parsing can be built and tested with no tools at all. Porting from Toone is mostly mechanical, so this can start while 01 and 02 finish.
4. **04 Agent tools last, incrementally.** Read-only tools first (the agent can describe the timeline), then the mutating tools for what already exists (cuts, zoom, spotlight, captions, music), then the new primitives one at a time, each shipped as a manual feature and a tool together.

## Principles for every feature

- Tests first, per `planning/tdd-strategy.md`. Pure logic (remaps, parsers, tool dispatch) is tier 1 and gets tested before any UI exists.
- New code goes in new folders where possible (`Reframed/Agent/`, `ReframedTests/`), upstream files get the smallest seams. Every divergence lands in `planning/upstream-sync.md`.
- UI follows `docs/architecture/05-coding-patterns.md` and the checklist in `06-conventions-checklist.md`: existing button styles, color tokens, track patterns (Zoom and Spotlight tracks are the template for new tracks).
- Every agent mutation is one undoable history step with a readable label, so the user can watch and revert.
- The agent runtime is pluggable: Claude Code and Codex are the first two providers behind one protocol.

## Milestone mapping

See `planning/ROADMAP.md`. Milestone 01 (test foundation) precedes feature work; then one milestone per feature, with 04 split into several.

## Open questions for the owner

Collected from the spikes. Each has a stated assumption so work continues; an answer that differs changes the design and is recorded in the feature's spike.

### 01 Lossless cut

1. Playback jumping applies to normal editor playback too, not only fullscreen preview? Assumed yes.
2. Once the Cuts track is visible, does the Screen track stop showing the slices, to avoid two editable copies? Assumed yes.
3. Is "lossless" literal (no re-encode when no effects are applied) or only the LosslessCut-style UX? Assumed UX only; literal passthrough is an optional last phase.
4. A cut inside a camera or spotlight region: keep the region continuous across the cut, or split it into two? Assumed continuous.
5. Compressed timeline: other tracks read-only in v1, or fully editable in compressed coordinates? Assumed read-only first.

### 02 Music tracks

6. One timeline row per file (assumed) or a single Audio row with lanes?
7. Tracks clamped to the recording length (assumed) or allowed to hang past the end?
8. Import places the file at the playhead (assumed) or at 0:00?
9. Linear fades (assumed) or equal-power?
10. Auto-duck music under the microphone? Assumed out of scope for v1.
11. Loop a short file to fill the recording? Assumed no.
12. Enable the Audio tab for recordings with no captured audio so music can still be added? Assumed yes.
13. Orphaned media files in the bundle: keep (assumed) or clean on close? Warn above a size such as 200 MB?

### 03 Agent chat

20. v1 agent is read-only (chat, inspect) until feature 04 adds tools? Assumed yes.
21. Working directory: the `.frm` bundle itself (agent can read media) or a sandbox subfolder exposing only `project.json`? Assumed a workspace folder next to the bundle, consistent with question 14.
22. Conversation stored inside the bundle travels with a shared project. Decided: acceptable, with an explicit clear action; exactly one conversation belongs to each project (ADR 0010).
23. One process per turn (about 1 s cold start, no mid-turn steering, less code) or a persistent process as Toone does? Decided: one fresh process per turn (ADR 0010).
24. Provider preference global (assumed) or per project?
25. Keyboard shortcut to toggle the panel in v1 (edits upstream `KeyboardShortcut.swift`) or none? Assumed none.
26. Provenance of copied Toone code: add a LICENSE there, or record authorization in an ADR here? Assumed ADR here (`planning/decisions/0009-toone-code-provenance.md`), LICENSE there when convenient.
27. Refuse to run the agent while an export is in progress? Assumed yes.

### 04 Agent tools

14. Agent workspace next to the project folder or inside the `.frm` bundle? Decided: ephemeral runtime state lives in a sibling `.agent/` workspace; the persisted conversation lives inside the `.frm` bundle (ADR 0010).
15. May the agent trigger a full export after confirmation, or is a low-res draft the ceiling? Assumed draft only.
16. Undo granularity: one step per tool call with explicit batches (assumed) or one step per chat turn?
17. Ship the Swift shim first and verify HTTP MCP on both runtimes later? Assumed yes.
18. Lock the timeline while a batch runs, or only show the "agent is editing" badge? Assumed badge only; a user undo cancels the batch.
19. First skills: the five in the spike (presentation cut, remove silences, spotlight clicks, title cards, music bed), or also a narration rewrite skill? Assumed five.
