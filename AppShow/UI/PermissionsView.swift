import SwiftUI

struct PermissionsView: View {
  let permissions: PermissionStore
  var onContinue: () -> Void

  private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    VStack(alignment: .leading, spacing: 20) {
      Text("Recording permissions")
        .font(.system(size: FontSize.xl, weight: .semibold))
        .foregroundStyle(AppShowColors.primaryText)
      Text("Allow the features you want to use. You can open and edit projects at any time.")
        .font(.system(size: FontSize.sm))
        .foregroundStyle(AppShowColors.secondaryText)

      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          PermissionRow(
            title: "Screen Recording",
            description: "Required to record your screen. macOS may ask you to quit and reopen AppShow after allowing access.",
            granted: permissions.screenRecordingGranted,
            onRequest: { permissions.request(.screenRecording) },
            onOpenSettings: { NSWorkspace.shared.open(PermissionKind.screenRecording.settingsURL) }
          )
          PermissionRow(
            title: "Accessibility",
            description: "Enables global recording shortcuts and interaction with other app windows.",
            granted: permissions.accessibilityGranted,
            onRequest: { permissions.request(.accessibility) },
            onOpenSettings: { NSWorkspace.shared.open(PermissionKind.accessibility.settingsURL) }
          )

          if !permissions.allGranted {
            VStack(alignment: .leading, spacing: 8) {
              Text("Already enabled in System Settings?")
                .font(.system(size: FontSize.sm, weight: .medium))
              Text(
                "If Allow does nothing, open Settings directly. If AppShow is enabled there but still unavailable here, remove its old entry and add the copy shown in Finder, then quit and reopen AppShow."
              )
              .font(.system(size: FontSize.xs))
              .foregroundStyle(AppShowColors.secondaryText)
              .fixedSize(horizontal: false, vertical: true)
              HStack {
                Button("Show AppShow in Finder") {
                  NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
                }
                .buttonStyle(OutlineButtonStyle(size: .small))
                Button("Check Again") { permissions.refresh() }
                  .buttonStyle(OutlineButtonStyle(size: .small))
              }
            }
          }

        }
      }

      HStack {
        Spacer()
        Button("Continue to AppShow", action: onContinue)
          .buttonStyle(PrimaryButtonStyle())
      }
    }
    .padding(32)
    .frame(width: 720, height: 570)
    .onAppear { permissions.refresh() }
    .onReceive(timer) { _ in permissions.refresh() }
  }
}
