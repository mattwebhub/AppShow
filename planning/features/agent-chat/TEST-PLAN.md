# Test plan: Agent chat panel

Assertions per phase in `docs/features/03-agent-chat/ATTACK-PLAN.md`.

| Spec # | Test suite | Layer | File | Fixture | Status |
|--------|-----------|-------|------|---------|--------|
| 3, 6 | `ClaudeCodeProviderTests` arguments, resume, stream parsing | unit T1 | `ReframedTests/Agent/ClaudeCodeProviderTests.swift` | recorded NDJSON | red |
| 3, 6 | `CodexProviderTests` arguments, resume, stream parsing | unit T1 | `ReframedTests/Agent/CodexProviderTests.swift` | recorded NDJSON | red |
| 3, 4 | `AgentProcessRunnerTests` with a fake executable script: streams lines, exit codes, cancellation terminates | T2 | `ReframedTests/Agent/AgentProcessRunnerTests.swift` | shell script in temp dir | red |
| 5 | `AgentTranscriptTests` model reduction from events, persistence round trip under `agent/` | T1 / T2 | `ReframedTests/Agent/AgentTranscriptTests.swift` | temp bundle | red |
| 1 | `AgentPanelStateTests` width clamp, collapse persistence via `StateService` | T1 / T2 | `ReframedTests/Agent/AgentPanelStateTests.swift` | temp home | red |
| 3 | `AgentMarkdownParserTests` blocks, fences, tables, streaming partials | unit T1 | `ReframedTests/Agent/AgentMarkdownParserTests.swift` | none | red |
| 2 | `AgentReadinessTests`, `AgentToolchainTests` PATH resolution with a fake PATH | T1 / T2 | `ReframedTests/Agent/...` | temp dir | red |
| 7 | `AgentSecurityTests` grep-style test that forbids permission-bypass flags in the argument builders | unit T1 | `ReframedTests/Agent/AgentSecurityTests.swift` | none | red |
| 5 | `AgentThreadStoreTests` create, rename, switch, delete | T2 | `ReframedTests/Agent/AgentThreadStoreTests.swift` | temp bundle | red |

## Manual checks

Panel look and feel against the design tokens, collapse animation, streaming feel with a real CLI, cancel mid-turn, not-logged-in guidance, behavior during an export.
