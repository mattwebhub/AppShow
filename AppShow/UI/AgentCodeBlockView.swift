import AppKit
import SwiftUI

struct AgentCodeBlockView: View {
  let language: String?
  let code: String
  let isStreaming: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text(language ?? "Code")
          .font(.system(size: FontSize.xxs, weight: .medium))
          .foregroundStyle(AppShowColors.secondaryText)
        Spacer()
        Button {
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(code, forType: .string)
        } label: {
          Image(systemName: "doc.on.doc")
            .foregroundStyle(AppShowColors.secondaryText)
        }
        .buttonStyle(PlainCustomButtonStyle())
      }
      .padding(8)
      Divider()
        .overlay(AppShowColors.divider)
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
    .background(AppShowColors.fieldBackground, in: RoundedRectangle(cornerRadius: Radius.md))
    .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(AppShowColors.border, lineWidth: 1))
  }
}
