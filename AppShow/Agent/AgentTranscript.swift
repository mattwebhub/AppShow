import Foundation
import Logging

@MainActor
@Observable
final class AgentTranscript {
  private(set) var conversation: AgentConversationData
  private(set) var isRunning = false
  private(set) var isCancelled = false
  private(set) var streamingMessageID: UUID?
  private(set) var lastError: String?

  let store: AgentConversationStore?
  private let logger = Logger(label: "com.mattwebhub.appshow.agent-transcript")
  private var turnTask: Task<Void, Never>?
  private var session: AgentSession?

  init(store: AgentConversationStore?, defaultProvider: AgentProviderKind = .claudeCode) {
    self.store = store
    conversation = store.flatMap { try? $0.load() } ?? AgentConversationData(provider: defaultProvider)
  }

  var messages: [AgentMessageData] {
    conversation.messages
  }

  var provider: AgentProviderKind {
    conversation.provider
  }

  var resumeIDs: [AgentProviderKind: String] {
    conversation.resumeIDs
  }

  func setProvider(_ provider: AgentProviderKind) {
    conversation.provider = provider
    persist()
  }

  @discardableResult
  func clear() -> Bool {
    guard !isRunning else { return false }
    conversation = AgentConversationData(provider: conversation.provider)
    streamingMessageID = nil
    isCancelled = false
    lastError = nil
    if let store {
      do {
        try store.clear()
      } catch {
        logger.error("Failed to clear agent conversation: \(error.localizedDescription)")
        return false
      }
    }
    return true
  }

  @discardableResult
  func appendUserMessage(_ text: String) -> AgentMessageData {
    let message = AgentMessageData(role: .user, content: [.text(text)], status: .completed)
    mutateConversation { conversation in
      conversation.messages.append(message)
      conversation.lastActivityAt = message.createdAt
    }
    persist()
    return message
  }

  @discardableResult
  func beginAssistantMessage() -> UUID {
    let message = AgentMessageData(role: .assistant, content: [], status: .streaming)
    mutateConversation { conversation in
      conversation.messages.append(message)
      conversation.lastActivityAt = message.createdAt
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
      mutateConversation { $0.resumeIDs[$0.provider] = id }
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
    persist()
  }

  func markCancelled() {
    mutateStreamingMessage { message in
      message.status = .cancelled
    }
    streamingMessageID = nil
    isRunning = false
    isCancelled = true
    persist()
  }

  func send(_ prompt: String, using session: AgentSession) {
    guard !isRunning else { return }
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

  private func mutateConversation(_ change: (inout AgentConversationData) -> Void) {
    change(&conversation)
  }

  private func mutateStreamingMessage(_ change: (inout AgentMessageData) -> Void) {
    guard let streamingMessageID else { return }
    mutateConversation { conversation in
      guard let index = conversation.messages.firstIndex(where: { $0.id == streamingMessageID }) else { return }
      change(&conversation.messages[index])
      conversation.lastActivityAt = AgentTimestamp.now()
    }
  }

  private func persist() {
    guard let store else { return }
    do {
      try store.save(conversation)
    } catch {
      logger.error("Failed to save agent conversation: \(error.localizedDescription)")
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
