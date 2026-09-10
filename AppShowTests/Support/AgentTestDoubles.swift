import Foundation

@testable import AppShow

struct ScriptedProvider: AgentProvider {
  let id: AgentProviderKind
  let executableNames = ["cat"]
  let argumentsBuilder: @Sendable (AgentTurn) -> [String]
  let parser: any AgentProvider

  init(
    kind: AgentProviderKind = .claudeCode,
    parser: any AgentProvider = ClaudeCodeProvider(),
    arguments: @escaping @Sendable (AgentTurn) -> [String]
  ) {
    id = kind
    self.parser = parser
    argumentsBuilder = arguments
  }

  func arguments(for turn: AgentTurn) -> [String] {
    argumentsBuilder(turn)
  }

  func standardInput(for turn: AgentTurn) -> String? {
    nil
  }

  func parse(line: String) -> [AgentEvent] {
    parser.parse(line: line)
  }
}

struct EchoProvider: AgentProvider {
  let id: AgentProviderKind = .codex
  let executableNames = ["sh"]

  func arguments(for turn: AgentTurn) -> [String] {
    ["-c", "printf '%s\\n' \"$0\"", turn.resumeID ?? "none"]
  }

  func standardInput(for turn: AgentTurn) -> String? {
    nil
  }

  func parse(line: String) -> [AgentEvent] {
    [.textDelta(line)]
  }
}

enum AgentTestSupport {
  static func testEnvironment(home: URL) -> [String: String] {
    AgentEnvironment.scrubbed(path: "/usr/bin:/bin", home: home.path, forwarding: [])
  }

  static func writeScript(_ body: String, name: String, in directory: URL) throws -> URL {
    let url = directory.appendingPathComponent(name)
    try body.write(to: url, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    return url
  }

  static func hangingClaudeScript(in directory: URL) throws -> URL {
    try writeScript(
      """
      #!/bin/sh
      trap 'exit 143' TERM
      echo '{"type":"system","subtype":"init","session_id":"hang-session"}'
      echo '{"type":"assistant","message":{"content":[{"type":"text","text":"working"}]}}'
      while true; do sleep 0.05; done
      """,
      name: "hanging-claude",
      in: directory
    )
  }
}
