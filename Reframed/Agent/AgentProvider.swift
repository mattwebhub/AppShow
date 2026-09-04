import Foundation

enum AgentProviderKind: String, Codable, CaseIterable, Sendable, Identifiable {
  case claudeCode = "claude"
  case codex = "codex"

  var id: Self { self }

  var displayName: String {
    switch self {
    case .claudeCode: "Claude Code"
    case .codex: "Codex"
    }
  }

  func makeProvider() -> any AgentProvider {
    switch self {
    case .claudeCode: ClaudeCodeProvider()
    case .codex: CodexProvider()
    }
  }
}

struct AgentTurn: Sendable, Equatable {
  var prompt: String
  var resumeID: String?

  init(prompt: String, resumeID: String? = nil) {
    self.prompt = prompt
    self.resumeID = resumeID
  }
}

protocol AgentProvider: Sendable {
  var id: AgentProviderKind { get }
  var displayName: String { get }
  var executableNames: [String] { get }
  var environmentKeys: [String] { get }
  func arguments(for turn: AgentTurn) -> [String]
  func standardInput(for turn: AgentTurn) -> String?
  func parse(line: String) -> [AgentEvent]
}

extension AgentProvider {
  var displayName: String { id.displayName }
  var environmentKeys: [String] { [] }
}
