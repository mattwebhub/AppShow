import Testing

@testable import Reframed

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
        .prose("## Result\n\n- first\n- second"),
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
}
