# Milestone 05: agent-tools-readonly

Goal: a client connected to the editor's Unix socket with the session token can list the read-only tool catalog and call every tool against the open project, getting structured JSON (and a PNG frame) without any change to the project.

Depends on: milestone 03 (external audio tracks in the timeline summary); milestone 01 fixtures. Independent of milestone 04 (the chat panel spawns the runtime later; tests talk to the socket directly).

## Tasks

- [x] T1. JSON value and JSON-RPC codec. Proof: `ReframedTests/Agent/JSONValueTests.swift`, `JSONRPCCodecTests.swift`.
- [x] T2. Tool catalog as data with schemas and MCP `tools/list`. Proof: `AgentToolCatalogTests.swift`.
- [x] T3. Read-only summaries (timeline, transcript, cursor activity, history) as pure builders. Proof: `AgentToolResultTests.swift`.
- [x] T4. Dispatcher with argument validation, mutation refusal, preview frame. Proof: `AgentToolDispatcherTests.swift`.
- [x] T5. Socket transport with token auth and per-call timeout; workspace folder with `session.json`. Proof: `AgentBridgeServerTests.swift`, `AgentWorkspaceTests.swift`.
- [x] T6. Planning docs, `upstream-sync.md` line, `STATE.md`. Proof: grep.
- [ ] T7. VERIFY.md run, branch pushed, PR opened.

## Out of scope

Mutating tools, batches, history labels, badge, confirmations, skills, the `reframed-mcp` shim, `get_silences`, `export_draft`, HTTP transport.

## Risks

- `sun_path` limit (104 bytes) on long project folders: socket path falls back to `ReframedPaths.temp`; `session.json` is the source of truth.
- Concurrent milestone 04 worktree adds `Reframed/Agent/` and `AgentJSONValue`: this milestone uses `Reframed/Agent/Tools/`, the `JSONValue` name, and pbxproj ids `7E57…B0` to `CF`; the merge conflict is limited to adjacent lines in the pbxproj.
- `render_preview_frame` duplicates the `ExportConfiguration` assembly from `EditorState+Export.swift` because that file is upstream; keep the two in step when a visual property is added.
