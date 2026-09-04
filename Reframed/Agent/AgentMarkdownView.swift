import AppKit
import SwiftUI

enum AgentMarkdownBlock: Equatable, Sendable {
  case prose(String)
  case code(language: String?, text: String, isStreaming: Bool)
}

enum AgentMarkdownParser {
  static func parse(_ text: String, maximumMarkdownBytes: Int = 64 * 1024) -> [AgentMarkdownBlock] {
    guard text.utf8.count <= maximumMarkdownBytes else { return [.prose(text)] }
    var blocks: [AgentMarkdownBlock] = []
    var prose: [String] = []
    var code: [String] = []
    var language: String?
    var insideFence = false

    func appendProse() {
      let value = prose.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
      if !value.isEmpty { blocks.append(.prose(value)) }
      prose.removeAll(keepingCapacity: true)
    }

    func appendCode(isStreaming: Bool) {
      let value = code.joined(separator: "\n").trimmingCharacters(in: .newlines)
      blocks.append(.code(language: language, text: value, isStreaming: isStreaming))
      code.removeAll(keepingCapacity: true)
      language = nil
    }

    for line in text.components(separatedBy: .newlines) {
      if line.hasPrefix("```") {
        if insideFence {
          appendCode(isStreaming: false)
        } else {
          appendProse()
          let label = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
          language = label.isEmpty ? nil : label
        }
        insideFence.toggle()
      } else if insideFence {
        code.append(line)
      } else {
        prose.append(line)
      }
    }
    if insideFence {
      appendCode(isStreaming: true)
    } else {
      appendProse()
    }
    return blocks
  }
}

struct AgentMarkdownView: View {
  let text: String

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(Array(AgentMarkdownParser.parse(text).enumerated()), id: \.offset) { _, block in
        switch block {
        case .prose(let prose):
          Text(attributed(prose))
            .textSelection(.enabled)
        case .code(let language, let code, let isStreaming):
          AgentCodeBlockView(language: language, code: code, isStreaming: isStreaming)
        }
      }
    }
  }

  private func attributed(_ text: String) -> AttributedString {
    (try? AttributedString(markdown: text)) ?? AttributedString(text)
  }
}

private struct AgentCodeBlockView: View {
  let language: String?
  let code: String
  let isStreaming: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text(language ?? "Code")
          .font(.system(size: FontSize.xxs, weight: .medium))
          .foregroundStyle(ReframedColors.secondaryText)
        Spacer()
        Button {
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(code, forType: .string)
        } label: {
          Image(systemName: "doc.on.doc")
            .foregroundStyle(ReframedColors.secondaryText)
        }
        .buttonStyle(PlainCustomButtonStyle())
      }
      .padding(8)
      Divider()
        .overlay(ReframedColors.divider)
      HStack(alignment: .bottom, spacing: 2) {
        Text(code)
          .font(.system(size: FontSize.xxs, design: .monospaced))
          .textSelection(.enabled)
        if isStreaming {
          Text("▋")
            .font(.system(size: FontSize.xxs, design: .monospaced))
        }
      }
      .padding(8)
    }
    .background(ReframedColors.fieldBackground)
    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
    .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(ReframedColors.border, lineWidth: 1))
  }
}
