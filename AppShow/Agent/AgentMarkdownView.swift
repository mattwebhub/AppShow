import SwiftUI

struct AgentMarkdownView: View {
  let text: String

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      ForEach(Array(AgentMarkdownParser.parse(text).enumerated()), id: \.offset) { _, block in
        switch block {
        case .prose(let prose):
          markdownText(prose)
        case .heading(let level, let title):
          markdownText(title)
            .font(.system(size: level <= 2 ? FontSize.base : FontSize.sm, weight: .semibold))
            .padding(.top, 4)
        case .listItem(let marker, let text, let depth):
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(marker)
              .foregroundStyle(AppShowColors.secondaryText)
              .frame(minWidth: 14, alignment: .trailing)
            markdownText(text)
          }
          .padding(.leading, CGFloat(depth) * 12)
        case .quote(let text):
          HStack(spacing: 8) {
            Rectangle().fill(AppShowColors.border).frame(width: 2)
            markdownText(text).foregroundStyle(AppShowColors.secondaryText)
          }
          .fixedSize(horizontal: false, vertical: true)
        case .divider:
          Divider().overlay(AppShowColors.divider)
        case .code(let language, let code, let isStreaming):
          AgentCodeBlockView(language: language, code: code, isStreaming: isStreaming)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func markdownText(_ value: String) -> some View {
    Text(AgentMarkdownParser.inline(value))
      .textSelection(.enabled)
      .lineSpacing(3)
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}
