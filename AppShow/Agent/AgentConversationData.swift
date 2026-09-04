import Foundation

enum AgentTimestamp {
  static func now() -> Date {
    Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down))
  }
}

enum AgentMessageRole: String, Codable, Sendable {
  case user
  case assistant
}

enum AgentMessageStatus: String, Codable, Sendable {
  case streaming
  case completed
  case failed
  case cancelled
}

enum AgentToolCallStatus: String, Codable, Sendable {
  case executing
  case completed
  case failed
}

struct AgentToolCallData: Codable, Sendable, Equatable, Identifiable {
  var id: UUID = UUID()
  var callID: String
  var name: String
  var input: String
  var output: String? = nil
  var status: AgentToolCallStatus = .executing
}

enum AgentContentData: Sendable, Equatable {
  case text(String)
  case toolCall(AgentToolCallData)
}

extension AgentContentData: Codable {
  private enum CodingKeys: String, CodingKey {
    case type
    case text
    case toolCall
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decodeOrDefault(.type, "text")
    switch type {
    case "toolCall":
      self = .toolCall(try container.decode(AgentToolCallData.self, forKey: .toolCall))
    default:
      self = .text(try container.decodeOrDefault(.text, ""))
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .text(let text):
      try container.encode("text", forKey: .type)
      try container.encode(text, forKey: .text)
    case .toolCall(let call):
      try container.encode("toolCall", forKey: .type)
      try container.encode(call, forKey: .toolCall)
    }
  }
}

struct AgentMessageData: Codable, Sendable, Equatable, Identifiable {
  var id: UUID = UUID()
  var role: AgentMessageRole
  var content: [AgentContentData]
  var status: AgentMessageStatus = .completed
  var failureReason: String? = nil
  var createdAt: Date = AgentTimestamp.now()

  var text: String {
    content.compactMap { block -> String? in
      if case .text(let text) = block { return text }
      return nil
    }.joined()
  }

  var toolCalls: [AgentToolCallData] {
    content.compactMap { block -> AgentToolCallData? in
      if case .toolCall(let call) = block { return call }
      return nil
    }
  }
}

extension AgentMessageData {
  private enum CodingKeys: String, CodingKey {
    case id
    case role
    case content
    case status
    case failureReason
    case createdAt
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decodeOrDefault(.id, UUID())
    role = try container.decodeOrDefault(.role, .assistant)
    content = try container.decodeOrDefault(.content, [])
    status = try container.decodeOrDefault(.status, .completed)
    failureReason = try container.decodeIfPresent(String.self, forKey: .failureReason)
    createdAt = try container.decodeOrDefault(.createdAt, AgentTimestamp.now())
  }
}

struct AgentConversationData: Codable, Sendable, Equatable {
  var provider: AgentProviderKind = .claudeCode
  var resumeIDs: [AgentProviderKind: String] = [:]
  var createdAt: Date = AgentTimestamp.now()
  var lastActivityAt: Date = AgentTimestamp.now()
  var messages: [AgentMessageData] = []
}

extension AgentConversationData {
  private enum CodingKeys: String, CodingKey {
    case provider
    case resumeIDs
    case sessionID
    case createdAt
    case lastActivityAt
    case messages
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    provider = try container.decodeOrDefault(.provider, .claudeCode)
    resumeIDs = try container.decodeOrDefault(.resumeIDs, [:])
    if resumeIDs.isEmpty, let legacySessionID = try container.decodeIfPresent(String.self, forKey: .sessionID) {
      resumeIDs[provider] = legacySessionID
    }
    createdAt = try container.decodeOrDefault(.createdAt, AgentTimestamp.now())
    lastActivityAt = try container.decodeOrDefault(.lastActivityAt, createdAt)
    messages = try container.decodeOrDefault(.messages, [])
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(provider, forKey: .provider)
    try container.encode(resumeIDs, forKey: .resumeIDs)
    try container.encode(createdAt, forKey: .createdAt)
    try container.encode(lastActivityAt, forKey: .lastActivityAt)
    try container.encode(messages, forKey: .messages)
  }

  func resumeID(for provider: AgentProviderKind) -> String? {
    resumeIDs[provider]
  }
}
