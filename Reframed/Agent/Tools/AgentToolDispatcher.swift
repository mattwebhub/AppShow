import Foundation
import Logging

@MainActor
final class AgentToolDispatcher {
  private struct MutationBatch {
    var snapshot: EditorStateData
    var historyIndex: Int
    var label: String
  }

  private let context: AgentToolContext
  private var handlers: [String: any AgentToolHandler] = [:]
  private var order: [String] = []
  private let allowsMutations: Bool
  private let batchTimeout: Duration
  private var mutationBatch: MutationBatch?
  private var batchTimeoutTask: Task<Void, Never>?
  private var batchTerminationError: AgentToolError?
  private let logger = Logger(label: "eu.jankuri.reframed.agent-tools")

  init(
    editorState: EditorState,
    framesDirectory: URL,
    workspaceDirectory: URL? = nil,
    handlers: [any AgentToolHandler] = AgentToolCatalog.readOnlyHandlers(),
    allowsMutations: Bool = false,
    batchTimeout: Duration = .seconds(300)
  ) {
    context = AgentToolContext(editorState: editorState, framesDirectory: framesDirectory, workspaceDirectory: workspaceDirectory)
    self.allowsMutations = allowsMutations
    self.batchTimeout = batchTimeout
    for handler in handlers {
      register(handler)
    }
  }

  func register(_ handler: any AgentToolHandler) {
    let name = handler.definition.name
    if handlers[name] == nil {
      order.append(name)
    }
    handlers[name] = handler
  }

  var definitions: [AgentToolDefinition] {
    order.compactMap { handlers[$0]?.definition }
  }

  var advertisedDefinitions: [AgentToolDefinition] {
    definitions.filter { $0.isAvailable && (allowsMutations || !$0.mutating) }
  }

  var toolsListResult: JSONValue {
    ["tools": .array(advertisedDefinitions.map(\.mcpValue))]
  }

  func definition(named name: String) -> AgentToolDefinition? {
    handlers[name]?.definition
  }

  func call(_ name: String, arguments: JSONValue?) async throws -> JSONValue {
    if let error = batchTerminationError {
      batchTerminationError = nil
      throw error
    }
    try cancelBatchIfHistoryChanged()
    guard let handler = handlers[name] else {
      throw AgentToolError.unknownTool(name)
    }
    let definition = handler.definition
    if definition.mutating && !allowsMutations {
      throw AgentToolError.mutationNotAllowed(name)
    }
    let validated = try AgentToolSchema.validate(arguments, against: definition.inputSchema)
    if name == AgentEditingToolCatalog.beginBatch.name {
      return try beginBatch(arguments: validated)
    }
    if name == AgentEditingToolCatalog.endBatch.name {
      return try endBatch()
    }
    let before = definition.mutating ? context.editorState.createSnapshot() : nil
    do {
      let value = try await handler.call(arguments: validated, context: context)
      if before != nil {
        context.editorState.pendingUndoTask?.cancel()
        if mutationBatch == nil {
          let label = Self.mutationLabel(arguments: validated, fallback: name)
          context.editorState.history.pushSnapshot(context.editorState.createSnapshot(), label: label)
        }
      }
      logger.info("Agent tool \(name) completed")
      return definition.mutating ? context.timelineResult() : value
    } catch let error as AgentToolError {
      restore(before)
      logger.warning("Agent tool \(name) failed: \(error.message)")
      throw error
    } catch {
      restore(before)
      logger.error("Agent tool \(name) failed: \(error)")
      throw AgentToolError.failed(error.localizedDescription)
    }
  }

  private func restore(_ snapshot: EditorStateData?) {
    guard let snapshot else { return }
    context.editorState.restoreFromSnapshot(snapshot)
    context.editorState.pendingUndoTask?.cancel()
  }

  private func beginBatch(arguments: JSONValue) throws -> JSONValue {
    guard mutationBatch == nil else { throw AgentToolError.batchAlreadyActive }
    context.editorState.pendingUndoTask?.cancel()
    mutationBatch = MutationBatch(
      snapshot: context.editorState.createSnapshot(),
      historyIndex: context.editorState.history.currentIndex,
      label: Self.mutationLabel(arguments: arguments, fallback: "batch")
    )
    context.editorState.agentMutationBatchActive = true
    batchTimeoutTask?.cancel()
    batchTimeoutTask = Task { [weak self] in
      guard let self else { return }
      try? await Task.sleep(for: self.batchTimeout)
      guard !Task.isCancelled else { return }
      self.expireBatch()
    }
    return context.timelineResult()
  }

  private func endBatch() throws -> JSONValue {
    guard let batch = mutationBatch else { throw AgentToolError.noActiveBatch }
    batchTimeoutTask?.cancel()
    batchTimeoutTask = nil
    mutationBatch = nil
    context.editorState.agentMutationBatchActive = false
    context.editorState.pendingUndoTask?.cancel()
    context.editorState.history.pushSnapshot(context.editorState.createSnapshot(), label: batch.label)
    return context.timelineResult()
  }

  private func cancelBatchIfHistoryChanged() throws {
    guard let batch = mutationBatch, context.editorState.history.currentIndex != batch.historyIndex else { return }
    restoreBatch(batch)
    throw AgentToolError.userUndo
  }

  private func expireBatch() {
    guard let batch = mutationBatch else { return }
    restoreBatch(batch)
    batchTerminationError = .batchTimedOut
  }

  private func restoreBatch(_ batch: MutationBatch) {
    batchTimeoutTask?.cancel()
    batchTimeoutTask = nil
    mutationBatch = nil
    context.editorState.agentMutationBatchActive = false
    context.editorState.pendingUndoTask?.cancel()
    _ = context.editorState.history.jumpTo(index: batch.historyIndex)
    context.editorState.restoreFromSnapshot(batch.snapshot)
    context.editorState.pendingUndoTask?.cancel()
  }

  private static func mutationLabel(arguments: JSONValue, fallback: String) -> String {
    let requested = arguments["label"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
    let value = requested.flatMap { $0.isEmpty ? nil : $0 } ?? fallback.replacingOccurrences(of: "_", with: " ")
    return "Agent: \(value.prefix(80))"
  }
}
