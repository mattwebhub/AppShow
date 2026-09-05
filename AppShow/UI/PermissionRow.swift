import SwiftUI

struct PermissionRow: View {
  let icon: String
  let title: String
  let description: String
  let granted: Bool
  let onRequest: () -> Void
  let onOpenSettings: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    HStack(alignment: .center, spacing: Layout.itemSpacing) {
      Image(systemName: icon)
        .font(.system(size: FontSize.base))
        .foregroundStyle(AppShowColors.secondaryText)
        .frame(width: 24)

      VStack(alignment: .leading, spacing: 6) {
        Text(title)
          .font(.system(size: FontSize.xs, weight: .medium))
          .foregroundStyle(AppShowColors.primaryText)
        Text(description)
          .font(.system(size: FontSize.xs))
          .foregroundStyle(AppShowColors.secondaryText)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      HStack(spacing: Layout.compactSpacing) {
        if granted {
          Label("Allowed", systemImage: "checkmark")
            .font(.system(size: FontSize.xs, weight: .medium))
            .foregroundStyle(AppShowColors.secondaryText)
            .frame(width: 84, height: ButtonSize.small.height)
        } else {
          Button("Allow", action: onRequest)
            .buttonStyle(OutlineButtonStyle(size: .small, fullWidth: true))
            .frame(width: 84)
            .accessibilityLabel("Allow \(title)")
        }
        Button(action: onOpenSettings) {
          Image(systemName: "arrow.up.right")
            .frame(width: ButtonSize.small.height)
        }
        .buttonStyle(OutlineButtonStyle(size: .small, fullWidth: true))
        .frame(width: ButtonSize.small.height)
        .help("Open \(title) in System Settings")
        .accessibilityLabel("Open \(title) in System Settings")
      }
    }
    .padding(.vertical, Layout.itemSpacing)
  }
}
