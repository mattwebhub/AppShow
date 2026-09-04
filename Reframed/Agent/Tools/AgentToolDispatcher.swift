import Foundation
import Logging

@MainActor
final class AgentToolDispatcher {
  private let context: AgentToolContext
  private var handlers: [String: any AgentToolHandler] = [:]
  private var order: [String] = []
  private let logger = Logger(label: "eu.jankuri.reframed.agent-tools")

  init(
    editorState: EditorState,
    framesDirectory: URL,
    workspaceDirectory: URL? = nil,
    handlers: [any AgentToolHandler] = AgentToolCatalog.readOnlyHandlers()
  ) {
    context = AgentToolContext(editorState: editorState, framesDirectory: framesDirectory, workspaceDirectory: workspaceDirectory)
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
    definitions.filter { $0.isAvailable && !$0.mutating }
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
    if definition.mutating {
      throw AgentToolError.mutationNotAllowed(name)
    }
    let validated = try AgentToolSchema.validate(arguments, against: definition.inputSchema)
    do {
      let value = try await handler.call(arguments: validated, context: context)
      logger.info("Agent tool \(name) completed")
      return value
    } catch let error as AgentToolError {
      logger.warning("Agent tool \(name) failed: \(error.message)")
      throw error
    } catch {
      logger.error("Agent tool \(name) failed: \(error)")
      throw AgentToolError.failed(error.localizedDescription)
    }
  }
}
