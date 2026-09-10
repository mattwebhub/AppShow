import Foundation
import Testing

@testable import Reframed

struct CodexProviderTests {
  private let provider = CodexProvider()
  private let commonFlags = ["--json", "--skip-git-repo-check", "--sandbox", "read-only"]

  @Test func identityDescribesTheCodexRuntime() {
    #expect(provider.id == .codex)
    #expect(provider.displayName == "Codex")
    #expect(provider.executableNames == ["codex"])
    #expect(AgentProviderKind.codex.rawValue == "codex")
  }

  @Test func codexArgumentsForFirstTurnUseExecJsonReadOnly() {
    let turn = AgentTurn(prompt: "Summarize project.json")
    #expect(provider.arguments(for: turn) == ["exec"] + commonFlags + ["--", "Summarize project.json"])
    #expect(provider.standardInput(for: turn) == nil)
  }

  @Test func codexArgumentsForResumedTurnUseExecResumeWithFlagsFirst() {
    let turn = AgentTurn(prompt: "Continue", resumeID: "019f-session")
    #expect(provider.arguments(for: turn) == ["exec"] + commonFlags + ["resume", "--", "019f-session", "Continue"])
  }

  @Test func codexPromptIsPreservedAsOneLiteralArgumentAfterTheSeparator() {
    let prompt = "Review $(touch /tmp/never) `whoami` \"quoted\" and $HOME"
    let arguments = provider.arguments(for: AgentTurn(prompt: prompt))
    #expect(arguments.last == prompt)
    #expect(arguments.filter { $0 == prompt }.count == 1)
    #expect(arguments[arguments.count - 2] == "--")
  }

  @Test func codexThreadStartedYieldsSessionStarted() throws {
    let events = provider.parse(line: try AgentFixtures.line("codex-toone-literals", 0))
    #expect(events == [.sessionStarted(id: "019f-codex-thread")])
  }

  @Test func codexTurnStartedYieldsNothing() throws {
    #expect(provider.parse(line: try AgentFixtures.line("codex-toone-literals", 1)).isEmpty)
  }

  @Test func codexAgentMessageYieldsTextDelta() throws {
    let events = provider.parse(line: try AgentFixtures.line("codex-toone-literals", 2))
    #expect(events == [.textDelta("Postgres Timeout Investigation")])
  }

  @Test func codexCommandExecutionStartYieldsToolCallStarted() throws {
    let events = provider.parse(line: try AgentFixtures.line("codex-0.149.1-turn", 3))
    #expect(events == [.toolCallStarted(id: "item_1", name: "Bash", input: "/bin/zsh -lc 'cat note.txt'")])
  }

  @Test func codexCommandExecutionCompletionYieldsStartAndFinish() throws {
    let events = provider.parse(line: try AgentFixtures.line("codex-0.149.1-turn", 4))
    #expect(
      events == [
        .toolCallStarted(id: "item_1", name: "Bash", input: "/bin/zsh -lc 'cat note.txt'"),
        .toolCallFinished(id: "item_1", output: "reframed fixture note\n", isError: false),
      ]
    )
  }

  @Test func codexFailedCommandExecutionIsFlagged() throws {
    let events = provider.parse(line: try AgentFixtures.line("codex-0.149.1-command-error", 4))
    #expect(
      events.last == .toolCallFinished(id: "item_1", output: "ls: /nonexistent-reframed-dir: No such file or directory\n", isError: true)
    )
  }

  @Test func codexNonZeroExitCodeAloneMarksTheCommandFailed() {
    let line =
      #"{"type":"item.completed","item":{"id":"item_3","type":"command_execution","command":"false","aggregated_output":"","exit_code":2,"status":"completed"}}"#
    #expect(provider.parse(line: line).last == .toolCallFinished(id: "item_3", output: "", isError: true))
  }

  @Test func codexFunctionCallYieldsToolCallStarted() throws {
    let events = provider.parse(line: try AgentFixtures.line("codex-toone-literals", 3))
    #expect(
      events == [
        .toolCallStarted(
          id: "question-1",
          name: "request_user_input",
          input: #"{"questions":[{"id":"project-kind","header":"Project","question":"What are you building?","options":[]}]}"#
        )
      ]
    )
  }

  @Test func codexFunctionCallOutputYieldsToolCallFinished() {
    let line = #"{"type":"item.completed","item":{"id":"out-1","type":"function_call_output","call_id":"question-1","output":"done"}}"#
    #expect(provider.parse(line: line) == [.toolCallFinished(id: "question-1", output: "done", isError: false)])
  }

  @Test func codexMcpToolCallYieldsStartAndFinishWithErrorFromStatus() {
    let line =
      #"{"type":"item.completed","item":{"id":"mcp-1","type":"mcp_tool_call","server":"reframed","tool":"list_regions","arguments":{"track":"video"},"status":"failed","error":{"message":"no such track"}}}"#
    #expect(
      provider.parse(line: line) == [
        .toolCallStarted(id: "mcp-1", name: "list_regions", input: #"{"track":"video"}"#),
        .toolCallFinished(id: "mcp-1", output: "no such track", isError: true),
      ]
    )
  }

  @Test func codexFileChangeItemsYieldToolRows() {
    let line = #"{"type":"item.completed","item":{"id":"f-1","type":"file_read","path":"project.json","status":"completed"}}"#
    #expect(
      provider.parse(line: line) == [
        .toolCallStarted(id: "f-1", name: "Read", input: "project.json"),
        .toolCallFinished(id: "f-1", output: "", isError: false),
      ]
    )
  }

  @Test func codexReasoningItemYieldsNothing() {
    let line = #"{"type":"item.completed","item":{"id":"item_0","type":"reasoning","text":"thinking"}}"#
    #expect(provider.parse(line: line).isEmpty)
  }

  @Test func codexUserMessageEchoYieldsNothing() {
    let line = #"{"type":"item.completed","item":{"id":"u-1","type":"user_message","text":"hi"}}"#
    #expect(provider.parse(line: line).isEmpty)
  }

  @Test func codexTurnCompletedYieldsCompletedTurn() throws {
    let events = provider.parse(line: try AgentFixtures.line("codex-0.149.1-turn", 6))
    #expect(events == [.turnCompleted(AgentTurnResult(isError: false))])
  }

  @Test func codexTurnCompletedWithNullErrorIsNotAFailure() throws {
    let events = provider.parse(line: try AgentFixtures.line("codex-toone-literals", 5))
    #expect(events == [.turnCompleted(AgentTurnResult(isError: false))])
  }

  @Test func codexTurnCompletedWithErrorPayloadIsAFailure() {
    let line = #"{"type":"turn.completed","error":{"message":"quota exhausted"},"usage":{"total_cost":0.5,"duration_ms":42}}"#
    #expect(
      provider.parse(line: line) == [.turnCompleted(AgentTurnResult(isError: true, text: "quota exhausted", costUSD: 0.5, durationMs: 42))]
    )
  }

  @Test func codexInterruptedTurnStatusIsAFailure() {
    let line = #"{"type":"turn.completed","status":"interrupted"}"#
    guard case .turnCompleted(let result)? = provider.parse(line: line).first else {
      Issue.record("expected turnCompleted")
      return
    }
    #expect(result.isError)
  }

  @Test func codexTurnFailedYieldsFailedTurn() throws {
    let events = provider.parse(line: try AgentFixtures.line("codex-toone-literals", 6))
    #expect(events == [.turnCompleted(AgentTurnResult(isError: true, text: "Turn failed: rate limited"))])
  }

  @Test func codexErrorEventYieldsError() throws {
    let events = provider.parse(line: try AgentFixtures.line("codex-toone-literals", 7))
    #expect(events == [.error(message: "Handled error from server: Connection interrupted")])
  }

  @Test func codexUnknownEventYieldsUnknown() {
    #expect(provider.parse(line: #"{"type":"turn.plan","plan":[]}"#) == [.unknown(type: "turn.plan")])
    #expect(
      provider.parse(line: #"{"type":"item.completed","item":{"id":"x","type":"hologram"}}"#) == [.unknown(type: "item.completed/hologram")]
    )
  }

  @Test func codexMalformedLineYieldsNothing() {
    #expect(provider.parse(line: "Reading additional input from stdin...").isEmpty)
    #expect(provider.parse(line: "").isEmpty)
  }

  @Test(arguments: AgentFixtures.recordedCodex)
  func codexRecordedFixtureParsesWithoutUnknownEvents(name: String) throws {
    let events = try AgentFixtures.events(name, provider: provider)
    let unknown = events.filter {
      if case .unknown = $0 { return true }
      return false
    }
    #expect(unknown.isEmpty)
    #expect(
      events.first
        == .sessionStarted(id: events.first.flatMap { if case .sessionStarted(let id) = $0 { return id } else { return nil } } ?? "")
    )
    #expect(events.last == .turnCompleted(AgentTurnResult(isError: false)))
  }

  @Test func codexResumedFixtureReportsTheSameThreadId() throws {
    let first = try AgentFixtures.events("codex-0.149.1-turn", provider: provider)
    let resumed = try AgentFixtures.events("codex-0.149.1-resume", provider: provider)
    #expect(first.first == resumed.first)
    #expect(resumed.contains(.textDelta("second turn")))
  }
}
