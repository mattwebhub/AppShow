import SwiftUI

struct PermissionRow: View {
  let title: String
  let description: String
  let granted: Bool
  let onRequest: () -> Void
  let onOpenSettings: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    HStack(alignment: .center, spacing: 16) {
      Image(systemName: granted ? "checkmark.circle.fill" : "lock.shield")
        .foregroundStyle(granted ? .green : AppShowColors.secondaryText)
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.system(size: FontSize.sm, weight: .medium))
          .foregroundStyle(AppShowColors.primaryText)
        Text(description)
          .font(.system(size: FontSize.xs))
          .foregroundStyle(AppShowColors.secondaryText)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      VStack(alignment: .trailing, spacing: 8) {
        if granted {
          Text("Allowed")
            .font(.system(size: FontSize.xs, weight: .medium))
            .foregroundStyle(.green)
        } else {
          Button("Allow", action: onRequest)
            .buttonStyle(PrimaryButtonStyle(size: .small))
        }
        Button("Open Settings", action: onOpenSettings)
          .buttonStyle(OutlineButtonStyle(size: .small))
      }
    }
    .padding(16)
    .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(AppShowColors.border, lineWidth: 1))
  }
}
