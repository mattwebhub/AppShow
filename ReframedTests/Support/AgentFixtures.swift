import Foundation

@testable import Reframed

enum AgentFixtures {
  static let recordedClaude = ["claude-2.1.260-turn", "claude-2.1.260-resume", "claude-2.1.260-tool-error"]
  static let recordedCodex = ["codex-0.149.1-turn", "codex-0.149.1-resume", "codex-0.149.1-command-error"]

  static func url(_ name: String) throws -> URL {
    let bundle = Bundle(for: FixtureAnchor.self)
    if let url = bundle.url(forResource: name, withExtension: "ndjson", subdirectory: "Fixtures/agent") {
      return url
    }
    if let url = bundle.url(forResource: name, withExtension: "ndjson") {
      return url
    }
    throw AgentFixtureError.missing(name)
  }

  static func lines(_ name: String) throws -> [String] {
    let text = try String(contentsOf: url(name), encoding: .utf8)
    return text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
  }

  static func line(_ name: String, _ index: Int) throws -> String {
    let all = try lines(name)
    guard index < all.count else { throw AgentFixtureError.missing("\(name):\(index)") }
    return all[index]
  }

  static func events(_ name: String, provider: any AgentProvider) throws -> [AgentEvent] {
    try lines(name).flatMap { provider.parse(line: $0) }
  }
}

enum AgentFixtureError: Error {
  case missing(String)
}
