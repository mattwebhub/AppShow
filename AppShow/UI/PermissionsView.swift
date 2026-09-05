import SwiftUI

struct PermissionsView: View {
  static let windowSize = NSSize(width: 600, height: 420)

  let permissions: PermissionStore
  var onContinue: () -> Void

  @State private var showsRecovery = false
  private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: Layout.compactSpacing) {
        Text("Permissions")
          .font(.system(size: FontSize.lg, weight: .semibold))
          .foregroundStyle(AppShowColors.primaryText)
        Text("Choose what AppShow can access on your Mac.")
          .font(.system(size: FontSize.xs))
          .foregroundStyle(AppShowColors.secondaryText)
      }
      .padding(.horizontal, Layout.settingsPadding)
      .padding(.top, Layout.settingsPadding)
      .padding(.bottom, Layout.itemSpacing)

      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          PermissionRow(
            icon: "display",
            title: "Screen Recording",
            description: "Record your screen and capture system audio.",
            granted: permissions.screenRecordingGranted,
            onRequest: { permissions.request(.screenRecording) },
            onOpenSettings: { NSWorkspace.shared.open(PermissionKind.screenRecording.settingsURL) }
          )
          separator
          PermissionRow(
            icon: "accessibility",
            title: "Accessibility",
            description: "Use global shortcuts and follow app windows.",
            granted: permissions.accessibilityGranted,
            onRequest: { permissions.request(.accessibility) },
            onOpenSettings: { NSWorkspace.shared.open(PermissionKind.accessibility.settingsURL) }
          )

          if !permissions.allGranted {
            separator
            recoverySection
          }
        }
        .padding(.horizontal, Layout.settingsPadding)
      }

      separator
      HStack(spacing: Layout.itemSpacing) {
        Text("You can edit projects without these permissions.")
          .font(.system(size: FontSize.xxs))
          .foregroundStyle(AppShowColors.secondaryText)
        Spacer(minLength: 0)
        Button("Continue", action: onContinue)
          .buttonStyle(PrimaryButtonStyle(size: .small))
      }
      .padding(.horizontal, Layout.settingsPadding)
      .padding(.vertical, Layout.itemSpacing)
    }
    .frame(width: Self.windowSize.width, height: Self.windowSize.height)
    .background(AppShowColors.backgroundPopover)
    .onAppear { permissions.refresh() }
    .onReceive(timer) { _ in permissions.refresh() }
  }

  private var separator: some View {
    Rectangle()
      .fill(AppShowColors.border)
      .frame(height: 1)
  }

  private var recoverySection: some View {
    VStack(alignment: .leading, spacing: Layout.compactSpacing) {
      Button {
        showsRecovery.toggle()
      } label: {
        HStack(spacing: Layout.compactSpacing) {
          Image(systemName: showsRecovery ? "chevron.down" : "chevron.right")
            .font(.system(size: FontSize.xxs, weight: .semibold))
            .frame(width: 12)
          Text("Permission not updating?")
            .font(.system(size: FontSize.xs, weight: .medium))
          Spacer()
        }
        .foregroundStyle(AppShowColors.secondaryText)
        .padding(.vertical, Layout.compactSpacing)
        .contentShape(Rectangle())
      }
      .buttonStyle(PlainCustomButtonStyle())
      .accessibilityValue(showsRecovery ? "Expanded" : "Collapsed")

      if showsRecovery {
        Text(
          "Open System Settings using the arrow beside each permission. If AppShow is already enabled, remove its entry and add this copy from Finder, then quit and reopen AppShow."
        )
        .font(.system(size: FontSize.xs))
        .foregroundStyle(AppShowColors.secondaryText)
        .fixedSize(horizontal: false, vertical: true)
        HStack(spacing: Layout.compactSpacing) {
          Button("Show in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
          }
          .buttonStyle(OutlineButtonStyle(size: .small))
          Button("Check Again") { permissions.refresh() }
            .buttonStyle(OutlineButtonStyle(size: .small))
        }
      }
    }
    .padding(.vertical, Layout.compactSpacing)
  }
}
