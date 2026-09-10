import SwiftUI

enum AgentNoticeTone {
  case info
  case warning
  case error

  var icon: String {
    switch self {
    case .info: "info.circle"
    case .warning: "exclamationmark.triangle"
    case .error: "exclamationmark.circle"
    }
  }

  @MainActor var color: Color {
    switch self {
    case .info: AppShowColors.secondaryText
    case .warning: Color.orange
    case .error: Color.red
    }
  }
}

struct AgentNoticeView: View {
  let text: String
  var tone: AgentNoticeTone = .info
  var icon: String? = nil

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      Image(systemName: icon ?? tone.icon)
        .foregroundStyle(tone.color)
      Text(text)
        .foregroundStyle(tone.color)
        .textSelection(.enabled)
    }
    .font(.system(size: FontSize.xxs))
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct AgentActivityRow: View {
  let text: String

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    HStack(spacing: 6) {
      ProgressView()
        .controlSize(.mini)
      Text(text)
    }
    .font(.system(size: FontSize.xxs))
    .foregroundStyle(AppShowColors.secondaryText)
  }
}
