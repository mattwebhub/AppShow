# Test plan: Agent tools (read-only)

Assertions condensed from `docs/features/04-agent-tools/ATTACK-PLAN.md` phases 1 to 3; layer names from `planning/tdd-strategy.md`.

| Spec # | Test suite | Layer | File | Fixture | Status |
|--------|-----------|-------|------|---------|--------|
| 1 | `JSONValueTests` literals, round trip, subscripts, typed accessors, sorted-key encoding, Encodable bridge | unit T1 | `ReframedTests/Agent/JSONValueTests.swift` | none | red |
| 1 | `JSONRPCCodecTests` request decode (int/string/null id, absent params, missing jsonrpc), response encode, error encode, line buffer partial frames, invalid JSON → parse error | unit T1 | `ReframedTests/Agent/JSONRPCCodecTests.swift` | none | red |
| 2, 3 | `AgentToolCatalogTests` unique snake_case names, object schemas with `additionalProperties: false`, no mutating tools, pending tool excluded from `tools/list`, MCP list JSON round trip, expected names present | unit T1 | `ReframedTests/Agent/AgentToolCatalogTests.swift` | none | red |
| 3 | `AgentToolResultTests` timeline summary from `fullEditorState`, cuts gaps and kept duration, transcript window and words, click clusters and keystroke bursts, history entries, MCP result wrapping | unit T1 | `ReframedTests/Agent/AgentToolResultTests.swift` | `ProjectFixtures` values | red |
| 4, 5 | `AgentToolDispatcherTests` summary reflects cuts and tracks, transcript empty vs populated, unknown tool error, invalid arguments rejected, mutating handler refused, pending tool unavailable, no history entry after read-only calls, preview PNG size and background pixel | T2 `@MainActor` `.serialized` | `ReframedTests/Agent/AgentToolDispatcherTests.swift` | `ProjectFixtures.recordingResult` + `ReframedProject.create(cleanupTemp: false)` | red |
| 6 | `AgentBridgeServerTests` wrong token → -32001 and closed, right token → `tools/list` catalog, `tools/call get_project_summary` JSON, request before initialize → -32002, slow tool → `TOOL_TIMEOUT` | T2 `.serialized` | `ReframedTests/Agent/AgentBridgeServerTests.swift` | fixture project, temp socket | red |
| 7 | `AgentWorkspaceTests` folder next to bundle, `session.json` contents and mode, short vs long socket path rule, close removes session and socket, frames folder kept | T2 | `ReframedTests/Agent/AgentWorkspaceTests.swift` | temp bundle path | red |

## Manual checks

None for this milestone: no UI is wired and no runtime is spawned. The first manual check (runtime `/mcp` lists `reframed`) belongs to the shim phase.
