import Foundation
import Testing

@testable import Reframed

@Suite(.serialized)
struct AgentSessionTests {
  private func collect(_ stream: AsyncThrowingStream<AgentEvent, Error>) async throws -> [AgentEvent] {
    var events: [AgentEvent] = []
    for try await event in stream {
      events.append(event)
    }
    return events
  }

  @Test func sessionMapsLinesToEventsAndRecordsTheResumeId() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let fixture = try AgentFixtures.url("claude-2.1.260-turn")
    let provider = ScriptedProvider { _ in [fixture.path] }
    let session = AgentSession(
      provider: provider,
      executable: URL(fileURLWithPath: "/bin/cat"),
      workingDirectory: dir,
      environment: AgentTestSupport.testEnvironment(home: dir)
    )
    let events = try await collect(await session.send("hello"))
    #expect(events == (try AgentFixtures.events("claude-2.1.260-turn", provider: ClaudeCodeProvider())))
    #expect(await session.resumeID() == "0e5ac684-a18e-4f1f-a028-e63b1d1b8e3b")
    #expect(await session.isRunning == false)
  }

  @Test func sessionSecondTurnPassesTheRecordedResumeId() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let first = try AgentFixtures.url("claude-2.1.260-turn")
    let resumed = try AgentFixtures.url("claude-2.1.260-resume")
    let provider = ScriptedProvider { turn in
      turn.resumeID == "0e5ac684-a18e-4f1f-a028-e63b1d1b8e3b" ? [resumed.path] : [first.path]
    }
    let session = AgentSession(
      provider: provider,
      executable: URL(fileURLWithPath: "/bin/cat"),
      workingDirectory: dir,
      environment: AgentTestSupport.testEnvironment(home: dir)
    )
    _ = try await collect(await session.send("first"))
    let events = try await collect(await session.send("second"))
    #expect(events.contains(.textDelta("second turn")))
  }

  @Test func sessionKeepsResumeIdsPerProvider() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let session = AgentSession(
      provider: EchoProvider(),
      executable: URL(fileURLWithPath: "/bin/sh"),
      workingDirectory: dir,
      environment: AgentTestSupport.testEnvironment(home: dir),
      resumeIDs: [.claudeCode: "claude-id"]
    )
    #expect(try await collect(await session.send("x")) == [.textDelta("none")])
    await session.setResumeID("codex-id", for: .codex)
    #expect(try await collect(await session.send("y")) == [.textDelta("codex-id")])
    #expect(await session.resumeID(for: .claudeCode) == "claude-id")
    #expect(await session.resumeIDs == [.claudeCode: "claude-id", .codex: "codex-id"])
  }

  @Test func sessionCancelTerminatesTheProcessAndKeepsTheResumeId() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let script = try AgentTestSupport.hangingClaudeScript(in: dir)
    let provider = ScriptedProvider { _ in [] }
    let session = AgentSession(
      provider: provider,
      executable: script,
      workingDirectory: dir,
      environment: AgentTestSupport.testEnvironment(home: dir)
    )
    var events: [AgentEvent] = []
    var failure: AgentError?
    do {
      for try await event in await session.send("go") {
        events.append(event)
        if case .textDelta = event {
          await session.cancel()
        }
      }
    } catch let error as AgentError {
      failure = error
    }
    #expect(events == [.sessionStarted(id: "hang-session"), .textDelta("working")])
    #expect(failure == .cancelled)
    #expect(await session.resumeID() == "hang-session")
    #expect(await session.isRunning == false)
  }

  @Test func sessionRefusesAConcurrentTurn() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let script = try AgentTestSupport.hangingClaudeScript(in: dir)
    let provider = ScriptedProvider { _ in [] }
    let session = AgentSession(
      provider: provider,
      executable: script,
      workingDirectory: dir,
      environment: AgentTestSupport.testEnvironment(home: dir)
    )
    let firstStream = await session.send("one")
    var firstEvent: AgentEvent?
    for try await event in firstStream {
      firstEvent = event
      break
    }
    #expect(firstEvent == .sessionStarted(id: "hang-session"))
    var failure: AgentError?
    do {
      _ = try await collect(await session.send("two"))
    } catch let error as AgentError {
      failure = error
    }
    #expect(failure == .alreadyRunning)
    await session.cancel()
    let deadline = Date().addingTimeInterval(3)
    while await session.isRunning, Date() < deadline {
      try await Task.sleep(for: .milliseconds(10))
    }
    #expect(await session.isRunning == false)
  }

  @Test func sessionSurfacesProcessFailures() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let provider = ScriptedProvider { _ in [dir.appendingPathComponent("missing.ndjson").path] }
    let session = AgentSession(
      provider: provider,
      executable: URL(fileURLWithPath: "/bin/cat"),
      workingDirectory: dir,
      environment: AgentTestSupport.testEnvironment(home: dir)
    )
    var failure: AgentError?
    do {
      _ = try await collect(await session.send("x"))
    } catch let error as AgentError {
      failure = error
    }
    guard case .processFailed(let status, let tail)? = failure else {
      Issue.record("expected processFailed, got \(String(describing: failure))")
      return
    }
    #expect(status == 1)
    #expect(tail.contains("No such file"))
  }
}
