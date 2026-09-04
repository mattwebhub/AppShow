import Foundation

struct CodexProvider: AgentProvider {
  static let commonFlags = ["--json", "--skip-git-repo-check", "--sandbox", "read-only"]

  let id = AgentProviderKind.codex
  let executableNames = ["codex"]
  let environmentKeys = ["CODEX_HOME"]

  func arguments(for turn: AgentTurn) -> [String] {
    let configuration = turn.configuration?.codexArguments ?? []
    if let resumeID = turn.resumeID {
      return ["exec"] + Self.commonFlags + configuration + ["resume", "--", resumeID, turn.prompt]
    }
    return ["exec"] + Self.commonFlags + configuration + ["--", turn.prompt]
  }

  func standardInput(for turn: AgentTurn) -> String? {
    nil
  }

  func parse(line: String) -> [AgentEvent] {
    guard let data = line.data(using: .utf8), let envelope = try? JSONDecoder().decode(CodexEnvelope.self, from: data) else {
      return []
    }
    switch envelope.type {
    case "thread.started":
      guard let threadID = envelope.threadID, !threadID.isEmpty else { return [] }
      return [.sessionStarted(id: threadID)]
    case "turn.started":
      return []
    case "item.started":
      return itemStartedEvents(envelope.item)
    case "item.completed":
      return itemCompletedEvents(envelope.item)
    case "turn.completed":
      return [.turnCompleted(turnCompletedResult(from: envelope))]
    case "turn.failed":
      return [.turnCompleted(AgentTurnResult(isError: true, text: message(from: envelope) ?? "Turn failed"))]
    case "error":
      return [.error(message: message(from: envelope) ?? "Unknown error")]
    default:
      return [.unknown(type: envelope.type ?? "")]
    }
  }

  private func itemStartedEvents(_ item: CodexItem?) -> [AgentEvent] {
    guard let item else { return [] }
    switch item.type {
    case "command_execution", "function_call", "tool_call", "mcp_tool_call", "web_search", "file_read", "file_write", "file_edit",
      "file_change":
      return [toolCallStarted(item)]
    default:
      return []
    }
  }

  private func itemCompletedEvents(_ item: CodexItem?) -> [AgentEvent] {
    guard let item else { return [] }
    switch item.type {
    case "agent_message", "message":
      guard item.role != "user", let text = messageText(item), !text.isEmpty else { return [] }
      return [.textDelta(text)]
    case "user_message", "reasoning":
      return []
    case "command_execution":
      let failed = (item.exitCode ?? 0) != 0 || statusIsError(item.status)
      return [toolCallStarted(item), .toolCallFinished(id: itemID(item), output: item.aggregatedOutput ?? "", isError: failed)]
    case "file_read", "file_write", "file_edit", "file_change", "web_search":
      return [toolCallStarted(item), .toolCallFinished(id: itemID(item), output: "", isError: toolItemIsError(item))]
    case "function_call", "tool_call":
      return [toolCallStarted(item)]
    case "function_call_output", "tool_result":
      let id = item.callID ?? item.toolCallID ?? itemID(item)
      let output = item.output ?? item.content?.joinedText ?? ""
      return [.toolCallFinished(id: id, output: output, isError: toolItemIsError(item))]
    case "mcp_tool_call":
      let output = item.result?.joinedText ?? item.error?.joinedText ?? ""
      return [toolCallStarted(item), .toolCallFinished(id: itemID(item), output: output, isError: toolItemIsError(item))]
    default:
      return [.unknown(type: "item.completed/\(item.type ?? "")")]
    }
  }

  private func toolCallStarted(_ item: CodexItem) -> AgentEvent {
    .toolCallStarted(id: itemID(item), name: toolName(item), input: toolInput(item))
  }

  private func itemID(_ item: CodexItem) -> String {
    item.id ?? item.callID ?? UUID().uuidString
  }

  private func toolName(_ item: CodexItem) -> String {
    switch item.type {
    case "command_execution": "Bash"
    case "web_search": "WebSearch"
    case "file_read": "Read"
    case "file_write": "Write"
    case "file_edit", "file_change": "Edit"
    default: item.tool ?? item.name ?? item.function ?? "unknown"
    }
  }

  private func toolInput(_ item: CodexItem) -> String {
    switch item.type {
    case "command_execution": item.command ?? ""
    case "web_search": item.query ?? ""
    case "file_read", "file_write", "file_edit", "file_change": item.path ?? item.filePath ?? ""
    default: item.arguments?.stringValue ?? item.arguments?.compactJSON ?? ""
    }
  }

  private func messageText(_ item: CodexItem) -> String? {
    if let text = item.text { return text }
    if let text = item.content?.joinedText { return text }
    if let formatted = item.formatted {
      return formatted["transcript"]?.stringValue ?? formatted["text"]?.stringValue
    }
    return nil
  }

  private func statusIsError(_ status: String?) -> Bool {
    guard let status else { return false }
    return ["failed", "error", "cancelled", "canceled", "interrupted"].contains(status.lowercased())
  }

  private func toolItemIsError(_ item: CodexItem) -> Bool {
    if item.isError == true { return true }
    if statusIsError(item.status) { return true }
    if let error = item.error, !error.isNull { return true }
    if let result = item.result, result["is_error"]?.boolValue == true || result["isError"]?.boolValue == true { return true }
    return false
  }

  private func turnCompletedResult(from envelope: CodexEnvelope) -> AgentTurnResult {
    let status = envelope.status ?? envelope.turn?.status
    let statusIsFailure = status != nil && !["completed", "success"].contains(status ?? "")
    let hasError = envelope.error.map { !$0.isNull } ?? false
    let usage = envelope.usage
    return AgentTurnResult(
      isError: (envelope.isError ?? false) || statusIsFailure || hasError,
      text: hasError ? message(from: envelope) : nil,
      costUSD: usage?.totalCost ?? usage?.costUSD,
      durationMs: usage?.durationMs ?? usage?.totalDuration
    )
  }

  private func message(from envelope: CodexEnvelope) -> String? {
    if let message = envelope.message, !message.isEmpty { return message }
    if let message = envelope.error?.stringValue, !message.isEmpty { return message }
    if let message = envelope.error?["message"]?.stringValue, !message.isEmpty { return message }
    return nil
  }
}

private struct CodexEnvelope: Decodable {
  var type: String?
  var threadID: String?
  var item: CodexItem?
  var usage: CodexUsage?
  var error: AgentJSONValue?
  var message: String?
  var status: String?
  var isError: Bool?
  var turn: CodexTurn?

  private enum CodingKeys: String, CodingKey {
    case type
    case threadID = "thread_id"
    case item
    case usage
    case error
    case message
    case status
    case isError = "is_error"
    case turn
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    type = try container.decodeIfPresent(String.self, forKey: .type)
    threadID = try? container.decodeIfPresent(String.self, forKey: .threadID)
    item = try? container.decodeIfPresent(CodexItem.self, forKey: .item)
    usage = try? container.decodeIfPresent(CodexUsage.self, forKey: .usage)
    error = try? container.decodeIfPresent(AgentJSONValue.self, forKey: .error)
    message = try? container.decodeIfPresent(String.self, forKey: .message)
    status = try? container.decodeIfPresent(String.self, forKey: .status)
    isError = try? container.decodeIfPresent(Bool.self, forKey: .isError)
    turn = try? container.decodeIfPresent(CodexTurn.self, forKey: .turn)
  }
}

private struct CodexTurn: Decodable {
  var status: String?
}

private struct CodexUsage: Decodable {
  var totalCost: Double?
  var costUSD: Double?
  var durationMs: Int?
  var totalDuration: Int?

  private enum CodingKeys: String, CodingKey {
    case totalCost = "total_cost"
    case costUSD = "cost_usd"
    case durationMs = "duration_ms"
    case totalDuration = "total_duration"
  }
}

private struct CodexItem: Decodable {
  var id: String?
  var type: String?
  var role: String?
  var text: String?
  var content: AgentJSONValue?
  var formatted: AgentJSONValue?
  var command: String?
  var aggregatedOutput: String?
  var exitCode: Int?
  var status: String?
  var name: String?
  var tool: String?
  var function: String?
  var arguments: AgentJSONValue?
  var callID: String?
  var toolCallID: String?
  var output: String?
  var result: AgentJSONValue?
  var error: AgentJSONValue?
  var isError: Bool?
  var path: String?
  var filePath: String?
  var query: String?

  private enum CodingKeys: String, CodingKey {
    case id
    case type
    case role
    case text
    case content
    case formatted
    case command
    case aggregatedOutput = "aggregated_output"
    case exitCode = "exit_code"
    case status
    case name
    case tool
    case function
    case arguments
    case callID = "call_id"
    case toolCallID = "tool_call_id"
    case output
    case result
    case error
    case isError = "is_error"
    case path
    case filePath = "file_path"
    case query
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try? container.decodeIfPresent(String.self, forKey: .id)
    type = try? container.decodeIfPresent(String.self, forKey: .type)
    role = try? container.decodeIfPresent(String.self, forKey: .role)
    text = try? container.decodeIfPresent(String.self, forKey: .text)
    content = try? container.decodeIfPresent(AgentJSONValue.self, forKey: .content)
    formatted = try? container.decodeIfPresent(AgentJSONValue.self, forKey: .formatted)
    command = try? container.decodeIfPresent(String.self, forKey: .command)
    aggregatedOutput = try? container.decodeIfPresent(String.self, forKey: .aggregatedOutput)
    exitCode = try? container.decodeIfPresent(Int.self, forKey: .exitCode)
    status = try? container.decodeIfPresent(String.self, forKey: .status)
    name = try? container.decodeIfPresent(String.self, forKey: .name)
    tool = try? container.decodeIfPresent(String.self, forKey: .tool)
    function = try? container.decodeIfPresent(String.self, forKey: .function)
    arguments = try? container.decodeIfPresent(AgentJSONValue.self, forKey: .arguments)
    callID = try? container.decodeIfPresent(String.self, forKey: .callID)
    toolCallID = try? container.decodeIfPresent(String.self, forKey: .toolCallID)
    output = try? container.decodeIfPresent(String.self, forKey: .output)
    result = try? container.decodeIfPresent(AgentJSONValue.self, forKey: .result)
    error = try? container.decodeIfPresent(AgentJSONValue.self, forKey: .error)
    isError = try? container.decodeIfPresent(Bool.self, forKey: .isError)
    path = try? container.decodeIfPresent(String.self, forKey: .path)
    filePath = try? container.decodeIfPresent(String.self, forKey: .filePath)
    query = try? container.decodeIfPresent(String.self, forKey: .query)
  }
}
