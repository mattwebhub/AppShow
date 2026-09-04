import Foundation
import Testing

@testable import Reframed

@MainActor
struct ConfigServiceAgentTests {
  @Test func providerDefaultsToClaudeAndPersists() throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let file = dir.appendingPathComponent("config.json")
    let service = ConfigService(fileURL: file)
    #expect(service.agentProvider == .claudeCode)
    service.agentProvider = .codex
    #expect(ConfigService(fileURL: file).agentProvider == .codex)
  }

  @Test func unknownProviderFallsBackToClaude() throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let file = dir.appendingPathComponent("config.json")
    try #"{"agentProvider":"future"}"#.write(to: file, atomically: true, encoding: .utf8)
    #expect(ConfigService(fileURL: file).agentProvider == .claudeCode)
  }
}
