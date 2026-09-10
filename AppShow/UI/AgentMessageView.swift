import SwiftUI

@MainActor
struct AgentMessageView: View {
  let message: AgentMessageData

  var body: some View {
    Group {
      if message.role == .user {
        content
          .padding(10)
          .background(AppShowColors.muted, in: RoundedRectangle(cornerRadius: Radius.lg))
          .padding(.leading, 24)
      } else {
        content
      }
    }
    .font(.system(size: FontSize.xs))
    .foregroundStyle(AppShowColors.primaryText)
    .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
  }

  private var content: some View {
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
        if case .text? = message.content.last {
          Text("▋")
            .foregroundStyle(AppShowColors.secondaryText)
        } else {
          AgentActivityRow(text: message.content.isEmpty ? "Thinking…" : "Working…")
        }
      }
      if message.status == .cancelled {
        AgentNoticeView(text: "Stopped before the reply finished.", icon: "stop.circle")
      }
      if let reason = message.failureReason {
        AgentNoticeView(text: reason, tone: .error)
      }
    }
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
          statusIndicator
            .frame(width: 16, height: 16)
          Text(AgentToolPresentation.displayName(for: call.name))
            .font(.system(size: FontSize.xs, weight: .medium))
            .lineLimit(1)
          Text(AgentToolPresentation.editorArea(for: call.name))
            .font(.system(size: FontSize.xxs))
            .foregroundStyle(AppShowColors.tertiaryText)
            .lineLimit(1)
          Spacer(minLength: 0)
          if hasDetails {
            Image(systemName: "chevron.down")
              .font(.system(size: FontSize.xxs, weight: .semibold))
              .foregroundStyle(AppShowColors.secondaryText)
              .rotationEffect(.degrees(expanded ? 180 : 0))
          }
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(PlainCustomButtonStyle())
      .help(call.name)
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
    .background(AppShowColors.muted, in: RoundedRectangle(cornerRadius: Radius.md))
    .animation(.easeOut(duration: 0.15), value: expanded)
  }

  private var hasDetails: Bool {
    !call.input.isEmpty || call.output?.isEmpty == false
  }

  @ViewBuilder
  private var statusIndicator: some View {
    switch call.status {
    case .executing:
      ProgressView()
        .controlSize(.mini)
    case .completed:
      Image(systemName: "checkmark.circle")
        .foregroundStyle(AppShowColors.secondaryText)
    case .failed:
      Image(systemName: "exclamationmark.circle")
        .foregroundStyle(Color.red)
    }
  }

  private func detail(_ text: String) -> some View {
    Text(text)
      .font(.system(size: FontSize.xxs, design: .monospaced))
      .foregroundStyle(AppShowColors.secondaryText)
      .textSelection(.enabled)
  }
}
