# Test plan: Agent chat panel

Assertions per phase in `docs/features/03-agent-chat/ATTACK-PLAN.md`.

| Spec # | Test suite | Layer | File | Fixture | Status |
|--------|-----------|-------|------|---------|--------|
| 3, 6 | `ClaudeCodeProviderTests` arguments, resume, stream parsing | unit T1 | `AppShowTests/Agent/ClaudeCodeProviderTests.swift` | recorded NDJSON | green |
| 3, 6 | `CodexProviderTests` arguments, resume, stream parsing | unit T1 | `AppShowTests/Agent/CodexProviderTests.swift` | recorded NDJSON | green |
| 3, 4 | `AgentProcessRunnerTests` with a fake executable script: streams lines, exit codes, cancellation terminates | T2 | `AppShowTests/Agent/AgentProcessRunnerTests.swift` | shell script in temp dir | green |
| 5 | `AgentTranscriptTests` model reduction, persistence, provider resume ids, clear lifecycle | T1 / T2 | `AppShowTests/Agent/AgentTranscriptTests.swift` | temp bundle | green |
| 1 | panel width clamp plus `StateService` and `ConfigService` persistence | T1 / T2 | `AppShowTests/Agent/AgentPanelLayoutTests.swift`, `AppShowTests/State/*Agent*Tests.swift` | temp files | green |
| 3 | `AgentMarkdownParserTests` prose, fences, streaming partials, large-text fallback | unit T1 | `AppShowTests/Agent/AgentMarkdownParserTests.swift` | none | green |
| 2 | `AgentReadinessTests`, `AgentToolchainTests` PATH, version, auth, timeout | T1 / T2 | `AppShowTests/Agent/...` | fake executables in temp dirs | green |
| 7 | `AgentSecurityTests` forbids permission-bypass flags in argument builders | unit T1 | `AppShowTests/Agent/AgentSecurityTests.swift` | none | green |
| 5 | `AgentConversationStoreTests` canonical round trip, clear, and legacy migration | T2 | `AppShowTests/Agent/AgentConversationStoreTests.swift` | temp bundle | green |

## Manual checks

Panel look and feel against the design tokens, collapse animation, streaming feel with a real CLI, cancel mid-turn, not-logged-in guidance, behavior during an export.
