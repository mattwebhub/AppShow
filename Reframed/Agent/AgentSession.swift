import Foundation
import Logging

actor AgentSession {
  let provider: any AgentProvider
  private let logger = Logger(label: "eu.jankuri.reframed.agent-session")
  private let executable: URL
  private let workingDirectory: URL
  private let environment: [String: String]
  private var runner: AgentProcessRunner?
  private var cancelPending = false
  private(set) var resumeIDs: [AgentProviderKind: String]
  private(set) var isRunning = false

  init(
    provider: any AgentProvider,
    executable: URL,
    workingDirectory: URL,
    environment: [String: String],
    resumeIDs: [AgentProviderKind: String] = [:]
  ) {
    self.provider = provider
    self.executable = executable
    self.workingDirectory = workingDirectory
    self.environment = environment
    self.resumeIDs = resumeIDs
  }

  func resumeID(for kind: AgentProviderKind? = nil) -> String? {
    resumeIDs[kind ?? provider.id]
  }

  func setResumeID(_ id: String?, for kind: AgentProviderKind? = nil) {
    resumeIDs[kind ?? provider.id] = id
  }

  func send(_ prompt: String) -> AsyncThrowingStream<AgentEvent, Error> {
    let (stream, continuation) = AsyncThrowingStream<AgentEvent, Error>.makeStream()
    guard !isRunning else {
      continuation.finish(throwing: AgentError.alreadyRunning)
      return stream
    }
    guard !cancelPending else {
      cancelPending = false
      continuation.finish(throwing: AgentError.cancelled)
      return stream
    }
    let turn = AgentTurn(prompt: prompt, resumeID: resumeIDs[provider.id])
    let launch = AgentProcessLaunch(
      executable: executable,
      arguments: provider.arguments(for: turn),
      workingDirectory: workingDirectory,
      environment: environment,
      standardInput: provider.standardInput(for: turn)
    )
    let runner = AgentProcessRunner()
    self.runner = runner
    isRunning = true
    logger.info("Turn started", metadata: ["provider": "\(provider.id.rawValue)", "resume": "\(turn.resumeID ?? "none")"])
    let task = Task {
      do {
        for try await line in await runner.run(launch) {
          for event in provider.parse(line: line) {
            if case .sessionStarted(let id) = event {
              resumeIDs[provider.id] = id
            }
            continuation.yield(event)
          }
        }
        continuation.finish()
      } catch {
        continuation.finish(throwing: error)
      }
      turnDidEnd(runner)
    }
    continuation.onTermination = { reason in
      guard case .cancelled = reason else { return }
      task.cancel()
      Task { await runner.cancel() }
    }
    return stream
  }

  func cancel() async {
    guard let runner else {
      cancelPending = true
      return
    }
    await runner.cancel()
  }

  private func turnDidEnd(_ finished: AgentProcessRunner) {
    guard runner === finished else { return }
    runner = nil
    isRunning = false
    logger.info("Turn ended")
  }
}
