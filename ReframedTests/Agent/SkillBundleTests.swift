import Foundation
import Testing

@testable import Reframed

@MainActor
struct SkillBundleTests {
  @Test func everyShippedSkillHasMatchingValidFrontmatter() throws {
    let directory = try AgentSkillBundle.bundledSkillsDirectory()

    for name in AgentSkillBundle.skillNames {
      let url = directory.appendingPathComponent(name).appendingPathComponent("SKILL.md")
      let data = try Data(contentsOf: url)
      let text = try #require(String(data: data, encoding: .utf8))
      let frontmatter = try frontmatter(in: text)
      #expect(frontmatter["name"] == name)
      #expect(!(frontmatter["description"] ?? "").isEmpty)
      #expect((frontmatter["description"] ?? "").count <= 1024)
      #expect(data.count <= 256 * 1024)
    }
  }

  @Test func skillsReferenceOnlyAdvertisedCatalogTools() throws {
    let directory = try AgentSkillBundle.bundledSkillsDirectory()
    let tools = Set(
      AgentToolCatalog.all.map(\.name)
        + AgentEditingToolCatalog.handlers.map(\.definition.name)
    )
    let expression = try NSRegularExpression(pattern: "`([a-z][a-z0-9_]+)`")

    for name in AgentSkillBundle.skillNames {
      let text = try String(contentsOf: directory.appendingPathComponent(name).appendingPathComponent("SKILL.md"), encoding: .utf8)
      let range = NSRange(text.startIndex..., in: text)
      let references = expression.matches(in: text, range: range).compactMap { match -> String? in
        guard let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
      }
      #expect(Set(references).isSubset(of: tools), "\(name) references unknown tools: \(Set(references).subtracting(tools))")
    }
  }

  @Test func workspaceMaterializerWritesBothSkillTreesAndCanonicalGuidanceIdempotently() throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let source = directory.appendingPathComponent("source", isDirectory: true)
    let skill = source.appendingPathComponent("demo", isDirectory: true)
    try FileManager.default.createDirectory(at: skill, withIntermediateDirectories: true)
    let content = "---\nname: demo\ndescription: Demonstrate materialization.\n---\n\nUse the available tools.\n"
    try Data(content.utf8).write(to: skill.appendingPathComponent("SKILL.md"))
    let workspace = directory.appendingPathComponent("workspace", isDirectory: true)

    try AgentSkillBundle.materialize(
      into: workspace,
      skillsDirectory: source,
      skillNames: ["demo"],
      guidance: "Canonical guidance\n"
    )

    let claude = workspace.appendingPathComponent(".claude/skills/demo/SKILL.md")
    let codex = workspace.appendingPathComponent(".agents/skills/demo/SKILL.md")
    #expect(try String(contentsOf: claude, encoding: .utf8) == content)
    #expect(try String(contentsOf: codex, encoding: .utf8) == content)
    #expect(try String(contentsOf: workspace.appendingPathComponent("AGENTS.md"), encoding: .utf8) == "Canonical guidance\n")
    #expect(try FileManager.default.destinationOfSymbolicLink(atPath: workspace.appendingPathComponent("CLAUDE.md").path) == "AGENTS.md")

    try Data("changed".utf8).write(to: codex)
    try AgentSkillBundle.materialize(
      into: workspace,
      skillsDirectory: source,
      skillNames: ["demo"],
      guidance: "Canonical guidance\n"
    )
    #expect(try String(contentsOf: codex, encoding: .utf8) == content)
  }

  private func frontmatter(in text: String) throws -> [String: String] {
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
    guard lines.first == "---", let end = lines.dropFirst().firstIndex(of: "---") else {
      throw AgentToolError.failed("missing frontmatter")
    }
    return lines[1..<end].reduce(into: [:]) { result, line in
      let parts = line.split(separator: ":", maxSplits: 1)
      guard parts.count == 2 else { return }
      result[String(parts[0]).trimmingCharacters(in: .whitespaces)] =
        String(parts[1]).trimmingCharacters(in: .whitespaces)
    }
  }
}
