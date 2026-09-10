import Testing

@testable import AppShow

struct AgentToolPresentationTests {
  @Test func humanizesToolNamesForChatRows() {
    #expect(AgentToolPresentation.displayName(for: "update_text") == "Update text")
    #expect(AgentToolPresentation.displayName(for: "get_timeline") == "Get timeline")
    #expect(AgentToolPresentation.displayName(for: "export") == "Export")
    #expect(AgentToolPresentation.displayName(for: "") == "")
  }

  @Test func mapsToolNamesToEditorAreas() {
    #expect(AgentToolPresentation.editorArea(for: "update_text") == "Text")
    #expect(AgentToolPresentation.editorArea(for: "remove_silences") == "Cuts")
    #expect(AgentToolPresentation.editorArea(for: "get_timeline") == "Project")
  }

  @Test func catalogTitleKeepsAreaPrefixAndCapitalizedWords() {
    let definition = AgentToolDefinition(name: "update_text", description: "", inputSchema: [:], mutating: true)
    #expect(definition.displayTitle == "Text · Update Text")
  }
}
