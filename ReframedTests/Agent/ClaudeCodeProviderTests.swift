import Foundation
import Testing

@testable import Reframed

struct ClaudeCodeProviderTests {
  private let provider = ClaudeCodeProvider()
  private let firstTurnArguments = [
    "-p", "--output-format", "stream-json", "--verbose", "--permission-mode", "default",
    "--allowedTools", "Read", "--allowedTools", "Glob", "--allowedTools", "Grep",
  ]

  @Test func identityDescribesTheClaudeCodeRuntime() {
    #expect(provider.id == .claudeCode)
    #expect(provider.displayName == "Claude Code")
    #expect(provider.executableNames == ["claude"])
    #expect(AgentProviderKind.claudeCode.rawValue == "claude")
  }

  @Test func claudeArgumentsForFirstTurnUseStreamJsonAndReadOnlyTools() {
    let turn = AgentTurn(prompt: "Summarize project.json")
    #expect(provider.arguments(for: turn) == firstTurnArguments)
  }

  @Test func claudeArgumentsForResumedTurnAppendResumeId() {
    let turn = AgentTurn(prompt: "Continue", resumeID: "abc")
    #expect(provider.arguments(for: turn) == firstTurnArguments + ["--resume", "abc"])
  }

  @Test func claudeConfiguredTurnUsesOnlyTheGeneratedMCPFile() {
    let config = AgentSessionConfig.testFixture
    let turn = AgentTurn(prompt: "Edit", configuration: config)

    #expect(
      provider.arguments(for: turn)
        == firstTurnArguments + [
          "--mcp-config", config.claudeConfigURL.path,
          "--strict-mcp-config",
          "--allowedTools", "mcp__appshow__*",
        ]
    )
  }

  @Test func claudePromptGoesToStandardInputAndNeverToArguments() {
    let prompt = "Review $(touch /tmp/never) `whoami` and $HOME"
    let turn = AgentTurn(prompt: prompt)
    #expect(provider.standardInput(for: turn) == prompt)
    #expect(!provider.arguments(for: turn).contains(prompt))
  }

  @Test func claudeSystemInitYieldsSessionStarted() throws {
    let events = provider.parse(line: try AgentFixtures.line("claude-2.1.260-turn", 2))
    #expect(events == [.sessionStarted(id: "0e5ac684-a18e-4f1f-a028-e63b1d1b8e3b")])
  }

  @Test func claudeHookSystemEventsYieldNothing() throws {
    #expect(provider.parse(line: try AgentFixtures.line("claude-2.1.260-turn", 0)).isEmpty)
    #expect(provider.parse(line: try AgentFixtures.line("claude-2.1.260-turn", 1)).isEmpty)
  }

  @Test func claudeAssistantTextBlockYieldsTextDelta() throws {
    let events = provider.parse(line: try AgentFixtures.line("claude-2.1.260-turn", 6))
    #expect(events == [.textDelta("reframed fixture note")])
  }

  @Test func claudeToolUseBlockYieldsToolCallStarted() throws {
    let events = provider.parse(line: try AgentFixtures.line("claude-2.1.260-turn", 3))
    #expect(
      events == [
        .toolCallStarted(
          id: "toolu_01GU1tRDPHffpwKnUaexW1Mw",
          name: "Read",
          input: #"{"file_path":"/Users/example/Movies/Reframed/demo.frm/note.txt"}"#
        )
      ]
    )
  }

  @Test func claudeToolResultYieldsToolCallFinished() throws {
    let events = provider.parse(line: try AgentFixtures.line("claude-2.1.260-turn", 5))
    #expect(events == [.toolCallFinished(id: "toolu_01GU1tRDPHffpwKnUaexW1Mw", output: "1\treframed fixture note\n2\t", isError: false)])
  }

  @Test func claudeErrorToolResultIsFlagged() throws {
    let events = provider.parse(line: try AgentFixtures.line("claude-2.1.260-tool-error", 4))
    guard case .toolCallFinished(let id, let output, let isError)? = events.first else {
      Issue.record("expected toolCallFinished, got \(events)")
      return
    }
    #expect(id == "toolu_014rAPiVWYHPjwUczdULtYWe")
    #expect(output.hasPrefix("File does not exist."))
    #expect(isError)
  }

  @Test func claudeResultYieldsCompletedTurn() throws {
    let events = provider.parse(line: try AgentFixtures.line("claude-2.1.260-turn", 7))
    #expect(
      events == [
        .turnCompleted(AgentTurnResult(isError: false, text: "reframed fixture note", costUSD: 0.25405649999999996, durationMs: 7305))
      ]
    )
  }

  @Test func claudeResultWithIsErrorTrueIsAFailedTurn() throws {
    let events = provider.parse(line: try AgentFixtures.line("claude-toone-literals", 5))
    #expect(
      events == [.turnCompleted(AgentTurnResult(isError: true, text: "Claude refused: usage policy", costUSD: 0.02, durationMs: 800))]
    )
  }

  @Test func claudeNonSuccessSubtypeIsAFailedTurnEvenWithoutIsError() {
    let line = #"{"type":"result","subtype":"error_max_turns","result":"","session_id":"s"}"#
    guard case .turnCompleted(let result)? = provider.parse(line: line).first else {
      Issue.record("expected turnCompleted")
      return
    }
    #expect(result.isError)
  }

  @Test func claudeStructuredOutputWinsOverResultText() throws {
    let events = provider.parse(line: try AgentFixtures.line("claude-toone-literals", 4))
    #expect(
      events == [.turnCompleted(AgentTurnResult(isError: false, text: #"{"answer":"schema-bound"}"#, costUSD: 0.01, durationMs: 1200))]
    )
  }

  @Test func claudeErrorEnvelopeYieldsError() throws {
    let events = provider.parse(line: try AgentFixtures.line("claude-toone-literals", 6))
    #expect(events == [.error(message: "Connection interrupted")])
    #expect(provider.parse(line: #"{"type":"error","message":"plain"}"#) == [.error(message: "plain")])
  }

  @Test func claudeRateLimitEventYieldsNothing() throws {
    #expect(provider.parse(line: try AgentFixtures.line("claude-2.1.260-turn", 4)).isEmpty)
  }

  @Test func claudeToolResultWithContentBlocksJoinsTheirText() {
    let line =
      #"{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t1","content":[{"type":"text","text":"a"},{"type":"text","text":"b"}]}]}}"#
    #expect(provider.parse(line: line) == [.toolCallFinished(id: "t1", output: "ab", isError: false)])
  }

  @Test func claudeAssistantMessageWithTextAndToolUseYieldsBothInOrder() {
    let line =
      #"{"type":"assistant","message":{"content":[{"type":"text","text":"Reading"},{"type":"tool_use","id":"t2","name":"Glob","input":{"pattern":"*.json"}}]}}"#
    #expect(
      provider.parse(line: line) == [.textDelta("Reading"), .toolCallStarted(id: "t2", name: "Glob", input: #"{"pattern":"*.json"}"#)]
    )
  }

  @Test func claudeUnknownEnvelopeYieldsUnknown() {
    #expect(provider.parse(line: #"{"type":"whatever","payload":1}"#) == [.unknown(type: "whatever")])
    #expect(provider.parse(line: #"{"payload":1}"#) == [.unknown(type: "")])
  }

  @Test func claudeMalformedLineYieldsNothing() {
    #expect(provider.parse(line: "not json").isEmpty)
    #expect(provider.parse(line: "").isEmpty)
    #expect(provider.parse(line: "[1,2]").isEmpty)
  }

  @Test(arguments: AgentFixtures.recordedClaude)
  func claudeRecordedFixtureParsesWithoutUnknownEvents(name: String) throws {
    let events = try AgentFixtures.events(name, provider: provider)
    let unknown = events.filter {
      if case .unknown = $0 { return true }
      return false
    }
    #expect(unknown.isEmpty)
    let started = events.filter {
      if case .sessionStarted = $0 { return true }
      return false
    }
    let completed = events.filter {
      if case .turnCompleted = $0 { return true }
      return false
    }
    #expect(started.count == 1)
    #expect(completed.count == 1)
    #expect(events.last == completed.first)
  }

  @Test func claudeResumedFixtureReportsTheSameSessionId() throws {
    let first = try AgentFixtures.events("claude-2.1.260-turn", provider: provider)
    let resumed = try AgentFixtures.events("claude-2.1.260-resume", provider: provider)
    #expect(first.first == .sessionStarted(id: "0e5ac684-a18e-4f1f-a028-e63b1d1b8e3b"))
    #expect(resumed.first == first.first)
    #expect(resumed.contains(.textDelta("second turn")))
  }
}
