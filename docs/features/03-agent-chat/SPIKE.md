# Spike: agent chat panel (Claude Code / Codex runtimes)

Status: spike, no code written. Date: 2026-09-03. Companion: `ATTACK-PLAN.md`.

Paths: `Reframed/...` and `ReframedTests/...` are relative to `/Users/matheusparanhos/Projects/appshow/reframed`. `Toone/...` and `TooneTests/...` are relative to `/Users/matheusparanhos/Projects/toone/apps/toone-desktop/Toone`. Every path and line below was read on the date above.

## 1. Goal

Add a collapsible chat panel on the left edge of the editor window that runs a coding-agent CLI (Claude Code or Codex, user's choice), streams text and tool calls into one persisted conversation per `.frm` project, and resumes the logical provider session through its saved id. It must look like the rest of the editor (same cards, tokens, button styles), obey the fork's rules (Swift 6 strict concurrency, tests first, no upstream file edited outside a listed seam), and use a project-scoped sibling workspace for ephemeral runtime files.

Owner decision 2026-09-04: ADR 0010 supersedes the multi-thread sketches below. There is exactly one conversation per project, it can be cleared explicitly, and each turn launches a fresh process while reusing the selected provider's saved resume id.

Out of scope for v1: MCP servers, slash commands beyond `/clear` and `/new`, background jobs, in-app CLI installation or in-app login, image attachments, cost accounting.

## 2. Design language of the target app

### 2.1 Tokens

| Token | Value | Source |
| --- | --- | --- |
| `Layout.sectionSpacing / itemSpacing / compactSpacing` | 32 / 16 / 8 | `Reframed/UI/Constants.swift:9-11` |
| `Layout.panelPadding` | 16 | `Reframed/UI/Constants.swift:13` |
| `Layout.toolbarHeight` | 52 | `Reframed/UI/Constants.swift:23` |
| `Layout.propertiesPanelWidth` | 390 | `Reframed/UI/Constants.swift:27` |
| `Layout.editorWindowMinWidth / MinHeight` | 1400 / 900 | `Reframed/UI/Constants.swift:28-29` |
| `FontSize.xxs / xs / sm / base / lg` | 10 / 12 / 14 / 16 / 18 | `Reframed/UI/Constants.swift:44-48` |
| `Radius.sm / md / lg / xl / xxl` | 4 / 6 / 8 / 12 / 16 | `Reframed/UI/Constants.swift:56-60` |
| `ReframedColors.backgroundCard` | `#0d0d0d` dark / `#ffffff` light | `Reframed/UI/Colors.swift:90-92` |
| `ReframedColors.background` | black / white | `Reframed/UI/Colors.swift:78-80` |
| `ReframedColors.fieldBackground` | `#000000` / `#ffffff` | `Reframed/UI/Colors.swift:110-112` |
| `ReframedColors.border` | `#313131` / `#d9d9d9` | `Reframed/UI/Colors.swift:138-140` |
| `ReframedColors.divider` | white 12 % / black 12 % | `Reframed/UI/Colors.swift:134-136` |
| `ReframedColors.primaryText / secondaryText / tertiaryText` | white / 70 % / 50 % (dark) | `Reframed/UI/Colors.swift:118-128` |
| `ReframedColors.muted` (selected tab, hover pill) | white 8 % / `Color(white: 0.96)` | `Reframed/UI/Colors.swift:190-192` |
| `ReframedColors.accent` (outline-button hover) | white 12 % / black 6 % | `Reframed/UI/Colors.swift:186-188` |
| `ReframedColors.isDark` reads `NSApp.effectiveAppearance`, so the enum is `@MainActor` | | `Reframed/UI/Colors.swift:61-66` |

There is no monospace token and no per-role bubble colour; the app is monochrome with opacity steps. A chat bubble should therefore be `ReframedColors.muted` for the user and no fill for the assistant, not an accent tint.

### 2.2 Buttons, headers, popovers

- Only four button styles exist and are allowed (`docs/architecture/06-conventions-checklist.md` item 3): `PrimaryButtonStyle` (filled, `Reframed/UI/PrimaryButton.swift:49-72`), `SecondaryButtonStyle` (74-97), `OutlineButtonStyle` (99-123), `PlainCustomButtonStyle` (125-129). `ButtonSize.small` is 30 pt high, `Radius.md`, `FontSize.xs` semibold (`PrimaryButton.swift:8-46`). The top-bar "Export" is `PrimaryButtonStyle(size: .small)` (`Reframed/Editor/EditorTopBar.swift:24-26`); the send button of the composer should match it.
- `IconButton` is a 28×28 `PlainCustomButtonStyle` image button at `FontSize.xs` (`Reframed/UI/IconButton.swift:3-20`); this is the collapse/expand control.
- `SectionHeader(icon:title:)` is `FontSize.sm` icon + `FontSize.xs` semibold title (`Reframed/UI/SectionHeader.swift:11-19`); the bare-title variant is `FontSize.xxs` secondary text with 12 pt horizontal padding (21-27), which is what a thread list header looks like.
- Sidebar tabs are 56×48 pills, `Radius.lg`, `ReframedColors.muted` when selected, wrapped in `HoverEffectScope` with `.hoverEffect(id:)` (`Reframed/Editor/EditorView+Sidebar.swift:15-36`, `Reframed/UI/HoverEffect.swift:3-24`).
- Popover content is `VStack(alignment: .leading, spacing: 0)` + `SectionHeader(title:)` + `.popoverContainerStyle()` (`Reframed/UI/PopoverContainerStyle.swift:3-23`, `Radius.lg`, 0.5 pt border). A provider picker is a `SegmentPicker` or `CheckmarkRow` list in such a popover (`docs/architecture/05-coding-patterns.md` §9.4).
- Every view starts `body` with `let _ = colorScheme` after declaring `@Environment(\.colorScheme) private var colorScheme` (`05-coding-patterns.md` §2.5). No comments, no literal sizes, no stock `.buttonStyle(.plain)`.

### 2.3 How the editor is laid out today

`EditorView.body` (`Reframed/Editor/EditorView.swift:28-127`) is a `VStack(spacing: 0)`:

1. `EditorTopBar` (44 pt, `EditorTopBar.swift:30`), horizontal padding 12.
2. `HStack(spacing: 8)` at lines 43-56 containing three cards, each `.background(ReframedColors.backgroundCard)`, `.clipShape(RoundedRectangle(cornerRadius: Radius.xxl))`, `.overlay(... strokeBorder(ReframedColors.border, lineWidth: 1))`: `mainContent` (video preview, flexible), `editorSidebar` (fixed 64 pt: 56 + 2×4 padding, `EditorView+Sidebar.swift:42-43`), `PropertiesPanel` (fixed `Layout.propertiesPanelWidth` = 390, `PropertiesPanel.swift:96`).
3. `transportBar`, then the `timeline` card with 12 pt padding.

Preview mode (`editorState.isPreviewMode`) collapses everything to `mainContent` (lines 31-33). The window is an `NSWindow` hosting `NSHostingView(rootView: EditorView)` with `contentMinSize` 1400×900 and its frame persisted through `StateService.shared.editorWindowFrame` (`Reframed/Editor/EditorWindow.swift:40-60, 173-181`). There is no collapsible sidebar anywhere in the app today; the closest precedent is `RecordingPreviewWindow` persisting its height in `StateService.recordingPreviewHeight` (`Reframed/State/StateService.swift:92-95`).

### 2.4 Where the panel slots in

The panel becomes the first child of the `HStack` at `EditorView.swift:43`, so the row reads agent · preview · sidebar · properties. It uses the same card treatment, is hidden in preview mode like the other cards, and its width is not part of the preview's aspect fit (the preview already sizes itself by `GeometryReader`, `EditorView+Preview.swift:23`).

```
Expanded (width persisted, default 320, clamp 260…480)                Collapsed (rail 40)

┌ EditorTopBar ───────────────────────────────────────────────────┐   ┌ EditorTopBar ─────────────────────────────────────┐
│ project-name                     [folder] [trash] [ Export ]    │   │ project-name              [folder] [trash] [Export]│
├────────────┬──────────────────────────┬────┬────────────────────┤   ├──┬────────────────────────────────┬────┬──────────┤
│ ◁ Agent  ⋯ │                          │Gen │ Canvas             │   │ ▷│                                │Gen │ Canvas   │
│ ──────────  │                          │Vid │ ┌──────────────┐  │   │  │                                │Vid │ ...      │
│ Thread A ● │      video preview       │Cam │ │ 16:9  1:1 …  │  │   │  │        video preview           │Cam │          │
│ Thread B   │                          │Aud │ └──────────────┘  │   │  │                                │Aud │          │
│ ──────────  │                          │Cur │ Padding   ── 8 %  │   │  │                                │Cur │          │
│ ▸ user: …  │                          │Zoom│ ...                │   │  │                                │Zoom│          │
│   assistant│                          │FX  │                    │   │  │                                │FX  │          │
│   ⚙ Read … │                          │Cap │                    │   │  │                                │Cap │          │
│   ▍(stream)│                          │    │                    │   │  │                                │    │          │
│ ──────────  │                          │    │                    │   │  │                                │    │          │
│ [ prompt ] │                          │    │                    │   │  │                                │    │          │
│ claude ▾ ⏎ │                          │    │                    │   │  │                                │    │          │
├────────────┴──────────────────────────┴────┴────────────────────┤   ├──┴────────────────────────────────┴────┴──────────┤
│ ⏮ ▶ ⏭  00:12 / 01:40                                 transport │   │ transport                                          │
├─────────────────────────────────────────────────────────────────┤   ├────────────────────────────────────────────────────┤
│ timeline                                                        │   │ timeline                                           │
└─────────────────────────────────────────────────────────────────┘   └────────────────────────────────────────────────────┘
```

Collapsed rail: 40 pt wide card with one `IconButton(systemName: "sidebar.left")` and a status dot while a turn runs. Expanded: header row (title, provider picker, clear, collapse), transcript `ScrollView`, composer. The drag handle is an 8 pt invisible strip on the card's trailing edge; width persists on drag end.

## 3. What Toone already provides

Toone is a Swift 5 (`SWIFT_VERSION = 5.0`, `Toone.xcodeproj/project.pbxproj:505,541,559`; no `SWIFT_STRICT_CONCURRENCY` key) SwiftUI/AppKit app that drives both CLIs. Its code is organised as provider abstraction → process runner → NDJSON parser → `AIMessage` → `RichMessage` (UI) → SwiftData persistence.

### 3.1 Reuse table

| Concern | Type | Toone path | Verdict | Reason |
| --- | --- | --- | --- | --- |
| Provider enum + flag knowledge | `AIProvider` | `Toone/Core/Services/AIService/Models/AIProvider.swift:11-94` | adapt | Keep `claude`/`codex` raw values and `displayName`; drop `managedBinaryURL`, distribution gating, docs URLs |
| Command builder protocol | `AICommandBuilder` | `Toone/Core/Services/AIService/Protocols/AICommandBuilder.swift:10-36` | rewrite | Its `AISessionOptions` is a 300-line bag; we need three parameters |
| Parser protocol | `AIMessageParser` | `Toone/Core/Services/AIService/Protocols/AIMessageParser.swift:10-24` | as-is | `parseLine(_:) -> AIMessage?` + `extractSessionId(from:)` is exactly the seam we want, renamed |
| Claude argv | `ClaudeCommandBuilder.buildStartArguments` | `Toone/Core/Services/AIService/Claude/ClaudeCommandBuilder.swift:15-86` | adapt | Keep the flag vocabulary, drop MCP/lockdown/budget branches |
| Claude stdin payloads | `buildMessagePayload`, `buildToolResultPayload` | `ClaudeCommandBuilder.swift:88-122` | as-is | Pure `JSONSerialization` dictionaries, no dependencies |
| Codex argv (`exec`) | `CodexCommandBuilder` | `Toone/Core/Services/AIService/Codex/CodexCommandBuilder.swift:11-111` | as-is | Pure; `exec` / `exec resume` shapes are what v1 needs |
| Codex app-server JSON-RPC | `CodexService` | `Toone/Core/Services/AIService/Codex/CodexService.swift:279-1252` | defer | 1 200 lines, locks, request timeouts, `request_user_input`; only needed for mid-turn interrupt and questions |
| Claude NDJSON parser | `ClaudeMessageParser` | `Toone/Core/Services/AIService/Claude/ClaudeMessageParser.swift:10-147` | adapt | Envelope switch (56-64), `content_block` walk (76-91), `tool_result` (92-114), `result` with `is_error`/`subtype` (115-147) are the core; drop plan/task/MCP projections (205-667) and `Log.ai` (13 calls) |
| Codex NDJSON parser | `CodexMessageParser` | `Toone/Core/Services/AIService/Codex/CodexMessageParser.swift:29-44, 181-227, 420-476, 904-965, 1009-1063` | adapt | Keep `thread.started`, `item.completed`, `turn.completed`/`turn.failed`, `command_execution`, `mcp_tool_call`; drop app-server normalisation (46-285) and `Log.ai` (37 calls) |
| Provider-neutral event | `AIMessage`, `AIToolCall` | `Toone/Core/Services/AIService/Models/AIMessage.swift:10-93, 330-342` | adapt | Good shape; strip `transientEvent`, `AIPlanSnapshot`, `AITaskProgressPayload` |
| `system/init` capability read | `ProviderCapabilitySnapshot.claudeInit` | `Toone/Core/Services/AIService/Models/ProviderCapabilities.swift:84-117` | later | Gives `slash_commands`/`skills`; not needed until slash commands |
| Process runner | `BaseAIService` | `Toone/Core/Services/AIService/Base/BaseAIService.swift:244-391, 411-426, 494-581, 623-727` | rewrite | The mechanics (pipes, `readabilityHandler`, NDJSON framing, 1 MB cap, `terminationHandler` not `waitUntilExit`, 30-min inactivity watchdog) are right; the class is a non-isolated `@Observable` with `NSLock`, which does not compile under Swift 6 |
| PATH resolution | `ToolchainResolver.controlledEnvironment`, `searchDirectories` | `Toone/Core/Services/CLIManager/ToolchainResolver.swift:151-162, 210-246` | adapt | Filesystem-only lookup, never a login shell; copy the directory list, drop the `-lic` fallback (343-381) |
| Health probe | `ProcessAIProviderHealthChecker` | `Toone/Features/Setup/Services/AIProviderDiscoveryService.swift:111-178` | adapt | `--version`, 10 s timeout, 32 KB cap, `SIGKILL` on timeout; it is `@unchecked Sendable`, port to an actor |
| Readiness model | `AIProviderReadiness`, `AIProviderReadinessSnapshot` | `Toone/Features/Setup/Models/AIProviderReadiness.swift:8-62` | as-is | Pure enum with `setupStatusLabel`; add a `.notLoggedIn` case |
| Version parsing | `CLIVersionParser.semanticVersion` | `Toone/Core/Services/CLIManager/AIProviderCandidateSelector.swift:14-91` | as-is | One regex |
| Login detection | `CLIAuthService.checkClaudeAuth/checkCodexAuth` | `Toone/Core/Services/CLIManager/CLIAuthService.swift:90-137` | adapt | The two commands are all we need; the PTY login flow (141-195) is out of scope |
| Auto-update | `CLIAutoUpdateService`, `CLIDownloadService` | `Toone/Core/Services/CLIManager/CLIAutoUpdateService.swift:16-208`, `CLIDownloadService.swift:258-265` | no | Downloads binaries into `~/.toone/bin`; we point at the user's install and never download |
| Markdown renderer | `MarkdownTextView`, `MarkdownRenderSegment`, `FormattedTextView`, `MarkdownTableView` | `Toone/Features/Chat/Views/MarkdownTextView.swift:35-53, 59-610, 614-833, 987-1074` | adapt | Bespoke parser, `import SwiftUI` only (line 8), NSCache-backed, streaming-aware (`cachedSegments(_:cacheResult:)` line 196); replace 22 `Colors.` and 6 `layoutStyle` references with `ReframedColors`, delete `appEnvironment` |
| Code block | `CodeBlockView` | `Toone/Features/Chat/Views/CodeBlockView.swift:12-206` | adapt | Depends on Highlightr; v1 uses `.system(design: .monospaced)` and a copy button only |
| Streaming cursor | `StreamingCursor` | `Toone/Features/Chat/Views/RichMessageBubble.swift:852-867` | as-is | 15 lines |
| Tool-call rows | `CollapsibleToolCalls`, `DetailedToolCallRow`, `ToolCallBadge` | `RichMessageBubble.swift:880-1004, 1040-1192, 1196` | adapt | Grouping logic and SF Symbol map (1049-1062) are good; restyle with tokens, drop file-viewer links |
| Eager/lazy transcript | `ChatTranscriptLayoutPolicy` | `Toone/Features/Chat/Views/ChatPanelView.swift:136-186` | as-is | Pure function over messages (80 messages / 1 MB thresholds) |
| Flipped scroll list | `messageListContent` | `ChatPanelView.swift:821-889` | adapt | The `scaleEffect(y: -1)` trick keeps the newest row at the bottom without scroll math |
| UI message model | `RichMessage`, `MessageContent`, `ToolCallContent`, `ToolCallStatus` | `Toone/Features/Chat/Models/Message.swift:330-455, 552-602` | adapt | Keep `text/codeBlock/toolCall/toolResult`; drop `image/pastedText`, `localContent`, `author` |
| Streaming update | `ChatViewModel.handleAssistantMessage`, `finishStreamingMessage` | `Toone/Features/Chat/ViewModels/ChatViewModel.swift:1302-1387, 1525-1550` | rewrite | Whole-text replace per event, fine; the class is 2 000+ lines of unrelated state |
| Composer | `ChatComposerTextField` | `Toone/Features/Chat/Views/ChatInputView.swift:14-95` | adapt | `TextField(axis: .vertical).lineLimit(2...20)`; 22 `DesignTokens` and `appEnvironment` references to replace |
| Thread activity | `ThreadActivityLifecycle`, `ThreadActivityProjection` | `Toone/Features/Chat/Models/ThreadActivityState.swift:10-68, 146-275` | adapt | Pure, `Sendable`; one `RoutineExecution` reference to cut |
| Thread persistence | `PersistedSession`, `PersistedMessage` | `Toone/Core/Storage/Models/PersistedModels.swift:742-1122` | no | SwiftData; the target app is JSON-in-bundle. Copy the field list only |
| Session id per provider | `ProviderThreadSessionState` | `Toone/Features/Organization/Models/RoutineExecution.swift:60-74` | as-is | `sessionId`, `syncedThroughMessageId`, `contextGeneration` |
| Slash commands | `SlashCommand`, `BuiltinSlashCommand`, `SlashSubmissionResolver` | `Toone/Features/Chat/Models/SlashCommand.swift:13-90`, `SlashSubmissionResolver.swift:8-41` | adapt (later) | Resolver is 41 pure lines; registry pulls org/routine concepts |
| Background jobs | `PersistedBackgroundJob`, `BackgroundJobStore` | `Toone/Core/Services/AgentSession/BackgroundJob.swift:15-168` | no | Depends on child threads and the process gate; not a v1 concern |
| MCP registration | `MCPRegistryService`, `CodexMCPOverrideBuilder`, `CodexConfigService`, `ClaudeConfigService` | `Toone/Core/Services/MCPRegistry/MCPRegistryService.swift:84-312`, `CodexMCPOverrideBuilder.swift:14-164`, `Toone/Core/Services/AIService/Codex/CodexConfigService.swift:11-26, 148-204`, `Claude/ClaudeConfigService.swift:226-273` | later | Shows the two registration shapes: Claude via `--mcp-config <file>` (`ClaudeCommandBuilder.swift:59-72`) or `mcpServers` in `~/.claude.json`; Codex via `codex mcp add toone -- <node> <server> ...` or `-c mcp_servers.<id>.command=...` per spawn |

### 3.2 CLI invocations Toone relies on (verbatim)

**Claude Code, persistent chat process** (`ClaudeCommandBuilder.swift:16`, then 18-24, 82-84):

```swift
var parts = ["--input-format", "stream-json", "--output-format", "stream-json", "--verbose"]
if allowAllPermissions {
    parts.append("--dangerously-skip-permissions")
} else if options.permissionMode != .default {
    parts += ["--permission-mode", options.permissionMode.rawValue]
}
...
for tool in options.allowedTools {
    parts += ["--allowedTools", tool]
}
...
if let sessionId = resumeSessionId {
    parts += ["--resume", sessionId]
}
```

Messages go to stdin as one JSON line (`ClaudeCommandBuilder.swift:88-102`): `{"type":"user","message":{"role":"user","content":[{"type":"text","text":"..."}]}}`.

**Claude Code, one-shot** (`Toone/Core/Services/AIService/ThreadTitleService.swift:134-139`):

```swift
return [
    "-p", prompt,
    "--model", model,
    "--tools", "",
    "--no-session-persistence"
]
```

`Toone/Features/Setup/Models/ClaudeCodeOutput.swift:12` documents the older one-shot shape: `claude -p --output-format stream-json --verbose`.

**Codex, one-shot** (`CodexCommandBuilder.swift:20`, 68, 93-99; `ThreadTitleService.swift:141-150`):

```swift
var arguments = ["exec", "--json", skipGitRepoCheckFlag]          // skipGitRepoCheckFlag = "--skip-git-repo-check"
var arguments = ["exec", prompt, "--json", skipGitRepoCheckFlag]
var arguments = ["exec", "resume", sessionId, prompt, "--json", skipGitRepoCheckFlag]
```

```swift
return [
    "exec", prompt,
    "--json",
    "--skip-git-repo-check",
    "--ephemeral",
    "--ignore-user-config",
    "--ignore-rules",
    "--sandbox", "read-only",
    "--model", model
]
```

`--full-auto` is never passed (asserted absent in `TooneTests/Services/CodexCommandBuilderTests.swift:48,60,73,88`). The admin flag is `--dangerously-bypass-approvals-and-sandbox` (`CodexCommandBuilder.swift:15`).

**Codex, persistent chat process** (`CodexService.swift:434-438`), used because `exec` cannot answer `request_user_input`:

```swift
task.arguments = identityEnvironmentArguments + [
    "app-server",
    "--stdio",
    "--enable", "default_mode_request_user_input"
]
```

followed by JSON-RPC `initialize` / `initialized` / `thread/start` or `thread/resume` (`CodexService.swift:531-581`) with `approvalPolicy` and `sandbox` set per mode (`911-956`: plan → `"never"`/`"read-only"`, default → `"on-request"`/`"workspace-write"`).

**Process mechanics** (`BaseAIService.swift:252-258, 314-329`): `Process()` with `executableURL` = resolved binary, `currentDirectoryURL` = the thread's working directory, `environment = ToolchainResolver.shared.controlledEnvironment(...)` (PATH replaced by a fixed directory list, HOME set), `standardInput`/`standardOutput`/`standardError` = pipes, stdout read through `readabilityHandler`, lines split on `\n` with a 1 MB cap (`523-545`), `terminate()` on stop (`494-519`).

**Detection** (`AIProviderDiscoveryService.swift:130-134`, `CLIAuthService.swift:90-137`): `<binary> --version` with a 10 s timeout; `claude auth status` returning JSON with `loggedIn`, `email`, `authMethod`; `codex login status` returning `Logged in using ChatGPT` on exit 0.

### 3.3 JSON event shapes Toone parses (verbatim from tests and parser comments)

Claude Code stream-json envelopes, as the parser reads them (`ClaudeMessageParser.swift:35, 56-64, 76-147`; `TooneTests/Services/ChatProgressSafetyTests.swift:112-138, 157-163`):

```json
{"type":"system","subtype":"init","session_id":"…","cwd":"…","tools":["Bash","Read"],"model":"…","mcp_servers":[],"slash_commands":[],"skills":[]}
{"type":"assistant","session_id":"…","message":{"role":"assistant","content":[{"type":"text","text":"Looking at project.json…"}]}}
{"type":"assistant","session_id":"…","message":{"content":[{"type":"tool_use","id":"toolu_01","name":"Read","input":{"file_path":"project.json"}}]}}
{"type":"user","session_id":"…","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_01","content":"…","is_error":false}]}}
{"type":"result","subtype":"success","is_error":false,"result":"fallback text","structured_output":{"answer":"schema-bound"},"total_cost_usd":0.01,"duration_ms":1200,"num_turns":1,"session_id":"…"}
```

The refusal rule at `ClaudeMessageParser.swift:132-147`: a failed turn arrives as `type:"result"` with `is_error:true` and/or `subtype != "success"`, never as `type:"error"`.

Codex `exec --json` NDJSON (`TooneTests/Services/CodexCommandBuilderTests.swift:130,142`; `TooneTests/Services/ThreadTitleServiceTests.swift:114-115`; `CodexMessageParser.swift:181-188`):

```json
{"type":"thread.started","thread_id":"019f-codex-thread"}
{"type":"turn.started"}
{"type":"item.completed","item":{"id":"item_0","type":"agent_message","text":"Postgres Timeout Investigation"}}
{"type":"item.completed","item":{"id":"question-1","type":"function_call","name":"request_user_input","arguments":"{\"questions\":[{\"id\":\"project-kind\",\"header\":\"Project\",\"question\":\"What are you building?\",\"options\":[]}]}"}}
{"type":"item.completed","item":{"id":"item_2","type":"command_execution","command":"ls","aggregated_output":"…","exit_code":0,"status":"completed"}}
{"type":"turn.completed","usage":{...}}
```

Two traps the Codex parser guards: `JSONSerialization` maps JSON `null` to `NSNull`, so `"error": null` on a successful `turn.completed` must not be read as an error (`CodexMessageParser.swift:1009-1063`); and Codex reuses item ids such as `item_0` across sessions, so UI message ids must be fresh UUIDs (`ChatViewModel.swift:1358`).

### 3.4 License of the source repo

`/Users/matheusparanhos/Projects/toone` has no root `LICENSE`; `apps/toone-desktop` has none either. `apps/toone-desktop/README.md:72-74` says `[MIT](LICENSE)` with a dangling link, and its disclaimer (line 68) names Hexagonal.io as the developer. Root `package.json` has no `license` field and is `"private": true`. No Swift file carries a license header. Sibling packages (`apps/toone-oss/LICENSE`, `apps/toone-edge-relay/LICENSE`, `packages/toone-edge-*/LICENSE`) are MIT, copyright `io-hexagonal`. Both repositories live under the same GitHub account (`mattwebhub/toone`, `mattwebhub/Reframed`). Conclusion: copying is a decision for the owner, not a legal blocker, but the first commit that copies code should be accompanied by either a `LICENSE` added to `apps/toone-desktop` or an ADR in `planning/decisions/` recording provenance and the owner's authorisation (the target app is MIT, ADR 0008 already tracks a licence question for gifski).

## 4. What the target app lacks

- No `Process` usage anywhere under `Reframed/` (grep `Process()` → 0 hits) and no NDJSON or JSON-RPC client.
- No markdown rendering and no SPM markdown package (`Reframed.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` lists Sparkle, WhisperKit, swift-log, MenuBarExtraAccess, rnnoise and their transitive deps only).
- No `AsyncStream` anywhere (`docs/architecture/02-concurrency.md` §2: every stream is a delegate callback on a GCD queue).
- No collapsible or resizable side panel; the three editor cards are fixed or flexible (§2.3).
- No multi-line text input component; `InlineEditableText` (`Reframed/UI/InlineEditableText.swift`) is single-line.
- No per-project auxiliary data beyond `project.json`, `history.json` and the media files (`Reframed/Project/ReframedProject.swift:13-45, 122, 179`); adding an `agent/` directory to the bundle is new territory for `rename(to:)` (line 161) and `delete()`.
- No test fixtures directory yet; `planning/tdd-strategy.md` §Fixtures describes `ReframedTests/Fixtures/` and `FixtureAnchor`, but `ReframedTests/` currently holds four suites and no `Support/` folder.

## 5. Recommended architecture for the port

### 5.1 Module boundary: `Reframed/Agent/`

One folder, one concern per file, no upstream file touched except at the seams listed in §5.6.

| File | Type | Isolation | Role |
| --- | --- | --- | --- |
| `AgentProvider.swift` | `protocol AgentProvider: Sendable`, `enum AgentProviderKind: String, Codable, CaseIterable` | none | `launchArguments(prompt:resume:workingDirectory:)`, `parse(line:) -> AgentEvent?`, `sessionID(from:)`, `probeArguments`, `authArguments` |
| `AgentEvent.swift` | `enum AgentEvent: Sendable, Equatable` | none | `.sessionStarted(id)`, `.assistantText(String)`, `.toolCall(id:name:inputSummary:)`, `.toolResult(id:text:isError:)`, `.turnCompleted(isError:costUsd:durationMs:)`, `.failure(String)`, `.system(String)` |
| `ClaudeCodeProvider.swift` | `struct` | none | Port of `ClaudeCommandBuilder` + the core of `ClaudeMessageParser`; decodes with `Codable` structs, not `[String: Any]`, so the result is `Sendable` |
| `CodexProvider.swift` | `struct` | none | Port of `CodexCommandBuilder` (`exec`, `exec resume`) + the NDJSON half of `CodexMessageParser` |
| `AgentProcessRunner.swift` | `actor` | actor | Owns `Process`, `Pipe`s, the line buffer and the inactivity watchdog; exposes `func run(executable:arguments:cwd:environment:stdin:) -> AsyncThrowingStream<String, Error>` and `func terminate()` |
| `AgentSession.swift` | `actor` | actor | One thread's live run: composes runner + provider, turns lines into `AgentEvent`s, tracks `sessionID`, exposes `func send(_ prompt: String) -> AsyncStream<AgentEvent>` and `func cancel()` |
| `AgentTranscript.swift` | `@MainActor @Observable final class` | main | Per-project UI model: one `AgentConversationData`, messages, provider-scoped resume ids, `isRunning`, `streamingMessageID`; applies `AgentEvent`s; owns the `Task` that drains the session |
| `AgentTranscript+Persistence.swift` | extension | main | `load(from:)`, `save()`; JSON with the `ReframedProject` encoder settings (`.iso8601`, `[.prettyPrinted, .sortedKeys]`) |
| `AgentConversationData.swift` | `struct … Codable, Sendable, Equatable` + `AgentMessageData`, `AgentContentData` (enum with string `type` discriminator, unknown → `.text`) | none | The single-conversation on-disk schema; custom decoding migrates the abandoned legacy session id field |
| `AgentToolchain.swift` | `enum` + `actor AgentProbe` | none / actor | Filesystem-only binary lookup (port of `ToolchainResolver.searchDirectories`), `--version` probe, login-status probe → `AgentReadiness` |
| `AgentReadiness.swift` | `enum AgentReadiness: Sendable, Equatable` | none | `.ready(path:version:)`, `.missing`, `.unhealthy(reason:)`, `.notLoggedIn(path:)`; `label`, `detail`, `isReady` |
| `AgentChatPanel.swift` (+ `+Header`, `+Transcript`, `+Composer`, `+Setup`) | SwiftUI views | main | The card; each extension file stays under ~200 lines |
| `AgentMarkdownView.swift`, `AgentCodeBlockView.swift`, `AgentToolCallRow.swift`, `AgentStreamingCursor.swift` | SwiftUI views | main | Ported from Toone, restyled with `ReframedColors`/`FontSize`/`Radius` |

Dependency direction: `Agent/` depends on `Project/` (`ReframedProject.bundleURL`), `State/` (`StateService`, `ConfigService`), `UI/` (tokens, buttons), `Utilities/` (`LenientCodable`, `ReframedPaths`), `Logging`. Nothing else depends on `Agent/` except `Editor/EditorView.swift` (one line) and `Editor/EditorState.swift` (one stored property, see §5.6).

### 5.2 Concurrency placement (per `docs/architecture/02-concurrency.md` §5)

- `Process`, `Pipe`, `FileHandle` are non-Sendable and callback-driven; they live inside `AgentProcessRunner` (actor). The `readabilityHandler` closure is `@Sendable` and runs on a GCD thread; it copies the `Data` and hops with `Task { await self.append(data) }`. This replaces Toone's `NSLock` + non-isolated `@Observable` class, which does not compile under strict concurrency. The `terminationHandler` is installed before `run()` (as `BaseAIService.swift:331-380` insists) and also hops into the actor.
- `AsyncThrowingStream` is new to the codebase but is the idiomatic Swift 6 replacement for Toone's `messageContinuation`; it is confined to `Agent/` and finished on termination, cancellation, or watchdog.
- `AgentSession` (actor) is the equivalent of `RecordingCoordinator`: a coordination point, not a data path. It returns `Sendable` enums only.
- `AgentTranscript` is `@MainActor @Observable`, owned by `EditorState` the way `History` is (`Reframed/Editor/EditorState.swift`), and torn down in `EditorState.teardown()` (`Reframed/Editor/EditorState+Persistence.swift:437`), which cancels the drain task and terminates the process so no CLI outlives the window.
- The transcript's streaming update is whole-text replace per event, exactly Toone's `updateStreamingMessage` (`ChatViewModel.swift:1382-1387`); no partial-message deltas in v1.
- Cancellation follows the app's existing pattern (`05-coding-patterns.md` §6.5): the drain task is stored as `Task<Void, Never>?`, cancelled in `teardown()`, and the runner's stream uses `withTaskCancellationHandler { … } onCancel: { terminate }`.

### 5.3 Process model per provider

| | Claude Code | Codex |
| --- | --- | --- |
| v1 | One process per turn: `["-p", "--output-format", "stream-json", "--verbose", "--allowedTools", <list>, "--permission-mode", <mode>] + (["--resume", id] if resuming)`; prompt written to stdin then stdin closed (`-p` reads stdin when no positional prompt is given) | One process per turn: `["exec", prompt, "--json", "--skip-git-repo-check", "--sandbox", "read-only"]` or `["exec", "resume", id, prompt, "--json", "--skip-git-repo-check", "--sandbox", "read-only"]` |
| Session id | `session_id` on every envelope; first `system/init` wins | `thread_id` on `thread.started` |
| Cancel | `terminate()`; the CLI persists the session so the next turn can still resume | `terminate()`; same |
| Upgrade path | persistent process with `--input-format stream-json` (Toone's chat shape) for tool-result round trips | `app-server --stdio` JSON-RPC (Toone's `CodexService`) for `turn/interrupt` and `request_user_input` |

One process per turn keeps the runner identical for both providers, makes cancellation a `terminate()`, and leaves no idle process while the user edits video. The cost is a cold start per turn (about a second) and no mid-turn steering; both are acceptable for v1 and are recorded as questions in §9.

### 5.4 Transcript persistence

Location: inside the bundle, beside `history.json`:

```
recording-…​.frm/
├── project.json
├── history.json
└── agent/
    └── conversation.json         provider, resumeIds, timestamps, messages
```

Reasons: a conversation is about one project and should move, rename, and delete with it; `ReframedProject.rename(to:)` already moves the whole directory (`ReframedProject.swift:161`). Resume ids are keyed by provider because a Claude session id is meaningless to Codex. Saves occur at user-message append, turn completion/cancellation, provider change, and clear. Provider session data itself stays where the CLIs keep it (`~/.claude/projects/...`, `~/.codex/sessions/...`); AppShow stores only the ids.

The CLI working directory is a sibling path, `.agent/<project-name>/`, containing ephemeral socket, token, and preview-frame files. It is intentionally separate from the portable conversation record inside the bundle.

### 5.5 Panel state and preferences

- `StateService` gains `agentPanelCollapsed: Bool` and `agentPanelWidth: CGFloat?` in `StateData` (`Reframed/State/StateService.swift:150-159`), with get/set + `save()` properties in the `recordingPreviewHeight` style (lines 92-95). Session-layout state belongs there, not in `ConfigService` (`06-conventions-checklist.md` "Adding a new setting" item 5).
- `ConfigService` gains `agentProvider: String = "claude"` in `ConfigData` plus a get/set property; the picker in the panel header writes it directly, like `appearance` in `SettingsView` (`05-coding-patterns.md` §5.2).
- Default width 320, clamp 260…480, collapsed rail 40; constants go into `Layout` as `agentPanelWidth`, `agentPanelMinWidth`, `agentPanelMaxWidth`, `agentPanelRailWidth` (`Reframed/UI/Constants.swift:8-30`).

### 5.6 Upstream files touched (seams)

| File | Change | Why it is a seam |
| --- | --- | --- |
| `Reframed/Editor/EditorView.swift:43` | insert `AgentChatPanel(transcript: editorState.agentTranscript)` as the first child of the `HStack` | one additive line |
| `Reframed/Editor/EditorState.swift` | one stored property `let agentTranscript: AgentTranscript` initialised from `project` | additive; `History` precedent |
| `Reframed/Editor/EditorState+Persistence.swift:437` | `agentTranscript.teardown()` inside `teardown()` | additive line |
| `Reframed/State/StateService.swift`, `Reframed/State/ConfigService.swift` | new optional/defaulted fields | listed pattern |
| `Reframed/UI/Constants.swift` | four `Layout` constants | additive |
| `planning/upstream-sync.md` | list the above under "Intentional divergences" | required by `planning/tdd-strategy.md` |

## 6. Provider detection and setup UX

Detection runs once when the panel first expands and again on "Check again", never at app launch (the editor is the only consumer). `AgentProbe` resolves the binary through the fixed directory list (no login shell), runs `--version` with a 10 s timeout and 32 KB output cap, then the login probe.

| State | How detected | Panel shows |
| --- | --- | --- |
| `.ready(path, version)` | `--version` exits 0 and prints a semver; `claude auth status` JSON has `loggedIn: true` or `codex login status` exits 0 | composer enabled; header shows `claude 2.1.x` in `tertiaryText` |
| `.missing` | no candidate file in the search list | setup card: "Claude Code was not found", the exact directories searched, an `OutlineButtonStyle` "Check again" button and "Use Codex instead" if the other provider is ready; install instructions are a copyable shell line, no download |
| `.unhealthy(reason)` | file exists but the probe times out or exits non-zero | setup card with the captured stderr (first 3 lines) |
| `.notLoggedIn(path)` | `--version` ok, auth probe says not logged in | setup card: "Run `claude auth login` in Terminal, then Check again"; no in-app PTY |

Provider switch is a `SegmentPicker` in the header; switching while a turn runs is disabled, and switching otherwise keeps the same conversation while selecting that provider's resume id. When exactly one provider is ready the picker preselects it (Toone's `selectionDecision`, `AIProviderReadiness.swift:54-60`).

## 7. Security and permissions

- Working directory: the `.frm` bundle directory of the open project, never `~`, never the project folder root. Both CLIs treat cwd as the project root for their own session storage and rule files, so a user's `~/.claude/CLAUDE.md` still applies but no `CLAUDE.md`/`AGENTS.md` from unrelated folders does.
- Tool policy v1: read-only. Claude Code launched with `--permission-mode default --allowedTools Read Glob Grep` (anything else prompts, and a prompt in `-p` mode is denied, which the transcript shows as a failed tool call); Codex with `--sandbox read-only` and no bypass flag. `--dangerously-skip-permissions` and `--dangerously-bypass-approvals-and-sandbox` are never passed, and there is no setting to enable them. Write access, when it comes, goes through a Reframed-owned MCP server exposing editor operations (Toone's `--mcp-config` / `codex mcp add` shapes), so the agent edits the project through validated operations, never by rewriting `project.json` or media.
- Environment: a fresh dictionary with `PATH` = the fixed search list, `HOME`, `LANG`, `TERM`; nothing else from the app's environment is forwarded. `REFRAMED_HOME`/`REFRAMED_TMP` are never forwarded.
- Never exposed: `~/.reframed/reframed.json`, `~/.reframed/state.json`, the Whisper model folders, `~/Movies/Reframed`, recordings of other projects, the app's log file. Media files inside the bundle are readable by the agent (it is in the bundle); if that is unwanted, cwd becomes `<bundle>/agent/` with a symlink to `project.json` only (question in §9).
- Prompt content is written to the CLI and to `agent/conversation.json`; nothing leaves the machine except through the CLI the user installed and logged into.
- Test host: `AgentProbe` and `AgentProcessRunner` take the executable URL and environment as parameters, so tests run `/bin/echo`, `/bin/cat`, `/usr/bin/false` and a fixture script instead of any real CLI, and never touch `~/.claude` or `~/.codex`.

## 8. Risks

| Risk | Evidence | Mitigation |
| --- | --- | --- |
| CLI protocol drift | Toone carries "legacy format support" branches for Codex (`CodexMessageParser.swift:214-225`) and a second, older Claude decoder (`ClaudeCodeOutput.swift`); Codex moved from `exec --json` to `app-server` for interactive features | Parsers are total functions with an `.unknown` fallback that keeps the raw line; recorded-line fixtures from the installed CLI versions are committed with the version in the filename; a failing fixture on a CLI update is a red test, not a crash |
| Long-running or hung processes | Toone needed a 30-minute inactivity watchdog (`BaseAIService.swift:27`) and a 1 MB output cap (`:18`) and moved off `waitUntilExit` because parked threads starved the cooperative pool (`331-336`) | Actor-owned runner, `terminationHandler`, watchdog with a 10-minute default, `terminate()` in `teardown()`, and a `SIGKILL` follow-up after 2 s |
| Orphans on quit | `EditorWindow.close()` tears down state but nothing today kills child processes | `applicationWillTerminate` is not touched; instead each `AgentProcessRunner` registers with a `@MainActor` `AgentProcessRegistry` whose `deinit` path is the window close; verified by the T3 checklist |
| Strict-concurrency port pitfalls | Toone is Swift 5 mode: non-isolated `@Observable` services with `NSLock`, `[String: Any]` dictionaries crossing threads, `Log.ai` global, `@unchecked Sendable` health checker | Decode into `Codable` structs inside the actor; never let `[String: Any]` leave `parse(line:)`; every ported type is a `struct`, `enum`, or `actor`; no `NSLock` |
| `NSNull` and id reuse | `CodexMessageParser.swift:1009-1063`, `ChatViewModel.swift:1358` | Codable decoding removes the `NSNull` class of bug; message ids are UUIDs generated by the transcript |
| Output volume | Codex resume replies can be megabytes (`CodexService.swift:56-62`) | Per-line cap 1 MB; large Markdown falls back to plain text above 64 KB and transcript rows use a lazy stack |
| Layout regressions | The editor minimum width is 1400 and the properties panel is 390 fixed | Panel width clamp 260…480 keeps the preview ≥ 500 pt at minimum window width; collapse is one click |
| Argument length | Codex takes the prompt as argv (`exec <prompt>`) | Reject prompts over 100 KB for Codex with an inline message; Claude reads stdin |
| Upstream merge conflicts | `EditorView.swift` changes often upstream | One-line insertion, documented in `upstream-sync.md`; everything else is in new files |

## 9. Questions for the owner

1. Read-only agent in v1 (proposed) or should it be able to change `project.json` immediately? If yes, through which mechanism: direct file edit or an MCP server we write?
2. Working directory: the `.frm` bundle (agent can read the media files) or a sandbox subfolder with only `project.json` visible?
3. Transcripts inside the bundle travel with a shared project. Acceptable, or should they be stripped on export/share?
4. Resolved by ADR 0010: one fresh process per turn is acceptable; the logical provider session resumes through its stored id.
5. Provider preference: global (`ConfigService`, proposed) or per project?
6. Which shortcut toggles the panel? Adding a `ShortcutAction` case edits `Reframed/Utilities/KeyboardShortcut.swift` (upstream); the alternative is no shortcut in v1.
7. Provenance of copied Toone code: add a `LICENSE` to `apps/toone-desktop`, or record authorisation in an ADR here?
8. Should the app refuse to run the agent while an export is in progress (`editorState.isExporting`) to keep CPU for the encoder?
