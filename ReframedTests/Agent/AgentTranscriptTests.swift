import Foundation
import Testing

@testable import Reframed

@MainActor
@Suite(.serialized)
struct AgentTranscriptTests {
  private func makeTranscript() -> AgentTranscript {
    AgentTranscript(store: nil)
  }

  private func streamingAssistant(_ transcript: AgentTranscript) -> AgentMessageData? {
    transcript.messages.last { $0.role == .assistant }
  }

  @Test func newTranscriptWithoutStoreStartsWithOneEmptyConversation() {
    let transcript = AgentTranscript(store: nil)
    #expect(transcript.messages.isEmpty)
    #expect(transcript.provider == .claudeCode)
    #expect(transcript.resumeIDs.isEmpty)
    #expect(!transcript.isRunning)
    #expect(!transcript.isCancelled)
  }

  @Test func providerChangesWithinTheSameConversation() {
    let transcript = AgentTranscript(store: nil)
    transcript.appendUserMessage("Keep this")
    transcript.setProvider(.codex)
    #expect(transcript.provider == .codex)
    #expect(transcript.messages.map(\.text) == ["Keep this"])
  }

  @Test func clearResetsTheOnlyConversationAndKeepsProvider() {
    let transcript = AgentTranscript(store: nil)
    transcript.setProvider(.codex)
    transcript.appendUserMessage("Remove this")
    transcript.beginAssistantMessage()
    transcript.apply(.sessionStarted(id: "session"))
    transcript.finishTurn(error: nil)
    #expect(transcript.clear())
    #expect(transcript.provider == .codex)
    #expect(transcript.messages.isEmpty)
    #expect(transcript.resumeIDs.isEmpty)
  }

  @Test func userMessageIsAppendedAsCompleted() {
    let transcript = makeTranscript()
    let message = transcript.appendUserMessage("Trim the intro")
    #expect(transcript.messages == [message])
    #expect(message.role == .user)
    #expect(message.status == .completed)
    #expect(message.text == "Trim the intro")
  }

  @Test func textDeltasAccumulateIntoOneStreamingAssistantMessage() {
    let transcript = makeTranscript()
    let id = transcript.beginAssistantMessage()
    transcript.apply(.textDelta("Looking at "))
    transcript.apply(.textDelta("project.json"))
    let assistant = streamingAssistant(transcript)
    #expect(transcript.messages.count == 1)
    #expect(assistant?.id == id)
    #expect(assistant?.status == .streaming)
    #expect(assistant?.content == [.text("Looking at project.json")])
    #expect(transcript.streamingMessageID == id)
  }

  @Test func toolCallStartedAppendsAnExecutingRowAfterTheText() {
    let transcript = makeTranscript()
    transcript.beginAssistantMessage()
    transcript.apply(.textDelta("Reading"))
    transcript.apply(.toolCallStarted(id: "toolu_01", name: "Read", input: "{\"file_path\":\"project.json\"}"))
    let content = streamingAssistant(transcript)?.content ?? []
    #expect(content.count == 2)
    guard case .toolCall(let row)? = content.last else {
      Issue.record("expected a tool row")
      return
    }
    #expect(row.callID == "toolu_01")
    #expect(row.name == "Read")
    #expect(row.input == "{\"file_path\":\"project.json\"}")
    #expect(row.status == .executing)
    #expect(row.output == nil)
  }

  @Test func toolCallFinishedCompletesTheMatchingRow() {
    let transcript = makeTranscript()
    transcript.beginAssistantMessage()
    transcript.apply(.toolCallStarted(id: "a", name: "Read", input: "x"))
    transcript.apply(.toolCallStarted(id: "b", name: "Grep", input: "y"))
    transcript.apply(.toolCallFinished(id: "a", output: "contents", isError: false))
    transcript.apply(.toolCallFinished(id: "b", output: "boom", isError: true))
    let rows = streamingAssistant(transcript)?.toolCalls ?? []
    #expect(rows.map(\.status) == [.completed, .failed])
    #expect(rows.map(\.output) == ["contents", "boom"])
  }

  @Test func repeatedToolCallStartedForTheSameIdDoesNotDuplicateTheRow() {
    let transcript = makeTranscript()
    transcript.beginAssistantMessage()
    transcript.apply(.toolCallStarted(id: "item_1", name: "Bash", input: "ls"))
    transcript.apply(.toolCallStarted(id: "item_1", name: "Bash", input: "ls"))
    transcript.apply(.toolCallFinished(id: "item_1", output: "a", isError: false))
    #expect(streamingAssistant(transcript)?.toolCalls.count == 1)
    #expect(streamingAssistant(transcript)?.toolCalls.first?.status == .completed)
  }

  @Test func toolCallFinishedWithoutAStartStillRecordsARow() {
    let transcript = makeTranscript()
    transcript.beginAssistantMessage()
    transcript.apply(.toolCallFinished(id: "orphan", output: "done", isError: false))
    let rows = streamingAssistant(transcript)?.toolCalls ?? []
    #expect(rows.count == 1)
    #expect(rows.first?.callID == "orphan")
    #expect(rows.first?.status == .completed)
  }

  @Test func textAfterAToolRowStartsANewTextBlock() {
    let transcript = makeTranscript()
    transcript.beginAssistantMessage()
    transcript.apply(.textDelta("Before"))
    transcript.apply(.toolCallStarted(id: "t", name: "Read", input: ""))
    transcript.apply(.textDelta("After"))
    let content = streamingAssistant(transcript)?.content ?? []
    #expect(content.count == 3)
    #expect(content.first == .text("Before"))
    #expect(content.last == .text("After"))
  }

  @Test func turnCompletedFinalisesTheMessageAndFinishTurnClearsRunning() {
    let transcript = makeTranscript()
    transcript.beginAssistantMessage()
    transcript.apply(.textDelta("done"))
    transcript.apply(.turnCompleted(AgentTurnResult(isError: false, text: "done", costUSD: 0.1, durationMs: 10)))
    #expect(streamingAssistant(transcript)?.status == .completed)
    #expect(streamingAssistant(transcript)?.content == [.text("done")])
    transcript.finishTurn(error: nil)
    #expect(!transcript.isRunning)
    #expect(transcript.streamingMessageID == nil)
  }

  @Test func failedTurnMarksTheMessageFailedWithTheReason() {
    let transcript = makeTranscript()
    transcript.beginAssistantMessage()
    transcript.apply(.turnCompleted(AgentTurnResult(isError: true, text: "Claude refused: usage policy")))
    #expect(streamingAssistant(transcript)?.status == .failed)
    #expect(streamingAssistant(transcript)?.failureReason == "Claude refused: usage policy")
  }

  @Test func errorEventMarksTheMessageFailed() {
    let transcript = makeTranscript()
    transcript.beginAssistantMessage()
    transcript.apply(.error(message: "Connection interrupted"))
    #expect(streamingAssistant(transcript)?.status == .failed)
    #expect(streamingAssistant(transcript)?.failureReason == "Connection interrupted")
  }

  @Test func finishTurnWithAnErrorMarksAStreamingMessageFailed() {
    let transcript = makeTranscript()
    transcript.beginAssistantMessage()
    transcript.finishTurn(error: AgentError.processFailed(status: 1, stderrTail: "boom"))
    #expect(streamingAssistant(transcript)?.status == .failed)
    #expect(streamingAssistant(transcript)?.failureReason == AgentError.processFailed(status: 1, stderrTail: "boom").errorDescription)
    #expect(transcript.lastError == AgentError.processFailed(status: 1, stderrTail: "boom").errorDescription)
  }

  @Test func sessionStartedStoresTheProviderResumeIdOnTheConversation() {
    let transcript = makeTranscript()
    transcript.beginAssistantMessage()
    transcript.apply(.sessionStarted(id: "sess-1"))
    #expect(transcript.resumeIDs[.claudeCode] == "sess-1")
    #expect(transcript.provider == .claudeCode)
  }

  @Test func unknownEventsAreIgnored() {
    let transcript = makeTranscript()
    transcript.beginAssistantMessage()
    transcript.apply(.unknown(type: "whatever"))
    #expect(streamingAssistant(transcript)?.content.isEmpty == true)
    #expect(streamingAssistant(transcript)?.status == .streaming)
  }

  @Test func markCancelledSetsTheCancelledState() {
    let transcript = makeTranscript()
    transcript.beginAssistantMessage()
    transcript.apply(.textDelta("partial"))
    transcript.markCancelled()
    #expect(transcript.isCancelled)
    #expect(!transcript.isRunning)
    #expect(streamingAssistant(transcript)?.status == .cancelled)
    #expect(streamingAssistant(transcript)?.content == [.text("partial")])
    transcript.beginAssistantMessage()
    #expect(!transcript.isCancelled)
  }

  @Test func replayingTheRecordedClaudeFixtureProducesTheExpectedTranscript() throws {
    let transcript = makeTranscript()
    transcript.beginAssistantMessage()
    for event in try AgentFixtures.events("claude-2.1.260-turn", provider: ClaudeCodeProvider()) {
      transcript.apply(event)
    }
    transcript.finishTurn(error: nil)
    let assistant = try #require(streamingAssistant(transcript))
    #expect(assistant.status == .completed)
    #expect(assistant.content.count == 2)
    guard case .toolCall(let row) = assistant.content[0] else {
      Issue.record("expected a tool row first")
      return
    }
    #expect(row.name == "Read")
    #expect(row.status == .completed)
    #expect(row.output == "1\treframed fixture note\n2\t")
    #expect(assistant.content[1] == .text("reframed fixture note"))
    #expect(transcript.resumeIDs[.claudeCode] == "0e5ac684-a18e-4f1f-a028-e63b1d1b8e3b")
  }

  @Test func replayingTheRecordedCodexFixtureProducesTheExpectedTranscript() throws {
    let transcript = AgentTranscript(store: nil, defaultProvider: .codex)
    transcript.beginAssistantMessage()
    for event in try AgentFixtures.events("codex-0.149.1-turn", provider: CodexProvider()) {
      transcript.apply(event)
    }
    transcript.finishTurn(error: nil)
    let assistant = try #require(streamingAssistant(transcript))
    #expect(assistant.status == .completed)
    #expect(assistant.content.count == 3)
    #expect(assistant.content.first == .text("I’ll read the file now."))
    guard case .toolCall(let row) = assistant.content[1] else {
      Issue.record("expected a tool row in the middle")
      return
    }
    #expect(row.name == "Bash")
    #expect(row.input == "/bin/zsh -lc 'cat note.txt'")
    #expect(row.output == "reframed fixture note\n")
    #expect(row.status == .completed)
    #expect(assistant.content.last == .text("reframed fixture note"))
    #expect(transcript.resumeIDs[.codex] == "01a06bb4-ffda-70f1-be3c-332c4b2c7a74")
  }

  @Test func codexItemIdsReusedAcrossTurnsDoNotCollide() {
    let transcript = makeTranscript()
    transcript.beginAssistantMessage()
    transcript.apply(.toolCallStarted(id: "item_1", name: "Bash", input: "ls"))
    transcript.apply(.toolCallFinished(id: "item_1", output: "first", isError: false))
    transcript.finishTurn(error: nil)
    transcript.beginAssistantMessage()
    transcript.apply(.toolCallStarted(id: "item_1", name: "Bash", input: "pwd"))
    transcript.apply(.toolCallFinished(id: "item_1", output: "second", isError: false))
    transcript.finishTurn(error: nil)
    let rows = transcript.messages.flatMap(\.toolCalls)
    #expect(rows.count == 2)
    #expect(rows[0].id != rows[1].id)
    #expect(rows.map(\.output) == ["first", "second"])
    #expect(Set(transcript.messages.map(\.id)).count == 2)
  }

  @Test func transcriptRoundTripsThroughAProjectBundle() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let sources = dir.appendingPathComponent("sources", isDirectory: true)
    try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)
    let result = try await ProjectFixtures.recordingResult(in: sources, webcam: false, systemAudio: false, microphone: false, cursor: false)
    let project = try ReframedProject.create(from: result, fps: result.fps, captureMode: .entireScreen, in: dir, cleanupTemp: false)
    let store = AgentConversationStore(project: project)
    let transcript = AgentTranscript(store: store, defaultProvider: .codex)
    #expect(transcript.messages.isEmpty)
    transcript.appendUserMessage("hello")
    transcript.beginAssistantMessage()
    transcript.apply(.sessionStarted(id: "019f"))
    transcript.apply(.textDelta("hi"))
    transcript.apply(.toolCallStarted(id: "item_1", name: "Bash", input: "ls"))
    transcript.apply(.toolCallFinished(id: "item_1", output: "a", isError: false))
    transcript.apply(.turnCompleted(AgentTurnResult()))
    transcript.finishTurn(error: nil)
    let file = project.bundleURL.appendingPathComponent("agent/conversation.json")
    #expect(FileManager.default.fileExists(atPath: file.path))
    let reloaded = AgentTranscript(store: store)
    #expect(reloaded.provider == .codex)
    #expect(reloaded.resumeIDs[.codex] == "019f")
    #expect(reloaded.messages == transcript.messages)
  }

  @Test func sendDrivesASessionAndPersistsTheResult() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let store = AgentConversationStore(directory: dir.appendingPathComponent("agent", isDirectory: true))
    let transcript = AgentTranscript(store: store)
    let fixture = try AgentFixtures.url("claude-2.1.260-turn")
    let session = AgentSession(
      provider: ScriptedProvider { _ in [fixture.path] },
      executable: URL(fileURLWithPath: "/bin/cat"),
      workingDirectory: dir,
      environment: AgentTestSupport.testEnvironment(home: dir)
    )
    transcript.send("Read the note", using: session)
    #expect(transcript.isRunning)
    await transcript.waitForTurn()
    #expect(!transcript.isRunning)
    #expect(!transcript.isCancelled)
    #expect(transcript.messages.count == 2)
    #expect(transcript.messages.first?.text == "Read the note")
    #expect(transcript.messages.last?.status == .completed)
    #expect(transcript.messages.last?.text == "reframed fixture note")
    #expect(transcript.resumeIDs[.claudeCode] == "0e5ac684-a18e-4f1f-a028-e63b1d1b8e3b")
    #expect(try store.load()?.messages == transcript.messages)
  }

  @Test func cancelDuringSendMarksTheTurnCancelled() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let transcript = makeTranscript()
    let script = try AgentTestSupport.hangingClaudeScript(in: dir)
    let session = AgentSession(
      provider: ScriptedProvider { _ in [] },
      executable: script,
      workingDirectory: dir,
      environment: AgentTestSupport.testEnvironment(home: dir)
    )
    transcript.send("go", using: session)
    let deadline = Date().addingTimeInterval(5)
    while transcript.messages.last?.text != "working", Date() < deadline {
      try await Task.sleep(for: .milliseconds(10))
    }
    transcript.cancel()
    await transcript.waitForTurn()
    #expect(transcript.isCancelled)
    #expect(!transcript.isRunning)
    #expect(transcript.messages.last?.status == .cancelled)
    #expect(transcript.messages.last?.text == "working")
    #expect(transcript.resumeIDs[.claudeCode] == "hang-session")
  }

  @Test func sendWhileRunningIsRefused() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let transcript = makeTranscript()
    let script = try AgentTestSupport.hangingClaudeScript(in: dir)
    let session = AgentSession(
      provider: ScriptedProvider { _ in [] },
      executable: script,
      workingDirectory: dir,
      environment: AgentTestSupport.testEnvironment(home: dir)
    )
    transcript.send("one", using: session)
    transcript.send("two", using: session)
    #expect(transcript.messages.filter { $0.role == .user }.count == 1)
    transcript.cancel()
    await transcript.waitForTurn()
    #expect(!transcript.isRunning)
  }
}
