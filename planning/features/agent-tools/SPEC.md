# Feature: Agent tools (read-only)

Status: complete
Milestone: 05 (read-only inspection); mutating tools follow in milestone 06, primitives in 07

## Problem

The chat panel from milestone 04 runs a coding-agent runtime against the open project but the runtime cannot see the project. This feature gives the runtime a small, typed tool surface over the editor that is open on screen: it can describe the recording, the timeline, the transcript, the cursor activity, the history, and render a still frame, all without changing anything. The same catalog, dispatcher, and transport carry the mutating tools of milestone 06.

## Behavior

1. A JSON value type (`JSONValue`) and a JSON-RPC 2.0 codec (`JSONRPC*`) exist in `AppShow/Agent/Tools/`; both are `Sendable`, decode tolerantly (missing `jsonrpc`, int or string ids, absent params), and frame messages as newline-delimited JSON.
2. `AgentToolCatalog.all` lists every tool as data: `name` (`snake_case`, unique), `description`, `inputSchema` (JSON Schema object with `additionalProperties: false`), `mutating`, `slow`, `availability`. `AgentToolCatalog.available` excludes tools whose backing code is not integrated. `tools/list` advertises only available tools in MCP shape (`name`, `description`, `inputSchema`, `annotations.readOnlyHint`).
3. Read-only catalog for this milestone (times in source seconds, ids are the region UUIDs from `EditorStateData`):

   | Tool | Input | Output |
   | --- | --- | --- |
   | `get_project_summary` | `{}` | `{name, bundlePath, workspacePath?, duration, fps, screenSize{width,height}, webcam{present,enabled,size?}, hasSystemAudio, hasMicAudio, hasCursorMetadata, isHDR, captureMode?, createdAt, history{index,count}}` |
   | `get_timeline` | `{detail?: "summary"\|"full"}` | the compact timeline below; `full` adds `snapshot` (the `EditorStateData` JSON) |
   | `get_transcript` | `{withWords?: bool, from?: number, to?: number}` | `{enabled, source, language, count, segments:[{id,start,end,text,words?:[{word,start,end}]}], hint?}`; `from`/`to` keep segments that overlap the range; `hint` explains how to get captions when there are none |
   | `get_cursor_activity` | `{dwellSeconds?: number (default 0.5), from?, to?}` | `{available, sampleRateHz?, clickCount, clickClusters:[{start,end,x,y,clicks}], keystrokeBursts:[{start,end,count}]}`; clusters group clicks whose gap is under `dwellSeconds` (the `ZoomDetector` rule), bursts group key-down events with gaps under 1 s |
   | `get_history` | `{}` | `{index, count, canUndo, canRedo, entries:[{index, timestamp, label, changes:[String], isCurrent}]}`; `label` is the first line of `History.describeChanges` between consecutive snapshots ("Initial state" for the first) until `HistoryEntry.label` lands in milestone 06 |
   | `render_preview_frame` (slow) | `{atSeconds: number ≥ 0, width?: integer 16…1920 (default 640)}` | `{path, width, height, atSeconds}`; PNG under `<workspace>/frames/`, rendered through `VideoCompositor.buildCompositionInstruction` + `FrameRenderer.renderFrame` from the current state (background, canvas, padding, corner radius, camera regions, cursor, zoom, spotlight, captions); the playhead seeks to `atSeconds` when playback is paused |
   | `export_draft` (slow) | `{maxWidth?: integer 320…640, fps?: integer 10…30}` | `{path, maxWidth, fps}`; MP4 under `<workspace>/drafts/`, capped without upscaling, and never written to a user-selected path |
   | `get_silences` (slow) | `{thresholdDb?, minGapSeconds?, source?}` | detected silent ranges and total duration for the selected captured-audio source |

   Compact timeline shape returned by `get_timeline` and, from milestone 06, by every mutating tool:

   ```json
   {
     "duration": 2.0,
     "trim": {"start": 0, "end": 2.0},
     "cuts": {"hasCuts": false, "keptDuration": 2.0,
              "slices": [{"id": "…", "start": 0, "end": 2.0, "entryTransition": "fade", "exitTransition": "none"}],
              "gaps": [{"start": 0.5, "end": 1.5}]},
     "zoom": {"enabled": false, "autoZoom": false, "level": 2.0, "keyframes": [{"t": 0.4, "level": 2.0, "x": 0.5, "y": 0.5, "auto": true}]},
     "spotlight": {"enabled": false, "regions": [{"id": "…", "start": 0.4, "end": 1.1, "radius": 120, "dimOpacity": 0.55, "edgeSoftness": 20, "fadeDuration": 0.3}]},
     "camera": {"present": true, "enabled": true, "regions": [{"id": "…", "start": 0, "end": 0.5, "type": "fullscreen", "entryTransition": "fade", "exitTransition": "scale"}]},
     "captions": {"enabled": true, "count": 2, "segments": [{"id": "…", "start": 0.3, "end": 0.9, "text": "hello there world"}]},
     "audio": {"system": {"present": true, "muted": false, "volume": 1.0, "regions": [{"start": 0, "end": 2.0}]},
               "mic": {"present": false, "muted": false, "volume": 1.0, "regions": []},
               "external": [{"id": "…", "name": "Bed", "start": 0.5, "end": 1.5, "fileIn": 0, "fileOut": 1.0, "volume": 1.0, "muted": false, "fadeIn": 0, "fadeOut": 0}]},
     "background": {"type": "solid", "color": "#000000"},
     "canvas": {"aspect": "original", "padding": 0, "cornerRadius": 0, "shadow": 0},
     "history": {"index": 0, "count": 1}
   }
   ```

   `background.type` is `none`, `solid` (+ `color`), `gradient` (+ `gradientId`), or `image` (+ `filename`). Optional keys are omitted when nil.
4. `AgentToolDispatcher` (`@MainActor`) is bound to one `EditorState` and a frames directory. `call(name, arguments)` validates the arguments against the tool schema before touching state (object shape, required keys, no unknown keys, primitive types, `enum`, `minimum`/`maximum`), refuses every tool flagged `mutating` in this milestone, answers unknown names with the JSON-RPC method-not-found error, and never pushes a history entry.
5. Errors are structured. `AgentToolError` carries a JSON-RPC code and a string code: `UNKNOWN_TOOL` (-32601), `TOOL_ARGUMENTS_INVALID` (-32602), `MUTATION_NOT_ALLOWED` (-32003), `TOOL_UNAVAILABLE` (-32004), `TOOL_TIMEOUT` (-32005), `TOOL_FAILED` (-32000). Over the wire the first five are JSON-RPC error responses; `TOOL_FAILED` is an MCP result with `isError: true` so the runtime can read the message.
6. Transport: `AgentBridgeServer` (actor) listens on a Unix domain socket with `NWListener` and speaks newline-delimited JSON-RPC. Methods: `initialize` (requires `params.token` equal to the session token; wrong token answers `UNAUTHORIZED` (-32001) and closes the connection), `notifications/initialized`, `ping`, `tools/list`, `tools/call`. Any other request before `initialize` answers `NOT_INITIALIZED` (-32002). `tools/call` hops to the dispatcher on the main actor and applies a timeout (30 s, 10 min for slow tools). One `AgentRPCSession` per connection holds the authorization state.
7. Workspace: `AgentWorkspace.create(forBundle:)` makes `<projectFolder>/.agent/<bundle-name>/` with a `frames/` folder and writes `session.json` (mode 0600) holding `socketPath`, `token`, `bundlePath`, `workspacePath`, `protocolVersion`, `createdAt`. The socket is `<workspace>/bridge.sock` when that path fits the 104-byte `sun_path` limit, otherwise `AppShowPaths.temp/agent/<12 hex>.sock`; `session.json` always says which. `close()` removes `session.json` and the socket file and leaves `frames/` in place.
8. Nothing in this feature imports SwiftUI or touches upstream files other than `AppShow.xcodeproj/project.pbxproj`.

## Stdio shim (implemented in milestone 06)

The runtime spawns MCP servers itself, so the app cannot own a stdio server. Milestone 06 adds a command-line target `appshow-mcp` (Foundation only, under 150 lines, copied to the app's `Contents/Helpers/` by a Copy Files phase, signed with the app):

1. Reads `APPSHOW_AGENT_SOCKET` and `APPSHOW_AGENT_TOKEN` from its environment (the chat panel writes them into the runtime's MCP config from `session.json`).
2. Opens `NWConnection(to: .unix(path:), using: .tcp)` and fails fast with a JSON-RPC error on stdout if the socket is gone.
3. Reads stdin line by line. For the one request whose `method` is `initialize` it decodes the object, sets `params.token`, and re-encodes; every other line is forwarded byte for byte.
4. Relays every line received from the socket to stdout unchanged and flushes after each line.
5. Exits when stdin closes (runtime ended the session) or when the socket closes (editor window closed), whichever comes first; the exit code is 0 on stdin close and 1 on socket loss.

As implemented, the third `PBXNativeTarget` compiles `Tools/appshow-mcp/main.swift`, inherits `Config.xcconfig`, is an app dependency, and is signed on copy into `Contents/Helpers`. `make test-shim` runs the gated real-process integration test.

## Not doing

- Mutating tools, batches, history labels, the editing badge, confirmations (milestone 06).
- HTTP transport. The authenticated Unix socket plus signed stdio shim is the implemented boundary.
- Any change to `EditorState`, `History`, `AppShowProject`, or the compositor.

## Touch points

New files, all ours, under `AppShow/Agent/Tools/` (registered in a `AppShow/Agent/Tools` `PBXGroup` with ids `7E57…B0` to `7E57…CF` so the concurrent `AppShow/Agent` group from milestone 04 merges cleanly): `JSONValue.swift`, `JSONRPC.swift`, `AgentTool.swift`, `AgentToolCatalog.swift`, `AgentToolSummaries.swift`, `AgentToolCursorActivity.swift`, `AgentToolHandlers.swift`, `AgentToolPreviewFrame.swift`, `AgentToolDispatcher.swift`, `AgentRPCSession.swift`, `AgentBridgeServer.swift`, `AgentWorkspace.swift`. Tests under `AppShowTests/Agent/`. Read-only use of upstream types: `EditorState` and its extensions, `CutTimeline`, `CursorMetadataProvider`, `History`, `AppShowProject`, `VideoCompositor.buildCompositionInstruction`, `FrameRenderer.renderFrame`.
