import SwiftUI

@MainActor
struct AgentConfirmationView: View {
  let request: AgentConfirmationRequest
  let onAllow: () -> Void
  let onDeny: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: Layout.compactSpacing) {
      HStack(spacing: Layout.compactSpacing) {
        Image(systemName: "shield.lefthalf.filled")
          .foregroundStyle(Color.orange)
        Text(request.title)
          .font(.system(size: FontSize.xs, weight: .semibold))
        Spacer()
      }
      Text(request.detail)
        .font(.system(size: FontSize.xxs))
        .foregroundStyle(AppShowColors.secondaryText)
        .textSelection(.enabled)
      HStack {
        Button("Deny", action: onDeny)
          .buttonStyle(SecondaryButtonStyle(size: .small))
        Button("Allow Once", action: onAllow)
          .buttonStyle(PrimaryButtonStyle(size: .small))
      }
    }
    .padding(10)
    .background(AppShowColors.muted)
    .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
    .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Color.orange.opacity(0.45), lineWidth: 1))
  }
}
