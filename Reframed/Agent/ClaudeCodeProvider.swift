import Foundation

struct ClaudeCodeProvider: AgentProvider {
  static let allowedTools = ["Read", "Glob", "Grep"]

  let id = AgentProviderKind.claudeCode
  let executableNames = ["claude"]
  let environmentKeys = ["CLAUDE_CONFIG_DIR"]

  func arguments(for turn: AgentTurn) -> [String] {
    var parts = ["-p", "--output-format", "stream-json", "--verbose", "--permission-mode", "default"]
    for tool in Self.allowedTools {
      parts += ["--allowedTools", tool]
    }
    if let resumeID = turn.resumeID {
      parts += ["--resume", resumeID]
    }
    return parts
  }

  func standardInput(for turn: AgentTurn) -> String? {
    turn.prompt
  }

  func parse(line: String) -> [AgentEvent] {
    guard let data = line.data(using: .utf8), let envelope = try? JSONDecoder().decode(ClaudeEnvelope.self, from: data) else {
      return []
    }
    switch envelope.type {
    case "system":
      guard envelope.subtype == "init", let sessionID = envelope.sessionID, !sessionID.isEmpty else { return [] }
      return [.sessionStarted(id: sessionID)]
    case "assistant":
      return assistantEvents(from: envelope.message?.content ?? [])
    case "user":
      return toolResultEvents(from: envelope.message?.content ?? [])
    case "result":
      return [.turnCompleted(turnResult(from: envelope))]
    case "error":
      return [.error(message: errorMessage(from: envelope))]
    case "rate_limit_event", "stream_event":
      return []
    default:
      return [.unknown(type: envelope.type ?? "")]
    }
  }

  private func assistantEvents(from blocks: [ClaudeContentBlock]) -> [AgentEvent] {
    var events: [AgentEvent] = []
    for block in blocks {
      switch block.type {
      case "text":
        if let text = block.text, !text.isEmpty {
          events.append(.textDelta(text))
        }
      case "tool_use":
        events.append(
          .toolCallStarted(
            id: block.id ?? UUID().uuidString,
            name: block.name ?? "unknown",
            input: block.input?.compactJSON ?? ""
          )
        )
      default:
        continue
      }
    }
    return events
  }

  private func toolResultEvents(from blocks: [ClaudeContentBlock]) -> [AgentEvent] {
    blocks.compactMap { block in
      guard block.type == "tool_result", let id = block.toolUseID else { return nil }
      return .toolCallFinished(id: id, output: toolResultText(block.content), isError: block.isError ?? false)
    }
  }

  private func toolResultText(_ content: AgentJSONValue?) -> String {
    guard let content else { return "" }
    if let text = content.stringValue { return text }
    if let text = content.joinedText { return text }
    return content.isNull ? "" : content.compactJSON
  }

  private func turnResult(from envelope: ClaudeEnvelope) -> AgentTurnResult {
    var text: String?
    if let structured = envelope.structuredOutput, !structured.isNull {
      text = structured.compactJSON
    } else if let result = envelope.result, !result.isEmpty {
      text = result
    }
    let subtypeIsError = envelope.subtype != nil && envelope.subtype != "success"
    return AgentTurnResult(
      isError: (envelope.isError ?? false) || subtypeIsError,
      text: text,
      costUSD: envelope.totalCostUSD,
      durationMs: envelope.durationMs
    )
  }

  private func errorMessage(from envelope: ClaudeEnvelope) -> String {
    if let message = envelope.error?["message"]?.stringValue, !message.isEmpty { return message }
    if let message = envelope.error?.stringValue, !message.isEmpty { return message }
    if let message = envelope.messageText, !message.isEmpty { return message }
    return "Unknown CLI error"
  }
}

private struct ClaudeEnvelope: Decodable {
  var type: String?
  var subtype: String?
  var sessionID: String?
  var message: ClaudeMessage?
  var messageText: String?
  var isError: Bool?
  var result: String?
  var structuredOutput: AgentJSONValue?
  var totalCostUSD: Double?
  var durationMs: Int?
  var error: AgentJSONValue?

  private enum CodingKeys: String, CodingKey {
    case type
    case subtype
    case sessionID = "session_id"
    case message
    case isError = "is_error"
    case result
    case structuredOutput = "structured_output"
    case totalCostUSD = "total_cost_usd"
    case durationMs = "duration_ms"
    case error
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    type = try container.decodeIfPresent(String.self, forKey: .type)
    subtype = try container.decodeIfPresent(String.self, forKey: .subtype)
    sessionID = try container.decodeIfPresent(String.self, forKey: .sessionID)
    message = try? container.decodeIfPresent(ClaudeMessage.self, forKey: .message)
    messageText = try? container.decodeIfPresent(String.self, forKey: .message)
    isError = try? container.decodeIfPresent(Bool.self, forKey: .isError)
    result = try? container.decodeIfPresent(String.self, forKey: .result)
    structuredOutput = try? container.decodeIfPresent(AgentJSONValue.self, forKey: .structuredOutput)
    totalCostUSD = try? container.decodeIfPresent(Double.self, forKey: .totalCostUSD)
    durationMs = try? container.decodeIfPresent(Int.self, forKey: .durationMs)
    error = try? container.decodeIfPresent(AgentJSONValue.self, forKey: .error)
  }
}

private struct ClaudeMessage: Decodable {
  var role: String?
  var content: [ClaudeContentBlock]?
}

private struct ClaudeContentBlock: Decodable {
  var type: String?
  var text: String?
  var id: String?
  var name: String?
  var input: AgentJSONValue?
  var toolUseID: String?
  var content: AgentJSONValue?
  var isError: Bool?

  private enum CodingKeys: String, CodingKey {
    case type
    case text
    case id
    case name
    case input
    case toolUseID = "tool_use_id"
    case content
    case isError = "is_error"
  }
}
