import SwiftUI

@MainActor
struct AgentMessageView: View {
  let message: AgentMessageData

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ForEach(Array(message.content.enumerated()), id: \.offset) { _, content in
        switch content {
        case .text(let text):
          if message.role == .user {
            Text(AgentMarkdownParser.inline(text))
              .textSelection(.enabled)
              .fixedSize(horizontal: false, vertical: true)
          } else {
            AgentMarkdownView(text: text)
          }
        case .toolCall(let call):
          AgentToolCallView(call: call)
        }
      }
      if message.status == .streaming {
        Text("▋")
          .foregroundStyle(AppShowColors.secondaryText)
      }
      if let reason = message.failureReason {
        Text(reason)
          .font(.system(size: FontSize.xxs))
          .foregroundStyle(Color.red)
      }
    }
    .font(.system(size: FontSize.xs))
    .foregroundStyle(AppShowColors.primaryText)
    .padding(message.role == .user ? 10 : 0)
    .background(message.role == .user ? AppShowColors.muted : Color.clear)
    .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
    .padding(.leading, message.role == .user ? 24 : 0)
    .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
  }

}

@MainActor
private struct AgentToolCallView: View {
  let call: AgentToolCallData
  @State private var expanded = false

  var body: some View {
    VStack(alignment: .leading, spacing: Layout.compactSpacing) {
      Button {
        if hasDetails { expanded.toggle() }
      } label: {
        HStack(spacing: Layout.compactSpacing) {
          Image(systemName: icon)
          Text(call.name)
            .font(.system(size: FontSize.xs, weight: .medium))
          Spacer()
          if hasDetails {
            Image(systemName: expanded ? "chevron.up" : "chevron.down")
              .foregroundStyle(AppShowColors.secondaryText)
          }
        }
      }
      .buttonStyle(PlainCustomButtonStyle())
      if expanded {
        if !call.input.isEmpty {
          detail(call.input)
        }
        if let output = call.output, !output.isEmpty {
          detail(output)
        }
      }
    }
    .padding(8)
    .background(AppShowColors.muted)
    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
  }

  private var hasDetails: Bool {
    !call.input.isEmpty || call.output?.isEmpty == false
  }

  private func detail(_ text: String) -> some View {
    Text(text)
      .font(.system(size: FontSize.xxs, design: .monospaced))
      .foregroundStyle(AppShowColors.secondaryText)
      .textSelection(.enabled)
  }

  private var icon: String {
    switch call.status {
    case .executing: "hourglass"
    case .completed: "checkmark.circle"
    case .failed: "exclamationmark.circle"
    }
  }
}
