import Foundation
import Testing

@testable import Reframed

@MainActor
struct StateServiceAgentPanelTests {
  @Test func panelDefaultsToExpandedAtDefaultWidth() throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let service = StateService(fileURL: dir.appendingPathComponent("state.json"))
    #expect(!service.agentPanelCollapsed)
    #expect(service.agentPanelWidth == AgentPanelLayout.defaultWidth)
  }

  @Test func panelStatePersistsAndClampsWidth() throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let file = dir.appendingPathComponent("state.json")
    let service = StateService(fileURL: file)
    service.agentPanelCollapsed = true
    service.agentPanelWidth = 900

    let reloaded = StateService(fileURL: file)
    #expect(reloaded.agentPanelCollapsed)
    #expect(reloaded.agentPanelWidth == AgentPanelLayout.maximumWidth)
  }
}
