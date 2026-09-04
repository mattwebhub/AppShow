import Foundation
import Testing

@testable import Reframed

struct AgentPanelLayoutTests {
  @Test func widthIsClampedToThePanelBounds() {
    #expect(AgentPanelLayout.clamp(100) == 260)
    #expect(AgentPanelLayout.clamp(320) == 320)
    #expect(AgentPanelLayout.clamp(900) == 480)
  }

  @Test func visibleWidthUsesRailWhenCollapsed() {
    #expect(AgentPanelLayout.visibleWidth(collapsed: true, expandedWidth: 400) == 40)
    #expect(AgentPanelLayout.visibleWidth(collapsed: false, expandedWidth: 400) == 400)
  }

  @Test func workspaceIsAHiddenSiblingOfTheProject() {
    let project = URL(fileURLWithPath: "/Users/me/Movies/Demo.frm", isDirectory: true)
    #expect(AgentProjectWorkspace.directory(for: project).path == "/Users/me/Movies/.agent/Demo")
  }
}
