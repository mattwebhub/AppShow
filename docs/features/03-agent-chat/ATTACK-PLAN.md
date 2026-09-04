# Attack plan: agent chat panel

Companion to `SPIKE.md`. Rules from `planning/tdd-strategy.md`: failing test first, one behaviour per test named as a sentence, no test touches `~/.reframed`, `~/.claude`, `~/.codex`, the network, or a real CLI. Tiers T1/T2/T3 are from `docs/architecture/07-testability.md` §1. Sizes: S ≤ 1 day, M 2–3 days, L 4–6 days.

Toone paths below are relative to `/Users/matheusparanhos/Projects/toone/apps/toone-desktop/Toone`.

## Toone files to copy first, in this order

| # | Toone file (lines) | Lands as | What to strip while copying |
| --- | --- | --- | --- |
| 1 | `Toone/Core/Services/AIService/Claude/ClaudeCommandBuilder.swift:15-122` | `Reframed/Agent/ClaudeCodeProvider.swift` (arguments half) | `AISessionOptions`, MCP lockdown branches (45-72), budget flags |
| 2 | `Toone/Core/Services/AIService/Codex/CodexCommandBuilder.swift:11-111` | `Reframed/Agent/CodexProvider.swift` (arguments half) | `AIModel`, image attachments |
| 3 | `Toone/Core/Services/AIService/Claude/ClaudeMessageParser.swift:35-147` | `ClaudeCodeProvider.swift` (parser half), rewritten on `Codable` structs | `Log.ai`, plan/task/MCP projections (205-667) |
| 4 | `Toone/Core/Services/AIService/Codex/CodexMessageParser.swift:29-44, 181-227, 420-476, 904-965, 1009-1063` | `CodexProvider.swift` (parser half) | app-server adapter (46-285), `Log.ai`, plan snapshots |
| 5 | `TooneTests/Services/CodexCommandBuilderTests.swift:129-142`, `TooneTests/Services/ThreadTitleServiceTests.swift:114-115`, `TooneTests/Services/ChatProgressSafetyTests.swift:112-163` | `ReframedTests/Fixtures/agent/*.ndjson` | Convert inline literals to one file per scenario; add lines recorded from the installed CLIs |
| 6 | `Toone/Features/Setup/Models/AIProviderReadiness.swift:8-62` + `TooneTests/Features/AIProviderReadinessTests.swift` | `Reframed/Agent/AgentReadiness.swift`, `ReframedTests/Agent/AgentReadinessTests.swift` | add `.notLoggedIn` |
| 7 | `Toone/Features/Setup/Services/AIProviderDiscoveryService.swift:111-178`, `Toone/Core/Services/CLIManager/ToolchainResolver.swift:151-162, 210-246`, `Toone/Core/Services/CLIManager/AIProviderCandidateSelector.swift:14-20` | `Reframed/Agent/AgentToolchain.swift` | `@unchecked Sendable` → actor; login-shell fallback |
| 8 | `Toone/Core/Services/AIService/Base/BaseAIService.swift:244-391, 494-581, 623-727` | `Reframed/Agent/AgentProcessRunner.swift` (as a reference, not a copy) | everything; only the sequence of operations survives |
| 9 | `Toone/Features/Chat/Views/MarkdownTextView.swift:35-53, 59-610, 614-833, 877-1074` | `Reframed/Agent/AgentMarkdownView.swift` (+ `AgentMarkdownParser.swift` for the pure block parser) | `Colors.`, `layoutStyle`, `appEnvironment`, Mermaid |
| 10 | `Toone/Features/Chat/Views/RichMessageBubble.swift:852-867, 880-1004, 1040-1062` | `AgentStreamingCursor.swift`, `AgentToolCallRow.swift` | file-viewer links, `DesignTokens` |
| 11 | `Toone/Features/Chat/Views/ChatPanelView.swift:136-186` | `Reframed/Agent/AgentTranscriptLayoutPolicy.swift` | nothing |
| 12 | `Toone/Features/Chat/Models/ThreadActivityState.swift:10-68` | `Reframed/Agent/AgentThreadActivity.swift` | `RoutineExecution` |
| 13 | `Toone/Features/Chat/Models/SlashSubmissionResolver.swift:8-41` | `Reframed/Agent/AgentSlashResolver.swift` (phase 7) | nothing |

## Phase 1 — provider protocol and stream parsers (pure) · size M · T1

Failing tests first, all in `ReframedTests/Agent/`:

| Test | File | Assertion |
| --- | --- | --- |
| `claudeArgumentsForFirstTurnUseStreamJsonAndReadOnlyTools` | `ClaudeCodeProviderTests.swift` | `launchArguments(prompt:resume:nil,...)` equals `["-p","--output-format","stream-json","--verbose","--permission-mode","default","--allowedTools","Read","--allowedTools","Glob","--allowedTools","Grep"]` |
| `claudeArgumentsForResumedTurnAppendResumeId` | same | array ends with `["--resume","abc"]` |
| `claudeArgumentsNeverContainSkipPermissions` | same | `!args.contains("--dangerously-skip-permissions")` |
| `claudeSystemInitYieldsSessionStarted` | same | parsing the `system/init` fixture line gives `.sessionStarted("…")` |
| `claudeAssistantTextBlockYieldsAssistantText` | same | `.assistantText("Looking at project.json…")` |
| `claudeToolUseBlockYieldsToolCallWithSummary` | same | `.toolCall(id:"toolu_01", name:"Read", inputSummary:"project.json")` |
| `claudeToolResultYieldsToolResultWithErrorFlag` | same | `.toolResult(id:"toolu_01", isError:false)` |
| `claudeResultWithIsErrorTrueIsAFailedTurn` | same | `.turnCompleted(isError:true, …)` for `subtype:"error_during_execution"` |
| `claudeStructuredOutputWinsOverResultText` | same | ported from `ChatProgressSafetyTests.swift:112-126` |
| `claudeUnknownEnvelopeKeepsRawLine` | same | `.system(raw)` and no throw |
| `claudeMalformedLineReturnsNil` | same | `parse(line:"not json") == nil` |
| `codexArgumentsForFirstTurnUseExecJsonReadOnly` | `CodexProviderTests.swift` | `["exec", prompt, "--json", "--skip-git-repo-check", "--sandbox", "read-only"]` |
| `codexArgumentsForResumedTurnUseExecResume` | same | `["exec","resume","019f…", prompt, "--json","--skip-git-repo-check","--sandbox","read-only"]` |
| `codexArgumentsNeverContainBypassOrFullAuto` | same | ported from `CodexCommandBuilderTests.swift:48-88` |
| `codexThreadStartedYieldsSessionStarted` | same | fixture `{"type":"thread.started","thread_id":"019f-codex-thread"}` |
| `codexAgentMessageYieldsAssistantText` | same | fixture from `ThreadTitleServiceTests.swift:115` |
| `codexCommandExecutionYieldsToolCallAndResult` | same | two events for one `command_execution` item, `isError` true when `exit_code != 0` |
| `codexTurnCompletedWithNullErrorIsNotAFailure` | same | pins the `NSNull` trap; decoded with `Codable` so `"error": null` is `nil` |
| `codexTurnFailedYieldsFailedTurn` | same | `.turnCompleted(isError:true, …)` |
| `codexReusedItemIdsDoNotCollide` | `AgentEventTests.swift` | two `item_0` messages produce distinct transcript ids (see phase 3) |
| `fixtureFilesParseWithoutUnknownEvents` | `AgentFixtureTests.swift` | `@Test(arguments:)` over every `ReframedTests/Fixtures/agent/*.ndjson`: no `.system(raw)` from a known line |

Production: `Reframed/Agent/AgentProvider.swift`, `AgentEvent.swift`, `ClaudeCodeProvider.swift`, `CodexProvider.swift`; fixtures under `ReframedTests/Fixtures/agent/` (`claude-2.1-turn.ndjson`, `claude-2.1-tool-error.ndjson`, `codex-0.14-turn.ndjson`, `codex-0.14-failed.ndjson`), each ≤ 20 KB, plus `ReframedTests/Support/Fixtures.swift` with the `FixtureAnchor` class that `planning/tdd-strategy.md` already specifies.

Manual check: none (pure).

## Phase 2 — process runner and cancellation · size M · T2

| Test | File | Assertion |
| --- | --- | --- |
| `runnerStreamsEachStdoutLineInOrder` | `AgentProcessRunnerTests.swift` | run `/bin/sh -c 'printf "a\nb\nc\n"'` → `["a","b","c"]` |
| `runnerDeliversLinesSplitAcrossReads` | same | `/bin/sh -c 'printf "ab"; sleep 0.1; printf "c\n"'` → `["abc"]` |
| `runnerFinishesStreamWhenProcessExits` | same | iteration ends; exit status 0 surfaced |
| `runnerThrowsOnNonZeroExit` | same | `/usr/bin/false` → `AgentError.processFailed(status: 1, stderrTail:)` |
| `runnerWritesPromptToStdinThenClosesIt` | same | `/bin/cat` echoes the prompt back as the only line |
| `runnerTerminatesProcessOnTaskCancellation` | same | `/bin/sleep 30`; cancel the consuming task; `isRunning == false` within 1 s |
| `runnerWatchdogFailsSilentProcess` | same | `/bin/sleep 30` with watchdog 0.2 s → `AgentError.inactivity` |
| `runnerCapsLineAtOneMegabyte` | same | `/bin/sh -c 'head -c 2000000 /dev/zero | tr "\0" x; echo'` → `AgentError.lineTooLong`, process terminated |
| `runnerUsesOnlyTheGivenEnvironment` | same | `/usr/bin/env` output contains `PATH` and `HOME` and not `REFRAMED_HOME` |
| `runnerRunsInTheGivenWorkingDirectory` | same | `/bin/pwd` prints the temp directory |
| `sessionMapsLinesToEventsAndRecordsSessionId` | `AgentSessionTests.swift` | `/bin/cat` fed the Claude fixture → events equal phase 1 expectations, `sessionID == "…"` |
| `sessionSecondTurnPassesResumeId` | same | a `RecordingProvider` test double captures `resume:` on the second `send` |
| `sessionCancelTerminatesAndLeavesThreadResumable` | same | after `cancel()`, `sessionID` is retained |

Production: `Reframed/Agent/AgentProcessRunner.swift` (actor), `AgentSession.swift` (actor), `AgentError.swift` (`LocalizedError`, own type; do not extend `CaptureError`). Tests use `@Suite(.serialized)` and `FileManager.default.temporaryDirectory/<UUID>` per `tdd-strategy.md` rule 4.

Manual check: Activity Monitor shows no `claude`/`codex` process after closing the editor window (T3, record in `VERIFY.md`).

## Phase 3 — transcript model and persistence · size M · T1/T2

| Test | File | Assertion |
| --- | --- | --- |
| `threadDataRoundTripsThroughJson` | `AgentThreadDataTests.swift` | encode → decode equality with `.iso8601` dates |
| `messageContentWithUnknownTypeDecodesAsText` | same | forward-compatible discriminator |
| `legacyThreadWithoutProviderFieldDecodesAsClaude` | same | `decodeOrDefault` path |
| `assistantTextEventReplacesStreamingMessageText` | `AgentTranscriptTests.swift` (`@MainActor`) | two `.assistantText` events → one message, `isStreaming == true`, latest text |
| `toolCallEventAppendsToolRowToStreamingMessage` | same | content array gains `.toolCall(status: .executing)` |
| `toolResultEventCompletesMatchingToolRow` | same | status `.completed`/`.failed` by `isError` |
| `turnCompletedFinalisesMessageAndClearsRunning` | same | `isStreaming == false`, `isRunning == false` |
| `failedTurnMarksMessageFailedWithReason` | same | `status == .failed`, reason text present |
| `sessionStartedStoresProviderScopedSessionId` | same | `thread.sessionID == "…"`, `thread.provider == .claudeCode` |
| `switchingProviderStartsANewThread` | same | old thread untouched, new thread has `sessionID == nil` |
| `transcriptIdsAreUniqueAcrossCodexItemReuse` | same | closes phase-1 `codexReusedItemIdsDoNotCollide` |
| `transcriptSavesToAgentDirectoryInsideBundle` | `AgentTranscriptPersistenceTests.swift` | temp `.frm` dir; `agent/threads.json` and `agent/<id>.json` exist, sorted keys |
| `transcriptLoadsThreadsAndLastActiveThread` | same | round trip through a temp bundle |
| `transcriptSaveIsDebouncedAndFlushedOnTurnEnd` | same | one write after N events, another on completion |
| `renamedProjectKeepsAgentDirectory` | `ReframedProjectTests.swift` | `ReframedProject.rename(to:)` on a temp bundle with `agent/` moves it |

Production: `AgentThreadData.swift`, `AgentTranscript.swift`, `AgentTranscript+Persistence.swift`. `AgentTranscript` takes the session as a protocol (`AgentSessionProviding`) so tests inject a scripted double instead of a process.

Manual check: none.

## Phase 4 — collapsible panel shell in the editor (no AI) · size S · T2/T3

| Test | File | Assertion |
| --- | --- | --- |
| `stateServiceDefaultsToExpandedPanelWithDefaultWidth` | `ReframedTests/State/StateServiceTests.swift` | seam S2 `init(fileURL:)` on a temp file: `agentPanelCollapsed == false`, `agentPanelWidth == nil` |
| `stateServicePersistsPanelCollapsedAndWidth` | same | set, reload from file, equal |
| `panelWidthIsClampedToLayoutBounds` | `AgentPanelLayoutTests.swift` | `AgentPanelLayout.clamp(250) == 260`, `clamp(900) == 480` |
| `configServiceDefaultsAgentProviderToClaude` | `ReframedTests/State/ConfigServiceTests.swift` | merged-defaults load |

Production: `Layout` constants (`Reframed/UI/Constants.swift`), `StateService`/`ConfigService` fields, `Reframed/Agent/AgentPanelLayout.swift` (pure clamp), `AgentChatPanel.swift` + `+Header.swift` with a placeholder transcript area, the one-line insertion in `EditorView.swift:43`, the `EditorState.agentTranscript` property. Card chrome copied from `EditorView.swift:44-55`; toggle via `IconButton`; drag handle on the trailing edge; hidden in preview mode.

Manual check (T3): expand/collapse animates with `.easeInOut(duration: 0.2)` like the timeline signature animation (`EditorView.swift:77`); width survives quit and relaunch; window at 1400×900 still shows the full properties panel; light and dark appearance both use `backgroundCard` and `border`.

## Phase 5 — message rendering (markdown, tool calls, streaming) · size L · T1/T3

| Test | File | Assertion |
| --- | --- | --- |
| `parserSplitsParagraphsHeadingsListsAndFences` | `AgentMarkdownParserTests.swift` | block types and ranges for a 30-line sample |
| `parserKeepsUnterminatedFenceOpenWhileStreaming` | same | trailing ``` without close → one `.codeBlock` with `isStreaming` |
| `parserRendersInlineCodeBoldAndLinksIntoAttributedString` | same | runs carry `.inlinePresentationIntent` |
| `parserFallsBackToPlainTextAbove64KB` | same | ported threshold from `MarkdownTextView.swift:65` |
| `layoutPolicyUsesEagerBelowEightyMessages` | `AgentTranscriptLayoutPolicyTests.swift` | ported from `ChatPanelView.swift:136-186` |
| `toolRowGroupingCollapsesCompletedToolsIntoSummary` | `AgentToolCallGroupingTests.swift` | `"Read, +2"` summary from three completed rows, executing rows kept separate |
| `toolIconMapCoversAllKnownToolNames` | same | `@Test(arguments:)` over the SF Symbol map |

Production: `AgentMarkdownParser.swift` (pure), `AgentMarkdownView.swift`, `AgentCodeBlockView.swift` (monospaced, copy button with `PlainCustomButtonStyle`), `AgentToolCallRow.swift`, `AgentStreamingCursor.swift`, `AgentChatPanel+Transcript.swift`, `AgentChatPanel+Composer.swift` (`TextField(axis: .vertical).lineLimit(2...12)`, Return sends, Shift-Return newline, send button `PrimaryButtonStyle(size: .small)`), `AgentTranscriptLayoutPolicy.swift`. Text selection enabled on all assistant text.

Manual check (T3): a 300-line assistant reply scrolls without jank; streaming cursor blinks; copy button copies the code only; Cmd-Z in the composer does not reach `EditorState.undo()` (the `NSTextView` guard at `EditorWindow.swift:104-106` covers field editors; verify it covers the multi-line field).

## Phase 6 — provider setup and detection UI · size M · T2/T3

| Test | File | Assertion |
| --- | --- | --- |
| `readinessLabelsAreDistinctPerState` | `AgentReadinessTests.swift` | ported from `AIProviderReadinessTests.swift`, plus `.notLoggedIn` |
| `toolchainFindsBinaryInFirstMatchingSearchDirectory` | `AgentToolchainTests.swift` | temp dirs, fake executable, injected search list |
| `toolchainIgnoresNonExecutableFiles` | same | mode 0644 file is skipped |
| `probeParsesSemanticVersionFromVersionOutput` | same | `"2.1.259 (Claude Code)"` → `"2.1.259"`, `"codex-cli 0.149.1"` → `"0.149.1"` |
| `probeReportsUnhealthyWhenVersionCommandTimesOut` | same | fixture script that sleeps; timeout 0.2 s |
| `probeReportsNotLoggedInFromClaudeAuthStatusJson` | same | fixture script printing `{"loggedIn":false}` |
| `probeReportsReadyFromCodexLoginStatusExitZero` | same | fixture script printing `Logged in using ChatGPT` |
| `singleReadyProviderIsPreselected` | same | `AgentReadinessSnapshot.selection(remembered:)` |

Production: `AgentReadiness.swift`, `AgentToolchain.swift` (actor `AgentProbe` with injectable search directories and executable overrides), `AgentChatPanel+Setup.swift` (setup card per state from `SPIKE.md` §6), provider `SegmentPicker` popover in the header. Fixture scripts live in `ReframedTests/Fixtures/agent/bin/` and are marked executable by `scripts/make-fixtures.swift`.

Manual check (T3): on a machine with neither CLI the panel shows the `.missing` card and the searched directories; after `brew install`/`npm i -g` "Check again" flips to ready without restarting; logged-out state shows the Terminal instruction.

## Phase 7 — thread management · size S · T1/T2

| Test | File | Assertion |
| --- | --- | --- |
| `newThreadBecomesActiveAndIsPersisted` | `AgentTranscriptTests.swift` | count +1, `activeThreadID` updated, `threads.json` rewritten |
| `deletingActiveThreadActivatesMostRecentRemaining` | same | ordering by `lastActivityAt` |
| `threadTitleDefaultsToFirstPromptTruncatedToSixtyCharacters` | same | no model call for titles in v1 |
| `slashClearResolvesToBuiltinClear` | `AgentSlashResolverTests.swift` | ported from `SlashSubmissionResolver.swift` |
| `slashNewResolvesToBuiltinNew` | same | |
| `textStartingWithSlashButUnknownIsAMessage` | same | falls through to `.message` |
| `activityLifecycleMapsRunningAndFailedStates` | `AgentThreadActivityTests.swift` | ported from `ThreadActivityState.swift:10-46` |

Production: thread strip in `AgentChatPanel+Header.swift` (bare `SectionHeader(title: "Threads")`, rows with `PlainCustomButtonStyle` and `.hoverEffect(id:)`), `AgentSlashResolver.swift`, `AgentThreadActivity.swift`, the status dot on the collapsed rail.

Manual check (T3): two threads on the same project resume independently after quit and relaunch, each on its own provider session id.

## Parallelism, order, and size

| Phase | Depends on | Can run alongside | Size |
| --- | --- | --- | --- |
| 1 parsers | — | 4, 5 | M |
| 2 runner | 1 (events) | 4, 5 | M |
| 3 transcript | 1 | 4, 5 | M |
| 4 panel shell | — | 1, 2, 3 | S |
| 5 rendering | 4 (shell), 3 (model shape) | 1, 2 | L |
| 6 setup UI | 2 (probe uses the runner), 4 | 5, 7 | M |
| 7 threads | 3, 4 | 5, 6 | S |

Two people: one takes 1 → 2 → 3 → 6 (runtime), the other 4 → 5 → 7 (UI); they meet at the `AgentTranscript` API, which is frozen at the end of phase 3 and stubbed with a scripted double for the UI track until then. Total: about 4–5 weeks for one developer, 3 weeks for two.

## Definition of done

- [ ] Every table row above exists as a test with that name; `make test` green locally and in CI; suites under `ReframedTests/Agent/` and the two `State/` suites.
- [ ] No test launches `claude` or `codex`; fixtures under `ReframedTests/Fixtures/agent/` are ≤ 20 KB each, named with the CLI version they were recorded from.
- [ ] `make format`, `make lint`, `make build` clean, zero warnings; no comments in new Swift files; every colour, size, and radius comes from `ReframedColors`/`FontSize`/`Radius`/`Layout`; only the four allowed button styles.
- [ ] No `[String: Any]` crosses an actor boundary; no `@unchecked Sendable` in `Reframed/Agent/`; no `NSLock`.
- [ ] The only upstream files edited are those in `SPIKE.md` §5.6, each additive, each listed in `planning/upstream-sync.md`.
- [ ] `--dangerously-skip-permissions` and `--dangerously-bypass-approvals-and-sandbox` appear nowhere under `Reframed/` (a grep test, `AgentSafetyTests.swift`, enforces it).
- [ ] T3 checklist run on a machine with both CLIs, with one, and with none; results in the milestone `VERIFY.md`; no orphan process after closing the editor.
- [ ] ADR in `planning/decisions/` covering the module boundary, the one-process-per-turn decision, the transcript location, and the provenance of copied Toone code.
- [ ] `docs/architecture/01-module-map.md` gains an `Agent/` section and `02-concurrency.md` lists the two new actors.
