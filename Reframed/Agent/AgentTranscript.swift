import Foundation
import Logging

@MainActor
@Observable
final class AgentTranscript {
  private(set) var threads: [AgentThreadData] = []
  private(set) var activeThreadID: UUID?
  private(set) var isRunning = false
  private(set) var isCancelled = false
  private(set) var streamingMessageID: UUID?
  private(set) var lastError: String?

  let store: AgentThreadStore?
  private let logger = Logger(label: "eu.jankuri.reframed.agent-transcript")
  private var turnTask: Task<Void, Never>?
  private var session: AgentSession?

  init(store: AgentThreadStore?) {
    self.store = store
    if let store {
      threads = (try? store.list()) ?? []
      activeThreadID = threads.first?.id
    }
  }

  var activeThread: AgentThreadData? {
    threads.first { $0.id == activeThreadID }
  }

  var messages: [AgentMessageData] {
    activeThread?.messages ?? []
  }

  @discardableResult
  func createThread(title: String, provider: AgentProviderKind) -> AgentThreadData {
    let thread = AgentThreadData(title: title, provider: provider)
    threads.insert(thread, at: 0)
    activeThreadID = thread.id
    persist(thread)
    return thread
  }

  func selectThread(id: UUID) {
    guard threads.contains(where: { $0.id == id }) else { return }
    activeThreadID = id
  }

  func renameThread(id: UUID, to title: String) {
    guard let index = threads.firstIndex(where: { $0.id == id }) else { return }
    threads[index].title = title
    persist(threads[index])
  }

  func deleteThread(id: UUID) {
    guard let index = threads.firstIndex(where: { $0.id == id }) else { return }
    threads.remove(at: index)
    if let store {
      do {
        try store.delete(id: id)
      } catch {
        logger.error("Failed to delete agent thread: \(error.localizedDescription)")
      }
    }
    if activeThreadID == id {
      activeThreadID = threads.max { $0.lastActivityAt < $1.lastActivityAt }?.id
    }
  }

  @discardableResult
  func appendUserMessage(_ text: String) -> AgentMessageData {
    let message = AgentMessageData(role: .user, content: [.text(text)], status: .completed)
    mutateActiveThread { thread in
      thread.messages.append(message)
      thread.lastActivityAt = message.createdAt
    }
    return message
  }

  @discardableResult
  func beginAssistantMessage() -> UUID {
    let message = AgentMessageData(role: .assistant, content: [], status: .streaming)
    mutateActiveThread { thread in
      thread.messages.append(message)
      thread.lastActivityAt = message.createdAt
    }
    streamingMessageID = message.id
    isRunning = true
    isCancelled = false
    lastError = nil
    return message.id
  }

  func apply(_ event: AgentEvent) {
    switch event {
    case .sessionStarted(let id):
      mutateActiveThread { $0.sessionID = id }
    case .textDelta(let text):
      mutateStreamingMessage { message in
        if case .text(let existing)? = message.content.last {
          message.content[message.content.count - 1] = .text(existing + text)
        } else {
          message.content.append(.text(text))
        }
      }
    case .toolCallStarted(let id, let name, let input):
      mutateStreamingMessage { message in
        if let index = message.toolCallIndex(callID: id) {
          if case .toolCall(var row) = message.content[index] {
            row.name = name
            row.input = input
            message.content[index] = .toolCall(row)
          }
        } else {
          message.content.append(.toolCall(AgentToolCallData(callID: id, name: name, input: input)))
        }
      }
    case .toolCallFinished(let id, let output, let isError):
      mutateStreamingMessage { message in
        let status: AgentToolCallStatus = isError ? .failed : .completed
        if let index = message.toolCallIndex(callID: id), case .toolCall(var row) = message.content[index] {
          row.output = output
          row.status = status
          message.content[index] = .toolCall(row)
        } else {
          message.content.append(.toolCall(AgentToolCallData(callID: id, name: id, input: "", output: output, status: status)))
        }
      }
    case .turnCompleted(let result):
      mutateStreamingMessage { message in
        if result.isError {
          message.status = .failed
          message.failureReason = result.text ?? "The turn failed"
        } else if message.status == .streaming {
          message.status = .completed
        }
      }
    case .error(let message):
      lastError = message
      mutateStreamingMessage { streaming in
        streaming.status = .failed
        streaming.failureReason = message
      }
    case .unknown:
      break
    }
  }

  func finishTurn(error: (any Error)?) {
    if let error {
      let reason = error.localizedDescription
      lastError = reason
      mutateStreamingMessage { message in
        if message.status == .streaming {
          message.status = .failed
          message.failureReason = reason
        }
      }
    } else {
      mutateStreamingMessage { message in
        if message.status == .streaming {
          message.status = .completed
        }
      }
    }
    streamingMessageID = nil
    isRunning = false
    if let thread = activeThread {
      persist(thread)
    }
  }

  func markCancelled() {
    mutateStreamingMessage { message in
      message.status = .cancelled
    }
    streamingMessageID = nil
    isRunning = false
    isCancelled = true
    if let thread = activeThread {
      persist(thread)
    }
  }

  func send(_ prompt: String, using session: AgentSession) {
    guard !isRunning, activeThreadID != nil else { return }
    self.session = session
    appendUserMessage(prompt)
    beginAssistantMessage()
    turnTask = Task { [weak self] in
      do {
        for try await event in await session.send(prompt) {
          self?.apply(event)
        }
        self?.finishTurn(error: nil)
      } catch AgentError.cancelled {
        self?.markCancelled()
      } catch {
        self?.finishTurn(error: error)
      }
    }
  }

  func cancel() {
    guard isRunning, let session else { return }
    Task {
      await session.cancel()
    }
  }

  func waitForTurn() async {
    await turnTask?.value
  }

  func teardown() {
    turnTask?.cancel()
    turnTask = nil
    if let session {
      Task {
        await session.cancel()
      }
    }
  }

  private func mutateActiveThread(_ change: (inout AgentThreadData) -> Void) {
    guard let index = threads.firstIndex(where: { $0.id == activeThreadID }) else { return }
    change(&threads[index])
  }

  private func mutateStreamingMessage(_ change: (inout AgentMessageData) -> Void) {
    guard let streamingMessageID else { return }
    mutateActiveThread { thread in
      guard let index = thread.messages.firstIndex(where: { $0.id == streamingMessageID }) else { return }
      change(&thread.messages[index])
      thread.lastActivityAt = AgentTimestamp.now()
    }
  }

  private func persist(_ thread: AgentThreadData) {
    guard let store else { return }
    do {
      try store.save(thread)
    } catch {
      logger.error("Failed to save agent thread: \(error.localizedDescription)")
    }
  }
}

extension AgentMessageData {
  fileprivate func toolCallIndex(callID: String) -> Int? {
    content.firstIndex { block in
      if case .toolCall(let row) = block { return row.callID == callID }
      return false
    }
  }
}
