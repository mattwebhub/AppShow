import Foundation

enum AgentJSONValue: Codable, Sendable, Equatable {
  case string(String)
  case number(Double)
  case bool(Bool)
  case null
  case array([AgentJSONValue])
  case object([String: AgentJSONValue])

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(Double.self) {
      self = .number(value)
    } else if let value = try? container.decode(String.self) {
      self = .string(value)
    } else if let value = try? container.decode([AgentJSONValue].self) {
      self = .array(value)
    } else {
      self = .object(try container.decode([String: AgentJSONValue].self))
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .string(let value): try container.encode(value)
    case .number(let value): try container.encode(value)
    case .bool(let value): try container.encode(value)
    case .null: try container.encodeNil()
    case .array(let value): try container.encode(value)
    case .object(let value): try container.encode(value)
    }
  }

  var isNull: Bool {
    if case .null = self { return true }
    return false
  }

  var stringValue: String? {
    if case .string(let value) = self { return value }
    return nil
  }

  var doubleValue: Double? {
    if case .number(let value) = self { return value }
    return nil
  }

  var intValue: Int? {
    doubleValue.map { Int($0) }
  }

  var boolValue: Bool? {
    if case .bool(let value) = self { return value }
    return nil
  }

  var arrayValue: [AgentJSONValue]? {
    if case .array(let value) = self { return value }
    return nil
  }

  var objectValue: [String: AgentJSONValue]? {
    if case .object(let value) = self { return value }
    return nil
  }

  subscript(key: String) -> AgentJSONValue? {
    objectValue?[key]
  }

  var compactJSON: String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    guard let data = try? encoder.encode(self) else { return "" }
    return String(decoding: data, as: UTF8.self)
  }

  var joinedText: String? {
    switch self {
    case .string(let value):
      return value
    case .array(let blocks):
      let text = blocks.compactMap { block -> String? in
        guard let type = block["type"]?.stringValue, type == "text" || type == "output_text" else { return nil }
        return block["text"]?.stringValue
      }.joined()
      return text.isEmpty ? nil : text
    case .object:
      if let content = self["content"], let text = content.joinedText { return text }
      if let text = self["text"]?.stringValue, !text.isEmpty { return text }
      if let message = self["message"]?.stringValue, !message.isEmpty { return message }
      return nil
    case .number, .bool, .null:
      return nil
    }
  }
}
