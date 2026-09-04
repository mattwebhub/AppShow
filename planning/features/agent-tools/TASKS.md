# Tasks: Agent tools (read-only)

One commit per phase; every phase starts red.

- [x] P0 Planning: spec, test plan, tasks, milestone plan and verify.
- [ ] P1 JSON: red `JSONValueTests`, `JSONRPCCodecTests`; green `JSONValue.swift`, `JSONRPC.swift`; pbxproj group `AppShow/Agent/Tools`.
- [ ] P2 Catalog: red `AgentToolCatalogTests`, `AgentToolResultTests`; green `AgentTool.swift`, `AgentToolCatalog.swift`, `AgentToolSummaries.swift`, `AgentToolCursorActivity.swift`, `AgentToolHandlers.swift`, `AgentToolPreviewFrame.swift`.
- [ ] P3 Dispatcher: red `AgentToolDispatcherTests`; green `AgentToolDispatcher.swift` (schema validation, mutation refusal, unknown tool, preview frame end to end).
- [ ] P4 Transport: red `AgentBridgeServerTests`, `AgentWorkspaceTests`; green `AgentRPCSession.swift`, `AgentBridgeServer.swift`, `AgentWorkspace.swift`.
- [ ] P5 Shim executable and chat-panel wiring (next milestone; design recorded in `SPEC.md`).
