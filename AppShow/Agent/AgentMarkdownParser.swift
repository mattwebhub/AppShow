import Foundation

enum AgentMarkdownBlock: Equatable, Sendable {
  case prose(String)
  case heading(level: Int, text: String)
  case listItem(marker: String, text: String, depth: Int)
  case quote(String)
  case divider
  case code(language: String?, text: String, isStreaming: Bool)
}

enum AgentMarkdownParser {
  static func inline(_ text: String) -> AttributedString {
    guard text.utf8.count <= 64 * 1024 else { return AttributedString(text) }
    return (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
      ?? AttributedString(text)
  }

  static func parse(_ text: String, maximumMarkdownBytes: Int = 64 * 1024) -> [AgentMarkdownBlock] {
    guard text.utf8.count <= maximumMarkdownBytes else { return [.prose(text)] }
    var blocks: [AgentMarkdownBlock] = []
    var prose: [String] = []
    var code: [String] = []
    var language: String?
    var fence: String?

    func appendProse() {
      let value = prose.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
      if !value.isEmpty { blocks.append(.prose(value)) }
      prose.removeAll(keepingCapacity: true)
    }

    for line in text.components(separatedBy: .newlines) {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if let activeFence = fence {
        if trimmed.hasPrefix(activeFence), trimmed.dropFirst(activeFence.count).allSatisfy({ $0 == activeFence.first! }) {
          blocks.append(.code(language: language, text: code.joined(separator: "\n"), isStreaming: false))
          code.removeAll(keepingCapacity: true)
          fence = nil
        } else {
          code.append(line)
        }
        continue
      }
      if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
        appendProse()
        let delimiter = String(trimmed.prefix { $0 == trimmed.first })
        fence = delimiter
        let label = trimmed.dropFirst(delimiter.count).trimmingCharacters(in: .whitespaces)
        language = label.isEmpty ? nil : label
      } else if trimmed.isEmpty {
        appendProse()
      } else if ["---", "***", "___"].contains(trimmed) {
        appendProse()
        blocks.append(.divider)
      } else if let heading = heading(trimmed) {
        appendProse()
        blocks.append(heading)
      } else if let item = listItem(line) {
        appendProse()
        blocks.append(item)
      } else if trimmed.hasPrefix("> ") {
        appendProse()
        blocks.append(.quote(String(trimmed.dropFirst(2))))
      } else if line.first?.isWhitespace == true, prose.isEmpty,
        case .listItem(let marker, let content, let depth)? = blocks.last
      {
        blocks[blocks.count - 1] = .listItem(marker: marker, text: content + "\n" + trimmed, depth: depth)
      } else {
        prose.append(line)
      }
    }
    if fence != nil {
      blocks.append(.code(language: language, text: code.joined(separator: "\n"), isStreaming: true))
    } else {
      appendProse()
    }
    return blocks
  }

  private static func heading(_ line: String) -> AgentMarkdownBlock? {
    let level = line.prefix { $0 == "#" }.count
    guard (1...6).contains(level), line.dropFirst(level).first == " " else { return nil }
    return .heading(level: level, text: line.dropFirst(level + 1).trimmingCharacters(in: .whitespaces))
  }

  private static func listItem(_ line: String) -> AgentMarkdownBlock? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    let depth = line.prefix { $0.isWhitespace }.reduce(0) { $0 + ($1 == "\t" ? 4 : 1) } / 2
    if let first = trimmed.first, "-*+".contains(first), trimmed.dropFirst().first == " " {
      return .listItem(marker: "•", text: String(trimmed.dropFirst(2)), depth: depth)
    }
    guard let range = trimmed.range(of: #"^\d+[.)]\s+"#, options: .regularExpression) else { return nil }
    let marker = trimmed[range].trimmingCharacters(in: .whitespaces)
    return .listItem(marker: marker, text: String(trimmed[range.upperBound...]), depth: depth)
  }
}
