import Testing

@testable import AppShow

struct AgentMarkdownParserTests {
  @Test func parserSplitsProseAndFencedCode() {
    let blocks = AgentMarkdownParser.parse(
      """
      ## Result

      - first
      - second

      ```swift
      let answer = 42
      ```

      Done.
      """
    )
    #expect(
      blocks == [
        .heading(level: 2, text: "Result"),
        .listItem(marker: "•", text: "first", depth: 0),
        .listItem(marker: "•", text: "second", depth: 0),
        .code(language: "swift", text: "let answer = 42", isStreaming: false),
        .prose("Done."),
      ]
    )
  }

  @Test func parserKeepsAnUnterminatedFenceOpenWhileStreaming() {
    let blocks = AgentMarkdownParser.parse("Before\n\n```json\n{\"ready\": true}")
    #expect(
      blocks == [
        .prose("Before"),
        .code(language: "json", text: "{\"ready\": true}", isStreaming: true),
      ]
    )
  }

  @Test func parserSupportsAnUnlabelledFence() {
    #expect(
      AgentMarkdownParser.parse("```\nhello\n```")
        == [.code(language: nil, text: "hello", isStreaming: false)]
    )
  }

  @Test func parserFallsBackToPlainTextAboveTheLimit() {
    let text = String(repeating: "a", count: 65)
    #expect(AgentMarkdownParser.parse(text, maximumMarkdownBytes: 64) == [.prose(text)])
  }
  @Test func paragraphsRemainSeparateInsteadOfRunningTogether() {
    #expect(
      AgentMarkdownParser.parse("First paragraph.\n\nSecond **paragraph**.") == [
        .prose("First paragraph."), .prose("Second **paragraph**."),
      ]
    )
  }

  @Test func listItemsKeepTheirMarkersIndentationAndInlineFormatting() {
    #expect(
      AgentMarkdownParser.parse("- **Inspect:** project details\n  - transcript\n1. Export\n   the video") == [
        .listItem(marker: "•", text: "**Inspect:** project details", depth: 0),
        .listItem(marker: "•", text: "transcript", depth: 1),
        .listItem(marker: "1.", text: "Export\nthe video", depth: 0),
      ]
    )
  }

  @Test func inlineFormattingPreservesLineBreaksAndLinks() {
    let rendered = AgentMarkdownParser.inline("**First**\nSecond [link](https://example.com)")
    #expect(String(rendered.characters) == "First\nSecond link")
    #expect(rendered.runs.contains { $0.link != nil })
  }

}
