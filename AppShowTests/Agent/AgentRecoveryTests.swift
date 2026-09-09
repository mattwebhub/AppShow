import Foundation
import Testing

@testable import AppShow

@MainActor
struct AgentRecoveryTests {
  @Test func eofWithoutCompletionPreservesPartialReplyAndOffersRecovery() {
    let transcript = AgentTranscript(store: nil)
    transcript.appendUserMessage("Zoom the chart")
    transcript.beginAssistantMessage()
    transcript.apply(.sessionStarted(id: "recover-me"))
    transcript.apply(.textDelta("I found the chart"))
    transcript.apply(.toolCallStarted(id: "pending", name: "add_zoom", input: "{}"))
    transcript.finishTurn(error: nil)
    #expect(transcript.messages.last?.status == .failed)
    #expect(transcript.messages.last?.text == "I found the chart")
    #expect(transcript.messages.last?.toolCalls.first?.status == .failed)
    #expect(transcript.recoveryPrompt?.contains("Zoom the chart") == true)
    #expect(transcript.resumeIDs[.claudeCode] == "recover-me")
    #expect(!transcript.isRunning)
  }

  @Test func retryUsesResumeIDWithoutDuplicatingUserRequest() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let partial = try AgentTestSupport.writeScript(
      """
      #!/bin/sh
      echo '{"type":"system","subtype":"init","session_id":"retained-id"}'
      echo '{"type":"assistant","message":{"content":[{"type":"text","text":"Partial"}]}}'
      """,
      name: "partial",
      in: dir
    )
    let transcript = AgentTranscript(store: AgentConversationStore(directory: dir.appendingPathComponent("chat")))
    let first = AgentSession(
      provider: ClaudeCodeProvider(),
      executable: partial,
      workingDirectory: dir,
      environment: AgentTestSupport.testEnvironment(home: dir)
    )
    transcript.send("Frame the chart", using: first)
    await transcript.waitForTurn()
    #expect(transcript.messages.last?.status == .failed)
    #expect(await first.isRunning == false)
    let resumed = try AgentFixtures.url("claude-2.1.260-resume")
    let provider = ScriptedProvider { turn in
      turn.resumeID == "retained-id" && turn.prompt.contains("Frame the chart") ? [resumed.path] : ["/missing-recovery-fixture"]
    }
    let retry = AgentSession(
      provider: provider,
      executable: URL(fileURLWithPath: "/bin/cat"),
      workingDirectory: dir,
      environment: AgentTestSupport.testEnvironment(home: dir),
      resumeIDs: transcript.resumeIDs
    )
    transcript.retry(using: retry)
    await transcript.waitForTurn()
    #expect(transcript.messages.filter { $0.role == .user }.count == 1)
    #expect(transcript.messages.count == 3)
    #expect(transcript.messages[1].text == "Partial")
    #expect(transcript.messages.last?.status == .completed)
    #expect(transcript.recoveryPrompt == nil)
  }

  @Test func terminalErrorReleasesTurnEvenWhenProviderDoesNotExit() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let script = try AgentTestSupport.writeScript(
      """
      #!/bin/sh
      echo '{"type":"error","error":{"message":"Connection lost"}}'
      while true; do sleep 0.05; done
      """,
      name: "disconnected",
      in: dir
    )
    let transcript = AgentTranscript(store: nil)
    let session = AgentSession(
      provider: ClaudeCodeProvider(),
      executable: script,
      workingDirectory: dir,
      environment: AgentTestSupport.testEnvironment(home: dir)
    )
    transcript.send("Continue", using: session)
    let deadline = Date().addingTimeInterval(2)
    while transcript.isRunning && Date() < deadline { try await Task.sleep(for: .milliseconds(20)) }
    let released = !transcript.isRunning
    if !released { transcript.cancel() }
    await transcript.waitForTurn()
    #expect(released)
    #expect(transcript.recoveryPrompt != nil)
  }

  @Test func freshSessionRecoveryRetainsConversationContext() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let transcript = AgentTranscript(store: nil)
    transcript.appendUserMessage("Blur the account number")
    transcript.beginAssistantMessage()
    transcript.apply(.sessionStarted(id: "expired"))
    transcript.finishTurn(error: AgentError.processFailed(status: 1, stderrTail: "Session not found"))
    let fixture = try AgentFixtures.url("claude-2.1.260-turn")
    let provider = ScriptedProvider { turn in
      turn.resumeID == nil && turn.prompt.contains("Blur the account number") ? [fixture.path] : ["/missing-fixture"]
    }
    let session = AgentSession(
      provider: provider,
      executable: URL(fileURLWithPath: "/bin/cat"),
      workingDirectory: dir,
      environment: AgentTestSupport.testEnvironment(home: dir)
    )
    transcript.retry(using: session)
    await transcript.waitForTurn()
    #expect(transcript.messages.last?.status == .completed)
    #expect(transcript.messages.filter { $0.role == .user }.count == 1)
    #expect(transcript.resumeIDs[.claudeCode] != "expired")
  }

  @Test func partialTextIsCheckpointedDuringTheTurn() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let store = AgentConversationStore(directory: dir)
    let transcript = AgentTranscript(store: store)
    transcript.beginAssistantMessage()
    transcript.apply(.textDelta("Saved while streaming"))
    try await Task.sleep(for: .milliseconds(400))
    #expect(try store.load()?.messages.last?.text == "Saved while streaming")
    transcript.markCancelled()
  }

  @Test func reopeningInterruptedConversationRetainsPartialOutputAndResumeID() throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let store = AgentConversationStore(directory: dir)
    let transcript = AgentTranscript(store: store)
    transcript.appendUserMessage("Continue the edit")
    transcript.beginAssistantMessage()
    transcript.apply(.sessionStarted(id: "session"))
    transcript.apply(.textDelta("Partial reply"))
    transcript.checkpoint()
    let restored = AgentTranscript(store: store)
    #expect(restored.messages.last?.text == "Partial reply")
    #expect(restored.messages.last?.status == .failed)
    #expect(restored.resumeIDs[.claudeCode] == "session")
    #expect(restored.recoveryPrompt != nil)
  }
}
