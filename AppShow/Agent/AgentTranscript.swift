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

  private(set) var store: AgentConversationStore?
  var onTurnEnd: (@MainActor () async -> Void)?
  private let logger = Logger(label: "com.mattwebhub.appshow.agent-transcript")
  private var turnTask: Task<Void, Never>?
  private var session: AgentSession?
  private var checkpointTask: Task<Void, Never>?

  init(store: AgentConversationStore?, defaultProvider: AgentProviderKind = .claudeCode) {
    self.store = store
    conversation = store.flatMap { try? $0.load() } ?? AgentConversationData(provider: defaultProvider)
    let needsRecovery = conversation.messages.contains { $0.status == .streaming }
    for index in conversation.messages.indices where conversation.messages[index].status == .streaming {
      conversation.messages[index].status = .failed
      conversation.messages[index].failureReason = "The app closed before this reply finished."
      Self.settleTools(&conversation.messages[index])
    }
    if needsRecovery { persist() }
  }

  func relocate(to store: AgentConversationStore) {
    self.store = store
    persist()
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
    persist()
    return message.id
  }

  func apply(_ event: AgentEvent) {
    switch event {
    case .sessionStarted(let id):
      mutateConversation { $0.resumeIDs[$0.provider] = id }
      persist()
    case .textBlock(let text):
      mutateStreamingMessage { message in
        if case .text(let existing)? = message.content.last {
          message.content[message.content.count - 1] = .text(existing + "\n\n" + text)
        } else {
          message.content.append(.text(text))
        }
      }
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
    scheduleCheckpoint()
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
          message.status = .failed
          message.failureReason = "The connection ended before the assistant finished."
        }
      }
    }
    mutateStreamingMessage { Self.settleTools(&$0) }
    streamingMessageID = nil
    isRunning = false
    persist()
  }

  func markCancelled() {
    mutateStreamingMessage { message in
      message.status = .cancelled
      Self.settleTools(&message)
    }
    streamingMessageID = nil
    isRunning = false
    isCancelled = true
    persist()
  }

  func send(_ prompt: String, using session: AgentSession) {
    guard !isRunning else { return }
    appendUserMessage(prompt)
    startTurn(prompt, using: session)
  }

  func retry(using session: AgentSession) {
    guard let prompt = recoveryPrompt else { return }
    startTurn(prompt, using: session)
  }

  private func startTurn(_ prompt: String, using session: AgentSession) {
    guard !isRunning else { return }
    self.session = session
    beginAssistantMessage()
    turnTask = Task { [weak self] in
      do {
        for try await event in await session.send(prompt) {
          self?.apply(event)
        }
        await self?.onTurnEnd?()
        if Task.isCancelled { self?.markCancelled() } else { self?.finishTurn(error: nil) }
      } catch AgentError.cancelled {
        await self?.onTurnEnd?()
        self?.markCancelled()
      } catch {
        await self?.onTurnEnd?()
        self?.finishTurn(error: error)
      }
    }
  }

  func cancel() {
    guard isRunning, let session else { return }
    turnTask?.cancel()
    Task {
      await session.cancel()
    }
  }

  func waitForTurn() async {
    await turnTask?.value
  }

  func teardown() {
    checkpoint()
    turnTask?.cancel()
    turnTask = nil
    if let session {
      Task {
        await session.cancel()
      }
    }
  }

  var recoveryPrompt: String? {
    guard !isRunning, let last = messages.last, last.role == .assistant,
      last.status == .failed || last.status == .cancelled,
      let request = messages.last(where: { $0.role == .user })
    else { return nil }
    let context = messages.suffix(8).map { "\($0.role.rawValue): \($0.text.prefix(6000))" }.joined(separator: "\n\n")
    return """
      Recover the interrupted request: \(request.text)
      Inspect the current project and timeline before making changes. Some tool calls may already have completed; do not repeat edits that are already applied. Continue the unfinished work and preserve completed work.
      Recent conversation:
      \(context)
      """
  }

  func checkpoint() { persist() }

  private func scheduleCheckpoint() {
    guard store != nil, checkpointTask == nil else { return }
    checkpointTask = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(250))
      guard !Task.isCancelled else { return }
      self?.persist()
    }
  }

  private static func settleTools(_ message: inout AgentMessageData) {
    for index in message.content.indices {
      if case .toolCall(var tool) = message.content[index], tool.status == .executing {
        tool.status = .failed
        tool.output = "No result was received. Check the project before retrying this action."
        message.content[index] = .toolCall(tool)
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
    checkpointTask?.cancel()
    checkpointTask = nil
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
