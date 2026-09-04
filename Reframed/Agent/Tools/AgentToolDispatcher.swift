import Foundation
import Logging

@MainActor
final class AgentToolDispatcher {
  private let context: AgentToolContext
  private var handlers: [String: any AgentToolHandler] = [:]
  private var order: [String] = []
  private let allowsMutations: Bool
  private let logger = Logger(label: "eu.jankuri.reframed.agent-tools")

  init(
    editorState: EditorState,
    framesDirectory: URL,
    workspaceDirectory: URL? = nil,
    handlers: [any AgentToolHandler] = AgentToolCatalog.readOnlyHandlers(),
    allowsMutations: Bool = false
  ) {
    context = AgentToolContext(editorState: editorState, framesDirectory: framesDirectory, workspaceDirectory: workspaceDirectory)
    self.allowsMutations = allowsMutations
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
    guard let handler = handlers[name] else {
      throw AgentToolError.unknownTool(name)
    }
    let definition = handler.definition
    if definition.mutating && !allowsMutations {
      throw AgentToolError.mutationNotAllowed(name)
    }
    let validated = try AgentToolSchema.validate(arguments, against: definition.inputSchema)
    let before = definition.mutating ? context.editorState.createSnapshot() : nil
    do {
      let value = try await handler.call(arguments: validated, context: context)
      if let before {
        context.editorState.pendingUndoTask?.cancel()
        let label = Self.mutationLabel(arguments: validated, fallback: name)
        context.editorState.history.pushSnapshot(context.editorState.createSnapshot(), label: label)
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

  private static func mutationLabel(arguments: JSONValue, fallback: String) -> String {
    let requested = arguments["label"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
    let value = requested.flatMap { $0.isEmpty ? nil : $0 } ?? fallback.replacingOccurrences(of: "_", with: " ")
    return "Agent: \(value.prefix(80))"
  }
}
