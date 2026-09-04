import Foundation

enum AgentToolAvailability: Sendable, Equatable {
  case available
  case pendingMerge(branch: String)
}

struct AgentToolDefinition: Sendable, Equatable {
  var name: String
  var description: String
  var inputSchema: JSONValue
  var mutating: Bool
  var slow: Bool = false
  var availability: AgentToolAvailability = .available

  var isAvailable: Bool { availability == .available }

  var mcpValue: JSONValue {
    [
      "name": .string(name),
      "description": .string(description),
      "inputSchema": inputSchema,
      "annotations": [
        "title": .string(name),
        "readOnlyHint": .bool(!mutating),
        "destructiveHint": .bool(mutating),
        "idempotentHint": .bool(!mutating),
        "openWorldHint": false,
      ],
    ]
  }
}

struct AgentToolContext: Sendable {
  let editorState: EditorState
  let framesDirectory: URL
  let workspaceDirectory: URL?
}

@MainActor
protocol AgentToolHandler {
  var definition: AgentToolDefinition { get }
  func call(arguments: JSONValue, context: AgentToolContext) async throws -> JSONValue
}

enum AgentToolError: Error, Equatable, Sendable {
  case unknownTool(String)
  case invalidArguments(String)
  case mutationNotAllowed(String)
  case unavailable(name: String, reason: String)
  case timedOut(String)
  case batchAlreadyActive
  case noActiveBatch
  case batchTimedOut
  case userUndo
  case failed(String)

  var code: String {
    switch self {
    case .unknownTool: "UNKNOWN_TOOL"
    case .invalidArguments: "TOOL_ARGUMENTS_INVALID"
    case .mutationNotAllowed: "MUTATION_NOT_ALLOWED"
    case .unavailable: "TOOL_UNAVAILABLE"
    case .timedOut: "TOOL_TIMEOUT"
    case .batchAlreadyActive: "BATCH_ALREADY_ACTIVE"
    case .noActiveBatch: "NO_ACTIVE_BATCH"
    case .batchTimedOut: "BATCH_TIMEOUT"
    case .userUndo: "USER_UNDO"
    case .failed: "TOOL_FAILED"
    }
  }

  var message: String {
    switch self {
    case .unknownTool(let name): "Unknown tool: \(name)"
    case .invalidArguments(let detail): "Invalid arguments: \(detail)"
    case .mutationNotAllowed(let name): "Tool \(name) mutates the project, which this build does not allow"
    case .unavailable(let name, let reason): "Tool \(name) is not available: \(reason)"
    case .timedOut(let name): "Tool \(name) timed out"
    case .batchAlreadyActive: "An agent edit batch is already active"
    case .noActiveBatch: "No agent edit batch is active"
    case .batchTimedOut: "The agent edit batch timed out and was restored"
    case .userUndo: "The user changed history, so the agent edit batch was cancelled and restored"
    case .failed(let detail): detail
    }
  }

  var jsonRPCCode: Int {
    switch self {
    case .unknownTool: JSONRPCError.methodNotFoundCode
    case .invalidArguments: JSONRPCError.invalidParamsCode
    case .mutationNotAllowed: -32003
    case .unavailable: -32004
    case .timedOut: -32005
    case .batchAlreadyActive, .noActiveBatch, .batchTimedOut, .userUndo: -32006
    case .failed: -32000
    }
  }

  var jsonRPCError: JSONRPCError {
    JSONRPCError(code: jsonRPCCode, message: message, data: ["code": .string(code)])
  }
}

struct AgentToolResult: Sendable, Equatable {
  var value: JSONValue
  var isError: Bool

  static func success(_ value: JSONValue) -> AgentToolResult {
    AgentToolResult(value: value, isError: false)
  }

  static func failure(_ message: String) -> AgentToolResult {
    AgentToolResult(value: .string(message), isError: true)
  }

  var mcpValue: JSONValue {
    let text = isError ? (value.stringValue ?? (try? value.jsonString()) ?? "") : ((try? value.jsonString()) ?? "")
    var object: [String: JSONValue] = [
      "content": [["type": "text", "text": .string(text)]],
      "isError": .bool(isError),
    ]
    if !isError, case .object = value {
      object["structuredContent"] = value
    }
    return .object(object)
  }
}

enum AgentToolSchema {
  static func object(_ properties: [String: JSONValue], required: [String] = []) -> JSONValue {
    [
      "type": "object",
      "properties": .object(properties),
      "required": .array(required.map { .string($0) }),
      "additionalProperties": false,
    ]
  }

  static func number(_ description: String, minimum: Double? = nil, maximum: Double? = nil) -> JSONValue {
    scalar("number", description, minimum: minimum, maximum: maximum)
  }

  static func integer(_ description: String, minimum: Double? = nil, maximum: Double? = nil) -> JSONValue {
    scalar("integer", description, minimum: minimum, maximum: maximum)
  }

  static func string(_ description: String, enum values: [String] = []) -> JSONValue {
    var object: [String: JSONValue] = ["type": "string", "description": .string(description)]
    if !values.isEmpty {
      object["enum"] = .array(values.map { .string($0) })
    }
    return .object(object)
  }

  static func boolean(_ description: String) -> JSONValue {
    ["type": "boolean", "description": .string(description)]
  }

  static func array(
    _ description: String,
    items: JSONValue,
    minimumItems: Int? = nil,
    maximumItems: Int? = nil
  ) -> JSONValue {
    var object: [String: JSONValue] = [
      "type": "array",
      "description": .string(description),
      "items": items,
    ]
    if let minimumItems { object["minItems"] = JSONValue(minimumItems) }
    if let maximumItems { object["maxItems"] = JSONValue(maximumItems) }
    return .object(object)
  }

  private static func scalar(_ type: String, _ description: String, minimum: Double?, maximum: Double?) -> JSONValue {
    var object: [String: JSONValue] = ["type": .string(type), "description": .string(description)]
    if let minimum { object["minimum"] = .number(minimum) }
    if let maximum { object["maximum"] = .number(maximum) }
    return .object(object)
  }

  static func validate(_ arguments: JSONValue?, against schema: JSONValue) throws -> JSONValue {
    let object: [String: JSONValue]
    switch arguments {
    case .none, .some(.null):
      object = [:]
    case .some(.object(let value)):
      object = value
    case .some(let other):
      throw AgentToolError.invalidArguments("expected an object, got \(other.typeName)")
    }
    try validateObject(object, path: "", schema: schema)
    return .object(object)
  }

  private static func validateObject(_ object: [String: JSONValue], path: String, schema: JSONValue) throws {
    let properties = schema["properties"]?.objectValue ?? [:]
    let required = schema["required"]?.arrayValue?.compactMap(\.stringValue) ?? []
    for key in required where object[key] == nil || object[key] == .null {
      let prefix = path.isEmpty ? "" : "\(path) "
      throw AgentToolError.invalidArguments("\(prefix)missing required key \(key)")
    }
    if schema["additionalProperties"] == false {
      for key in object.keys.sorted() where properties[key] == nil {
        let qualified = path.isEmpty ? key : "\(path).\(key)"
        throw AgentToolError.invalidArguments("unknown key \(qualified)")
      }
    }
    for (key, value) in object.sorted(by: { $0.key < $1.key }) {
      guard let property = properties[key] else { continue }
      let qualified = path.isEmpty ? key : "\(path).\(key)"
      try validate(value, path: qualified, property: property)
    }
  }

  private static func validate(_ value: JSONValue, path: String, property: JSONValue) throws {
    guard let type = property["type"]?.stringValue else { return }
    switch type {
    case "integer":
      guard value.intValue != nil else {
        throw AgentToolError.invalidArguments("\(path) must be an integer, got \(value.typeName)")
      }
    case "number":
      guard value.doubleValue != nil else {
        throw AgentToolError.invalidArguments("\(path) must be a number, got \(value.typeName)")
      }
    case "array":
      guard let values = value.arrayValue else {
        throw AgentToolError.invalidArguments("\(path) must be an array, got \(value.typeName)")
      }
      if let minimum = property["minItems"]?.intValue, values.count < minimum {
        throw AgentToolError.invalidArguments("\(path) must contain at least \(minimum) item")
      }
      if let maximum = property["maxItems"]?.intValue, values.count > maximum {
        throw AgentToolError.invalidArguments("\(path) must contain at most \(maximum) items")
      }
      if let items = property["items"] {
        for (index, item) in values.enumerated() {
          try validate(item, path: "\(path)[\(index)]", property: items)
        }
      }
    case "object":
      guard let object = value.objectValue else {
        throw AgentToolError.invalidArguments("\(path) must be an object, got \(value.typeName)")
      }
      try validateObject(object, path: path, schema: property)
    default:
      guard value.typeName == type else {
        throw AgentToolError.invalidArguments("\(path) must be a \(type), got \(value.typeName)")
      }
    }
    if let number = value.doubleValue {
      if let minimum = property["minimum"]?.doubleValue, number < minimum {
        throw AgentToolError.invalidArguments("\(path) is below the minimum \(minimum)")
      }
      if let maximum = property["maximum"]?.doubleValue, number > maximum {
        throw AgentToolError.invalidArguments("\(path) is above the maximum \(maximum)")
      }
    }
    if let allowed = property["enum"]?.arrayValue, !allowed.contains(value) {
      let names = allowed.compactMap(\.stringValue).joined(separator: ", ")
      throw AgentToolError.invalidArguments("\(path) must be one of \(names)")
    }
  }
}
