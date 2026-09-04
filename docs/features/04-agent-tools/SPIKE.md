# Spike 04 — Agent tools: MCP tools and skills that edit the open project live

**Scope.** How an in-app agent session (Claude Code or Codex, driven from the chat panel designed in spike 03) edits the project that is open in the editor, through MCP tools and written skills, with every change visible on the timeline and in the preview as it happens and undoable by the user. Written against the working tree on 2026-09-03 (upstream `v0.14.7` plus milestone 00). Every path below was verified to exist; line numbers are from this tree.

Sections: 1 what exists today · 2 transport · 3 tool catalog · 4 feedback loop · 5 skills · 6 safety · 7 missing primitives · 8 sequence diagram · 9 risks · 10 questions for the owner.

---

## 1. What exists today

### 1.1 The editor state the agent must drive

| Fact | Evidence |
| --- | --- |
| All editable state is stored `var`s on one `@MainActor @Observable final class EditorState` | `Reframed/Editor/EditorState.swift:7-125` |
| Mutations are plain property writes or small methods in `EditorState+*.swift`; nothing is a command object | `Reframed/Editor/EditorState+VideoRegions.swift:5-88`, `+SpotlightRegions.swift:11-119`, `+Zoom.swift:5-103`, `+CameraRegions.swift:115-211`, `+AudioRegions.swift:22-90`, `+Playback.swift:45-52` |
| SwiftUI observation fans a write out to the preview synchronously (`EditorView+Preview` → `VideoPreviewView.updateNSView` → `VideoPreviewView+Update.swift:164-274`) | `docs/architecture/03-data-flow.md` Flow B |
| Persistence and undo are automatic and debounced: `observeChanges()` lists every undoable property (`EditorState+Persistence.swift:350-435`), `scheduleSave()` writes `project.json` after 1 s (`:7-14`), `scheduleUndoSnapshot()` pushes a full snapshot after 1.5 s of quiet (`:337-344`) | same file |
| A snapshot is `EditorStateData` (`Reframed/Project/ProjectMetadata.swift:463-495`), produced by `createSnapshot()` (`+Persistence.swift:16-128`) and applied by `restoreFromSnapshot(_:)` (`:130`); `undo()`/`redo()` at `:322-330` | same |
| `History` keeps 50 `HistoryEntry(snapshot:timestamp:)` values with no label field (`Reframed/Editor/History.swift:3-6, 24-35`); labels are computed after the fact by diffing two snapshots (`History+ChangeRules.swift:345-349`) | same |
| Explicit, non-debounced pushes already exist for discrete operations: `generateCaptions` (`EditorState+Captions.swift:65`), `clearCaptions` (`:87`), `updateSegmentText` (`:95`), `deleteSegment` (`:104`), and drag end in `EditorView+Preview.swift` | same |
| Keyboard undo/redo goes through `EditorWindow.setupKeyboardMonitor` → `state.undo()/redo()` | `Reframed/Editor/EditorWindow.swift:98-117` |
| One editor window per open project; `SessionState.editorWindows` holds them | `Reframed/State/SessionState+Project.swift:23-56` |
| `.frm` opens arrive through `AppDelegate.application(_:open:)` → `session.openProject(at:)` | `Reframed/App/AppDelegate.swift:100-104` |

### 1.2 Data the agent can inspect

| Data | Where | Notes |
| --- | --- | --- |
| Word-level transcript | `CaptionSegment.words: [CaptionWord]?` with `word/startSeconds/endSeconds` (`ProjectMetadata.swift:154-166`); produced with `wordTimestamps: true` (`Reframed/Utilities/TranscriptionService.swift:48`) and drift-corrected in `EditorState+Captions.swift:37-58` | Transcription is async on WhisperKit; a tool must await `isTranscribing == false` |
| Cursor clicks and samples | `CursorClickEvent(t:x:y:button:)`, `CursorSample`, `KeystrokeEvent` (`Reframed/Editor/CursorMetadata.swift:45-96`); `EditorState.cursorMetadataProvider` (`EditorState.swift:47`) | Normalized 0–1 coordinates |
| Click clusters | `ZoomDetector.detect(from:duration:config:)` groups clicks by dwell (`Reframed/Editor/ZoomDetector.swift:10`); `groupZoomRegions(from:)` turns keyframes into regions | Pure, T1 |
| Audio samples for silence detection | `AudioWaveformGenerator.extractSamples` is `nonisolated private static` (`Reframed/Editor/AudioWaveformGenerator.swift:33`) | Seam S7 (drop `private`) or a new `SilenceDetector` |
| Preview/export geometry | `EditorState.canvasSize(for:)` (`+CameraLayout.swift:52`), `ExportConfiguration` (`Reframed/Compositor/ExportConfiguration.swift:7-68`) | |

### 1.3 Rendering paths a new primitive must touch

`FrameRenderer.renderFrame` (`Reframed/Compositor/FrameRenderer.swift:190`) draws, in order, `+Background` → `+Screen` → `+Webcam` → `+Cursor` (`FrameRenderer+Cursor.swift:5`) → `+Spotlight` (`FrameRenderer+Spotlight.swift:5`) → `+Captions` (`FrameRenderer+Captions.swift:6`, called at `FrameRenderer.swift:320-330`). Every parameter comes from the immutable `CompositionInstruction` (`Reframed/Compositor/CompositionInstruction.swift:33-171`) built in `VideoCompositor+InstructionBuilder.swift`. The preview mirrors each stage with CALayers (`VideoPreviewView+Update.swift:200 updateOverlays`, `VideoPreviewContainer+Spotlight.swift:5`, `SpotlightOverlayLayer.swift:34`). `06-conventions-checklist.md` §"Adding a new editor property" lists the 12 sites; a new overlay primitive hits all of them plus a timeline track modeled on `TimelineView+SpotlightTrack.swift:4-193`.

### 1.4 What Toone already solved (reuse)

| Concern | Toone evidence | Reuse |
| --- | --- | --- |
| MCP server shape: `Server` from `@modelcontextprotocol/server` 2.0.0 with `setRequestHandler("tools/list")` / `("tools/call")`, served over stdio | `/Users/matheusparanhos/Projects/toone/packages/mcp-server/src/index.ts:1149-1162, 1799-1804`; `package.json` | Same JSON-RPC methods, whichever language hosts them |
| Tools are plain `{name, description, inputSchema}` objects; arguments validated with Ajv before dispatch; a static per-tool note appended to successful results | `src/tools/guides.ts:7-16`; `src/index.ts:1176-1197`; `src/tools/tool-notes.ts` | Catalog-as-data, validate-before-mutate, "notes" for skill hints |
| The Node server is a thin client: real work happens in the app over a loopback WebSocket (`ws://localhost:9876`, port from `--browser-bridge-port=`), identity from env (`TOONE_AGENT_ID`, `TOONE_THREAD_ID`), 30 s command timeout | `src/tools/browser/swift-bridge.ts:110-174`; Swift side `apps/toone-desktop/Toone/Toone/Core/Services/BrowserBridge/BrowserBridgeServer.swift:22-97` (`NWListener`) | This is transport option (b) below, proven in production |
| Claude Code receives servers via `--mcp-config <file>` + `--strict-mcp-config`, tools are auto-approved with `--allowedTools`, built-ins denied with `--disallowedTools` | `Toone/Core/Services/AIService/Claude/ClaudeCommandBuilder.swift:43-72` | Copy verbatim |
| `.mcp.json` entries are `{"type": transport ?? "stdio", "command", "args", "env"}`; HTTP marked "a later phase" | `Toone/Core/Services/MCPRegistry/MCPRegistryService.swift:425-436`; `MCPCatalog.swift:40` | Config writer |
| Codex has no project MCP file; servers are passed as `-c mcp_servers.<id>.command=… / .args=[…] / .env={…}`, env allow-listed with `env_vars=[…]`, per-tool `approval_mode="approve"`, `tool_timeout_sec`, and `-c mcp_servers={}` to drop inherited servers | `Toone/Core/Services/MCPRegistry/CodexMCPOverrideBuilder.swift:19-95, 124-139` | Copy verbatim |
| Working directory is set on the spawned process (`task.currentDirectoryURL`) | `Toone/Core/Services/AIService/Codex/CodexService.swift:443`, `Base/BaseAIService.swift:315` | Per-project workspace |
| Transport tests spawn the built bundle and speak JSON-RPC over stdin; handler tests call handlers directly | `packages/mcp-server/src/__tests__/tool-advertising.test.ts:33-80`, `hook-analysis.test.ts` | Same two layers here |
| Skills: `SKILL.md` with `name`/`description` frontmatter; Codex reads `.agents/skills/` from cwd up to the repo root plus `~/.agents/skills/`, `agents/openai.yaml` can declare MCP tool dependencies; Claude Code reads `.claude/skills/<name>/SKILL.md`, `~/.claude/skills`, plugin `skills/`; `AGENTS.md` is always-on for Codex | `/Users/matheusparanhos/Projects/toone/docs/exploratory/agent-skills-strategy.md` §2–4; example `_templates/software-engineering/skills/source-triangulation/SKILL.md`; parser limits in `Toone/Core/Services/Skills/SkillParserService.swift:17-19` | Ship one canonical folder, materialize into both locations |

---

## 2. Transport: how a tool call reaches `EditorState` on the main actor

The runtime (Claude Code or Codex) is a child process spawned by the chat panel (spike 03). It, not the app, spawns MCP servers, so the app cannot be a stdio server itself. Four options:

| Option | How | Live feedback | Cost | Verdict |
| --- | --- | --- | --- | --- |
| (a) MCP server in-process speaking stdio | impossible: the CLI owns the server's stdin/stdout | — | — | rejected |
| (b) Tiny stdio shim → app over a loopback channel | shim forwards JSON-RPC lines to the app; app answers | yes, mutation happens in the app | one extra executable (Swift target) or a Node script; a socket server in the app | **recommended** |
| (c) App exposes streamable-HTTP MCP on localhost; CLI connects with `"type":"http"` | no shim; app implements HTTP + SSE session semantics | yes | HTTP server + MCP session handling in Swift; both runtimes' HTTP support must be verified per installed version (Toone still treats HTTP as "a later phase", `MCPCatalog.swift:40`) | phase-2 upgrade, same dispatcher |
| (d) Server edits `project.json` on disk, app reloads | file writes | no: `EditorState.init(project:)` reads the file once (`EditorState.swift:179-234`); autosave rewrites it every 1 s (`+Persistence.swift:7-14`) so writes race and get clobbered; nothing observes the file | nothing in the app | rejected |

### 2.1 Recommendation: (b) with a Swift shim and a Unix domain socket

- **Shim.** New command-line target `reframed-mcp` (third `PBXNativeTarget`; the project is `objectVersion = 90` with synchronized groups, `Reframed.xcodeproj/project.pbxproj:6, 517-523`, so adding a target is a small pbxproj edit), embedded at `Reframed.app/Contents/Helpers/reframed-mcp` and signed with the app. It reads newline-delimited JSON-RPC from stdin, writes each message to the socket, and relays responses to stdout. It answers nothing itself; `initialize`, `tools/list`, `tools/call` are all answered by the app. A Node script would need a `node` binary on the user's machine (Toone injects `${TOONE_NODE}`, `MCPRegistryService.swift:405`); Codex is a native binary, so Node is not guaranteed. Swift avoids that dependency and the shim is under 150 lines.
- **Channel.** `NWListener` on `NWEndpoint.unix(path:)` (same framework Toone uses for its loopback server, `BrowserBridgeServer.swift:97`), socket at `<workspace>/.reframed-agent.sock`, mode 0600. No TCP port to collide with, no firewall prompt, and the app sandbox is off (`Reframed/Reframed.entitlements`), so nothing blocks it.
- **Auth.** Per-session random token generated by the app when the chat session starts, passed to the shim in `env` (`REFRAMED_AGENT_TOKEN`) and sent in the first frame; a second token `REFRAMED_EDITOR_ID` binds the session to one `EditorWindow` so two open projects cannot cross. Same pattern as Toone's `TOONE_THREAD_ID` (`swift-bridge.ts:172-174`).
- **Concurrency placement.** `actor AgentBridgeServer` (`Reframed/Agent/AgentBridgeServer.swift`) owns the listener and connections and decodes JSON-RPC off-main. Each `tools/call` becomes `await MainActor.run { dispatcher.call(name, args) }` where `AgentToolDispatcher` is `@MainActor` and holds a `weak var editorState`. Tools that are inherently async (`generate_captions`, `render_preview_frame`, `export_draft`) return after their own `await`; the bridge applies a per-tool timeout (30 s default, 10 min for transcription/export) so a stuck call is reported instead of freezing the runtime's turn (Toone's `COMMAND_TIMEOUT_MS`, `swift-bridge.ts:111-115`). Rule from `02-concurrency.md` §5 holds: state stays on `@MainActor`, the actor only coordinates.
- **Project path and working directory.** The chat panel spawns the runtime with `currentDirectoryURL = <workspace>` where `<workspace>` is a per-project folder next to the bundle (spike 03's assumption, `docs/features/00-overall-plan.md` "Open questions"): `<projectFolder>/.agent/<bundle-name>/`. The bundle path is exported as `REFRAMED_PROJECT` for skills that mention it, but no tool takes a path argument: the session is bound to the open editor and `get_project` returns the bundle path read-only.
- **Runtime configuration.** Claude Code: write `<workspace>/mcp.json` `{"mcpServers":{"reframed":{"type":"stdio","command":"<app>/Contents/Helpers/reframed-mcp","env":{"REFRAMED_AGENT_SOCKET":…,"REFRAMED_AGENT_TOKEN":…,"REFRAMED_EDITOR_ID":…}}}}` and launch with `--mcp-config <workspace>/mcp.json --strict-mcp-config --allowedTools "mcp__reframed__*"` (`ClaudeCommandBuilder.swift:59-65` pattern). Codex: `-c mcp_servers={}` then `-c mcp_servers.reframed.command=…`, `.env={…}`, `.env_vars=[…]`, `.tool_timeout_sec=600`, and `.tools.<name>.approval_mode="approve"` for read-only tools (`CodexMCPOverrideBuilder.swift:19-95`).
- **Upgrade path to (c).** The dispatcher takes a decoded JSON-RPC request and returns a response value; the socket server is one adapter. When both runtimes' HTTP transport is confirmed, an `AgentHTTPServer` adapter replaces the shim without touching tools.

---

## 3. Tool catalog

Conventions: tool names are `snake_case`, advertised as `mcp__reframed__<name>` to Claude Code; every mutating tool takes `label?: string` (shown in history) and returns `{ok, historyIndex, label, timeline}` where `timeline` is the compact summary from `get_timeline`; times are seconds in source (recording) time, never composition time; ids are the region UUIDs from `EditorStateData`; errors return `isError: true` with `{code, message, didMutate:false}` (Toone's shape, `index.ts:1180-1197`). "Undo step" says whether the dispatcher pushes exactly one `History` entry for the call. "Live" says what the user sees.

### 3.1 Project inspection (read-only, auto-approved)

| Tool | Input sketch | Maps to | Undo step | Live |
| --- | --- | --- | --- | --- |
| `get_project` | `{}` | `EditorState.project?.bundleURL`, `projectName`, `result` sizes/fps/HDR (`EditorState.swift:10-11, 42`), `hasWebcam/hasSystemAudio/hasMicAudio` (`:127-136`) | no | badge only |
| `get_timeline` | `{detail?: "summary"\|"full"}` | `duration`, `trimStart/End`, `videoRegions`, `cameraRegions`, `spotlightRegions`, `systemAudioRegions/micAudioRegions`, `zoomTimeline?.allKeyframes`, caption count, `backgroundStyle`, `canvasAspect`, `padding` (all `EditorState.swift:13-121`); full mode returns `createSnapshot()` JSON | no | — |
| `get_transcript` | `{withWords?: bool, from?, to?}` | `captionSegments` and `words` (`ProjectMetadata.swift:154-166`); if empty and a model is downloaded, says so and points at `generate_captions` | no | — |
| `get_click_clusters` | `{dwellSeconds?: 0.5}` | `ZoomDetector.detect(from:duration:config:)` (`ZoomDetector.swift:10`) + `groupZoomRegions`; also raw `cursorMetadataProvider.metadata.clicks` counts per second | no | — |
| `get_silences` | `{thresholdDb?: -40, minGapSeconds?: 0.8, source?: "mic"\|"system"}` | does not exist yet: `SilenceDetector.detect(samples:sampleRate:…)` over `AudioWaveformGenerator.extractSamples` (seam S7) | no | — |
| `get_history` | `{}` | `history.entries` with labels and `describeChanges` (`History+ChangeRules.swift:345`) | no | — |
| `render_preview_frame` | `{atSeconds, width?: 640}` → `{path}` | does not exist yet as a unit: `AVAssetImageGenerator` for screen/webcam frames + `VideoCompositor.buildCompositionInstruction` + `FrameRenderer.renderFrame` (`FrameRenderer.swift:190`) into a BGRA buffer, PNG written under `<workspace>/frames/` | no | playhead seeks to `atSeconds` |
| `export_draft` | `{maxWidth?: 640, fps?: 15}` → `{path}` | `EditorState.export(settings:)` (`EditorState+Export.swift:6`) with a low-res `ExportSettings`; needs seam S3 `outputDirectory` so the draft lands in `<workspace>/drafts/`, not `~/Movies` | no | export progress UI |

### 3.2 Editing what exists today (each is one undo step, labelled)

| Tool | Input sketch | Maps to | Undo step | Live |
| --- | --- | --- | --- | --- |
| `set_trim` | `{start, end}` | `updateTrimStart/updateTrimEnd` (`EditorState+Playback.swift:45-52`) | yes | trim handles move; label "Trim range …" already produced by the rule at `History+ChangeRules.swift:5-11` |
| `add_cut` / `remove_cut` / `update_cut` | `{start, end}` / `{id}` / `{id, start?, end?, entryTransition?, exitTransition?}` | today: video regions (`+VideoRegions.swift:5, 42, 46, 55, 76`); `addVideoRegion(atTime:)` only inserts a fixed ±5 s region, so the dispatcher inserts the exact `VideoRegionData(startSeconds:endSeconds:)` and sorts, mirroring `:35-39`; after spike 01 these map to keep-slices | yes | region chips on the Screen track; playhead jumps to `start` |
| `set_keep_slices` | `{slices:[{start,end}]}` | replaces `videoRegions` wholesale (keep-slice model from spike 01) | yes | whole track redraws |
| `add_zoom` / `remove_zoom` / `auto_zoom` / `clear_auto_zoom` | `{at, centerX, centerY, level?, hold?}` / `{startIndex,count}` / `{level?, dwell?}` / `{}` | `addManualZoomKeyframe(at:center:)` (`+Zoom.swift:44`), `removeZoomRegion(startIndex:count:)` (`:83`), `generateAutoZoom()` (`:5`), `clearAutoZoom()` (`:34`); dispatcher sets `zoomEnabled = true` when adding | yes | zoom chips in `ZoomKeyframeEditor`; preview zooms at playhead |
| `add_spotlight` / `remove_spotlight` / `update_spotlight` | `{start, end, radius?, dimOpacity?, edgeSoftness?, fadeDuration?}` | `addSpotlightRegion(atTime:)` (`+SpotlightRegions.swift:11`) then `updateSpotlightRegionStart/End` (`:48, 56`) and `updateSpotlightRegionStyle` (`:67`); sets `spotlightEnabled = true` | yes | Spotlight track chip + `SpotlightOverlayLayer` |
| `add_camera_region` / `set_camera_region` / `remove_camera_region` | `{start, end, type: fullscreen\|hidden\|custom, layout?}` | `addCameraRegion(atTime:type:)` (`+CameraRegions.swift:115`), `updateCameraRegionType` (`:152`), `updateCameraRegionLayout` (`:28`), `updateCameraRegionStyle` (`:80`), `updateCameraRegionTransition` (`:101`) | yes | Camera track chip; PiP moves |
| `set_camera_layout` | `{corner?: topLeft…, relativeWidth?, cornerRadius?, border?, shadow?, mirrored?}` | `setCameraCorner` (`+CameraLayout.swift:4`), `cameraLayout`, `cameraCornerRadius`… (`EditorState.swift:13, 33-39`) | yes | PiP |
| `set_background` | `{style: none\|solid\|gradient\|image, color?, gradientId?, imagePath?}` | `backgroundStyle` (`EditorState.swift:27`), `setBackgroundImage(from:)` copies the file into the bundle (`+Background.swift:5-22`); image path must be inside the workspace or bundle | yes | SwiftUI background behind the preview |
| `set_canvas` | `{aspect?, padding?, cornerRadius?, shadow?}` | `canvasAspect`, `padding`, `videoCornerRadius`, `videoShadow` (`EditorState.swift:30-37`) | yes | preview reflows |
| `set_caption_style` | `{fontSize?, weight?, textColor?, background?, position?, wordsPerLine?, enabled?}` | `captionFontSize…captionMaxWordsPerLine` (`EditorState.swift:109-121`) | yes | caption overlay |
| `generate_captions` / `clear_captions` | `{language?, source?}` / `{}` | `generateCaptions()` (`+Captions.swift:12`, async, already pushes its own snapshot at `:65`), `clearCaptions()` (`:82`) | yes (dispatcher awaits `isTranscribing == false`, no second push) | transcription progress |
| `set_volume` | `{track: system\|mic, volume?, muted?, noiseReduction?}` | `systemAudioVolume…micNoiseReductionIntensity` (`EditorState.swift:93-98`), `syncAudioVolumes()` (`+AudioRegions.swift:112`) | yes | audio tab; playback volume |
| `set_audio_regions` | `{track, regions:[{start,end}]}` | `setRegions(_:for:)` (`+AudioRegions.swift:13`) | yes | audio track |
| `set_cursor` | `{show?, style?, size?, clickHighlights?, clickSound?}` | `showCursor…clickSoundStyle` (`EditorState.swift:48-67`) | yes | cursor overlay |
| `undo` / `redo` / `jump_to_history` | `{}` / `{}` / `{index}` | `undo()`, `redo()` (`+Persistence.swift:322-330`), `jumpToHistory(index:)` (`:332`) | n/a | same as the user pressing the shortcut |
| `begin_batch` / `end_batch` | `{label}` / `{}` | dispatcher flag: mutations inside a batch do not push; `end_batch` pushes one entry with the batch label | one for the batch | badge shows the batch label |

### 3.3 New primitives (do not exist yet; see §7)

| Tool | Input sketch | Needs |
| --- | --- | --- |
| `add_text` / `update_text` / `remove_text` | `{text, start, end, position:{x,y}, size?, weight?, color?, background?, animation?: fade\|slide\|scale}` | text overlay primitive (§7.1) |
| `add_image` / `remove_image` | `{path, start, end, rect:{x,y,w,h}, cornerRadius?, animation?}` | image overlay primitive (§7.2); file copied into the bundle like `setBackgroundImage` |
| `add_blur` / `remove_blur` | `{start, end, rect:{x,y,w,h}, radius?}` | blur region primitive (§7.3) |
| `set_transition` | `{targetId, entry?, exit?, duration?}` | generalises `RegionTransitionType` (`ProjectMetadata.swift:87-100`) to overlays and keep-slices (§7.4) |
| `remove_silences` | `{thresholdDb?, minGapSeconds?, padding?: 0.15, dryRun?}` | `get_silences` + keep-slices (§7.5); `dryRun` returns the gaps without mutating |
| `add_music` / `set_music` / `remove_music` | `{path, start?, volume?, fadeIn?, fadeOut?, duckUnderSpeech?}` | music tracks from spike 02 (§7.6) |

---

## 4. Feedback loop

### 4.1 What the agent sees

- Every mutating tool returns the compact timeline (`get_timeline` summary: duration, trim, counts and `[start,end]` lists per track, zoom regions, history index and label). This keeps the runtime's context small and lets it verify its own step without a second call.
- `render_preview_frame` returns a PNG path inside the workspace; the runtime reads it with its own file tools (Claude Code can view images; for Codex the path is still useful for the user).
- `export_draft` produces a small MP4 for a final check; gated (§6).
- Errors are structured and never partial: the dispatcher validates arguments against the catalog schema and clamps times to `[0, duration]` before touching state, so `didMutate` is false on every rejection.

### 4.2 What the user sees

| Signal | Mechanism |
| --- | --- |
| "Agent is editing" badge | new `EditorState.agentActivity: AgentActivity?` (`struct {label, startedAt, batchDepth}`) rendered as a pill in `EditorTopBar` (`Reframed/Editor/EditorTopBar.swift:3-32`) using `ReframedColors` and `FontSize` tokens; deliberately not listed in `observeChanges()` so it never triggers a save or snapshot |
| Last change highlighted | `EditorState.lastAgentChange: (track: String, start: Double, end: Double)?` drawn as a translucent band in `TimelineView+Overlays.swift`, fading after 2 s |
| Playhead follows | dispatcher calls `seek(to:)` (`+Playback.swift:41`) to the start of the changed range when playback is paused |
| Step log | the chat panel (spike 03) renders each `tools/call` as a row: label, elapsed time, undo button that calls `jump_to_history(index-1)` |
| History labels | `HistoryEntry` gains `var label: String?` (synthesized Codable decodes a missing key as `nil`, so existing `history.json` still loads); `HistoryPopover` shows `"Agent: <label>"` before the diff text from `describeChanges` |

### 4.3 Undo granularity

- **One snapshot per tool call, pushed explicitly** by the dispatcher (the same pattern as `generateCaptions`, `+Captions.swift:65`), with the label. The debounced `scheduleUndoSnapshot()` still fires 1.5 s later from `observeChanges` and would push a duplicate; fix by making `EditorStateData: Equatable` (all members already are, except the struct itself) and having `History.pushSnapshot` skip when the new snapshot equals the current entry. This also removes the existing double push after `generateCaptions` and drag end.
- **Batches.** `begin_batch`/`end_batch` suppress per-call pushes so "structure this demo" is one undo step; the dispatcher auto-ends a batch on session end or after a 5-minute timeout so the user is never left without a snapshot.
- **User undo during a batch** restores the pre-batch snapshot and cancels the batch; the tool result tells the agent (`{ok:false, code:"USER_UNDO"}`) so it re-reads the timeline instead of continuing blind.

---

## 5. Skills

### 5.1 What a skill is per runtime

Both runtimes implement the same open format: a folder with `SKILL.md` whose YAML frontmatter has `name` and `description`, body in Markdown, loaded on demand when the description matches or the user invokes it (`agent-skills-strategy.md` §1–3). Differences that matter here:

| | Claude Code | Codex |
| --- | --- | --- |
| Project location | `<cwd>/.claude/skills/<name>/SKILL.md` | `<cwd>/.agents/skills/<name>/SKILL.md`, searched up to the repo root |
| Always-on guidance | `CLAUDE.md` | `AGENTS.md` |
| Extra metadata | frontmatter `allowed-tools`, `disable-model-invocation` | `agents/openai.yaml` (may declare MCP tool dependencies) |
| Invocation | `/name` or automatic | `$name`, `/skills`, or automatic |

### 5.2 Where the app ships them and how they reach the runtime

- Canonical source: `Reframed/Agent/Skills/<name>/SKILL.md` in the repo, copied into `Reframed.app/Contents/Resources/skills/` at build time (a folder reference, no code).
- At chat-session start the app materializes the workspace: `<workspace>/.claude/skills/<name>/` and `<workspace>/.agents/skills/<name>/` (real copies, not symlinks, since Toone's parser precedent rejects symlinked skills, `SkillParserService.swift:27-35`), plus `<workspace>/AGENTS.md` with the always-on rules from §6 and a `CLAUDE.md` symlink to it (the convention this repo already uses, ADR 0007). Re-materialized on every launch so app updates propagate; user edits inside the workspace are overwritten, which is the intended contract for v1.
- Each `SKILL.md` names only tools in the catalog; a test enforces that (ATTACK-PLAN phase 11).

### 5.3 First set

| Skill | Purpose | Tools used | Checks it performs before finishing |
| --- | --- | --- | --- |
| `presentation-cut` | Turn a raw flow into a structured demo: intro, 3–6 chapters, outro | `get_project`, `get_transcript`, `get_click_clusters`, `get_silences`, `begin_batch`, `set_keep_slices` (or `add_cut`), `add_zoom`, `add_spotlight`, `add_text`, `set_background`, `set_canvas`, `end_batch`, `render_preview_frame` | total kept duration within the requested target; no chapter shorter than 3 s; no zoom overlapping a cut boundary; a preview frame rendered at each title card; timeline re-read after the batch |
| `remove-silences` | Remove dead air and long pauses | `get_silences` (dry run), `remove_silences`, `get_timeline` | never removes a gap that contains a click or a transcript word; keeps `padding` of speech; reports seconds removed and asks before removing more than 40 % |
| `spotlight-clicks` | Highlight every meaningful click cluster | `get_click_clusters`, `add_spotlight`, `add_zoom` | one spotlight per cluster, radius scaled to cluster spread; skips clusters inside removed ranges; cursor must be shown (`set_cursor {show:true}`) or the export drops spotlights (`EditorState+Export.swift:201`) |
| `add-title-cards` | Title, chapter and outro cards from the transcript | `get_transcript`, `add_text`, `set_transition` | text fits the safe area for the current `canvasAspect`; card duration 2–3 s; no overlap with captions position |
| `music-bed` | Lay a music track under the narration | `add_music`, `set_music`, `set_volume` | ducks under speech using transcript word ranges; fade-in/out at trim edges; never louder than −18 dBFS relative to mic |

---

## 6. Safety

### 6.1 What the agent must never do

| Rule | Enforcement |
| --- | --- |
| Never delete or rewrite source recordings, `project.json`, or `history.json` | no tool touches files; media-adding tools copy into the bundle via the existing `setBackgroundImage` pattern (`+Background.swift:5-22`) and only from paths inside the workspace or user-picked paths; `deleteRecording` (`+Project.swift:5`) and `renameProject` (`:48`) are not exposed |
| Never export over user files | `export_draft` writes only under `<workspace>/drafts/` (seam S3); full export stays a user action per the owner's assumption in `00-overall-plan.md` |
| Never run shell against the bundle | Claude Code: `--disallowedTools Bash Write Edit` plus `--strict-mcp-config` (`ClaudeCommandBuilder.swift:59-72`); Codex: default sandbox (read-only workspace), never `--dangerously-bypass-approvals-and-sandbox` (what Toone uses for its own agents, `AIProvider.swift:74`, is explicitly not copied) |
| Never see other projects | the socket token binds to one `EditorWindow`; `get_project` is the only path returned |
| Never leave state half-applied | argument validation and clamping before mutation; a tool that throws mid-way calls `restoreFromSnapshot` on the pre-call snapshot |

### 6.2 Allowed-tools configuration

| Runtime | Auto-approved | Requires confirmation in the chat panel | Denied |
| --- | --- | --- | --- |
| Claude Code | `--allowedTools "mcp__reframed__get_*" "mcp__reframed__render_preview_frame" "mcp__reframed__add_*" … (all catalog tools except the gated ones)` | `export_draft`, `add_music`/`add_image`/`set_background {image}` with a path outside the workspace, `clear_captions`, `remove_silences` without `dryRun` when > 40 % would go | `Bash`, `Write`, `Edit`, `WebFetch`, `WebSearch`; `Read`/`Glob`/`Grep` allowed only inside the workspace (default project scoping) |
| Codex | `-c mcp_servers.reframed.tools.<name>.approval_mode="approve"` for the same set (`CodexMCPOverrideBuilder.swift:80-85` pattern) | same tools left at the default approval mode, surfaced by the chat panel | workspace sandbox read-only; no network |

Confirmation is implemented app-side too: gated tools return `{ok:false, code:"NEEDS_CONFIRMATION", confirmationId}` until the user clicks Allow in the panel, then the runtime retries with `confirmationId`. This keeps the guarantee even if a runtime's approval flag changes.

---

## 7. Missing editor primitives and their rendering paths

Each row follows the 12-site checklist in `06-conventions-checklist.md`. "Model" is a `*Data` struct in `ProjectMetadata.swift` with an optional `EditorStateData` field; "State" is the `EditorState` array plus `observeChanges`, `createSnapshot`, `restoreFromSnapshot`, `init/setup` load, and a `regions(...)` change rule.

| # | Primitive | Model + state | `CompositionInstruction` / builder | `FrameRenderer+*` | Preview mirror | Timeline |
| --- | --- | --- | --- | --- | --- | --- |
| 7.1 | Text overlay | `TextOverlayData {id, start, end, text, relativeX/Y, fontSize, weight, textColor, backgroundColor?, animation?}`; `EditorState.textOverlays` | `let textOverlays: [TextOverlayData]`, font size scaled like captions (`CaptionLayout.scaledFontSize`, `ProjectMetadata.swift:215-223`) | new `FrameRenderer+TextOverlays.swift` drawn after `+Spotlight`, before `+Captions` (`FrameRenderer.swift:320-330`); reuse CoreText measuring from `+Captions`; HDR variant in `+HDR.swift:577` pattern | `CATextLayer` per overlay in a new `VideoPreviewContainer+TextOverlays.swift`, updated from `updateOverlays` (`VideoPreviewView+Update.swift:200`) | new "Text" track modeled on `TimelineView+SpotlightTrack.swift` |
| 7.2 | Image overlay | `ImageOverlayData {id, start, end, filename, rect, cornerRadius, animation?}`; file `overlay-<id>.<ext>` in the bundle (pattern `+Background.swift:12-21`) | `let imageOverlays: [(ImageOverlayData, CGImage)]` rasterized in the builder like `backgroundImage` | same stage as text; `drawRoundedShadow` + clip from `FrameRenderer+Helpers.swift:212` | `CALayer.contents` | same track as text ("Overlays") |
| 7.3 | Blur region | `BlurRegionData {id, start, end, rect (0–1 in source coords), radius}` | `let blurRegions` | inside `drawScreenVideo` (`FrameRenderer+Screen.swift:5`) before the zoom crop, so the rect stays in source coordinates; `CIGaussianBlur` on the sub-image via the static `CIContext` precedent in `+HDR.swift` | a `CALayer` with `CIFilter` `gaussianBlur` and a mask over `screenPlayerLayer` (`VideoPreviewContainer+Layout.swift`) | "Blur" chips on the Screen track or the Overlays track |
| 7.4 | Transitions / animations | extend `RegionTransitionType` (`ProjectMetadata.swift:87-100`) with `entry/exit` fields on overlays and keep-slices | reuse `RegionTransitionInfo` (`CompositionInstruction.swift:4-10`) | reuse `computeRegionTransition`/`resolveActiveTransitionType` (`FrameRenderer+Helpers.swift:41-77`) for opacity/scale/slide of overlays | reuse `VideoPreviewView+Transitions.swift` | edit popover like `VideoRegionEditPopover` |
| 7.5 | Silence detection | none persisted; `SilenceDetector.detect(samples:sampleRate:thresholdDb:minGap:) -> [(start,end)]` in `Reframed/Editor/SilenceDetector.swift` (T1) over `AudioWaveformGenerator.extractSamples` (S7) | n/a | n/a | n/a | results become keep-slices (spike 01) or, until then, `videoRegions` |
| 7.6 | Music tracks (spike 02) | `MusicTrackData {id, filename, timelineStart, sourceStart, duration, volume, muted, fadeIn, fadeOut}` | `VideoCompositor.AudioSource(url:regions:volume:)` (`VideoCompositor.swift:9-13`) gains fades; mixed in `+Audio.swift` | n/a | extra `AVPlayer` in `SyncedPlayerController` | Music track |
| 7.7 | Keep-slices (spike 01) | replaces the "cut out" semantics of `videoRegions` with kept ranges; remap already exists (`VideoCompositor+RegionRemapping.swift`) | `videoSegmentMappings` (`CompositionInstruction.swift:81`) | none | `handlePreviewGapSkip` (`SyncedPlayerController.swift:191`) | Screen sub-track |

Top three by leverage for the target demo: **silence detection** (needs only T1 code plus keep-slices), **text overlay** (title cards are what makes it "a presentation"), **blur region** (the only way to make screen recordings shareable). Image overlay reuses 90 % of text; transitions reuse existing helpers.

---

## 8. One tool call, from chat to timeline

```
 chat panel (spike 03)     runtime child process        reframed-mcp shim        Reframed.app
 EditorView left panel     (claude / codex)             (stdio <-> unix socket)  AgentBridgeServer (actor)   AgentToolDispatcher (@MainActor)   EditorState / SwiftUI
 ────────────────────      ─────────────────────        ───────────────────────  ────────────────────────    ────────────────────────────────    ───────────────────────
  user: "spotlight the
  first click" ──stdin──►  decides tools/call
                           add_spotlight{start:3.2,
                           end:6.0,label:"…"} ─stdout─► JSON-RPC line ──socket──► verify token + editorId
                                                                                  decode request
                                                                                  await MainActor.run ───────► validate args vs catalog
                                                                                                               clamp to [0,duration]
                                                                                                               pre = createSnapshot()
                                                                                                               agentActivity = "Spotlight 3.2–6.0"  ─► badge appears (EditorTopBar)
                                                                                                               addSpotlightRegion(atTime:)          ─► @Observable write
                                                                                                               updateSpotlightRegionStart/End       ─► TimelineView+SpotlightTrack redraws
                                                                                                               spotlightEnabled = true              ─► VideoPreviewView.updateNSView
                                                                                                               seek(to: 3.2)                        ─►   → updateOverlays → SpotlightOverlayLayer
                                                                                                               pendingUndoTask?.cancel()
                                                                                                               history.pushSnapshot(createSnapshot(),
                                                                                                                 label: "Agent: Spotlight 3.2–6.0")  ─► HistoryPopover row
                                                                                                               lastAgentChange = (spotlight,3.2,6.0) ─► highlight band, fades 2 s
                                                                                                               observeChanges onChange (async) → scheduleSave 1 s → project.json
                                                                                  ◄── {ok, historyIndex,
                                                                                       label, timeline}
                                                        ◄──socket── response ◄──
  panel shows step row     ◄─stdout─ tool_result
  "Spotlight 3.2–6.0 ↶"    continues the turn …
```

---

## 9. Risks

| Risk | Mitigation |
| --- | --- |
| The debounced snapshot (1.5 s) duplicates the explicit one | `EditorStateData: Equatable` + dedupe in `pushSnapshot` (§4.3); test it |
| A property added to `EditorState` for the badge accidentally triggers autosave | keep `agentActivity`/`lastAgentChange` out of `observeChanges()`; a test diffs the observed list against `createSnapshot()` fields (hazard 9 in `02-concurrency.md`) |
| Runtime hangs on a long tool (transcription minutes, export) | per-tool timeout in the bridge; long tools report progress through the badge and return early with `{status:"running", jobId}` plus `get_job` polling if the timeout is hit |
| Two editor windows open | token bound to `EditorWindow`; one session per window; `SessionState.editorWindows` lookup |
| Shim and app version skew | the shim sends its bundle version in `initialize`; the app refuses mismatches with a clear error |
| Codex/Claude Code flag drift (`--allowedTools`, `approval_mode`) | app-side confirmation gate (§6.2) is the real boundary; flags are convenience |
| Codex sandbox blocks the Unix socket | verify on the installed Codex; fallback is a loopback TCP port with the same token (Toone's `9876` pattern) |
| `.frm` bundle grows with overlay images and drafts | drafts and frames live in the workspace, never the bundle; overlay images are the only bundle additions |

---

## 10. Questions for the owner

1. Workspace location: `<projectFolder>/.agent/<bundle-name>/` (assumed) or inside the `.frm` bundle? Inside would travel with the project but bloats it with drafts and frames.
2. May the agent trigger a full export after confirmation, or is `export_draft` (low-res, workspace-only) the ceiling? Assumed: draft only.
3. Should agent edits be a single undo step per chat turn (batch by default) or per tool call (assumed per call, with explicit batches)?
4. Transport phase 2: is it worth verifying HTTP MCP on both runtimes now, or ship the Swift shim and revisit? Assumed: shim first.
5. Is the "Agent is editing" badge enough, or should the timeline lock user input while a batch is running? Assumed: no lock; user undo cancels the batch.
6. Skills: ship only the five above, or also a `walkthrough-narration` skill that rewrites captions? Assumed: five.
