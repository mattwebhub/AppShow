import SwiftUI

struct EditorTopBar: View {
  @Bindable var editorState: EditorState
  let onOpenFolder: () -> Void
  let onDelete: () -> Void
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    ZStack {
      Text(editorState.projectName)
        .font(.system(size: FontSize.xs, weight: .semibold))
        .foregroundStyle(AppShowColors.primaryText)

      HStack(spacing: 8) {
        if let activity = editorState.agentActivity {
          HStack(spacing: 6) {
            ProgressView()
              .controlSize(.small)
            Text(activity.label)
              .lineLimit(1)
          }
          .font(.system(size: FontSize.xxs, weight: .medium))
          .foregroundStyle(AppShowColors.primaryText)
          .padding(.horizontal, 10)
          .frame(height: 28)
          .background(AppShowColors.muted)
          .clipShape(Capsule())
        }
        Spacer()

        IconButton(systemName: "folder", color: AppShowColors.secondaryText, action: onOpenFolder)

        IconButton(systemName: "trash", color: AppShowColors.secondaryText, action: onDelete)
          .disabled(editorState.isExporting)

        Button("Export") { editorState.showExportSheet = true }
          .buttonStyle(PrimaryButtonStyle(size: .small))
          .disabled(editorState.isExporting)
      }
    }
    .padding(.leading, 16)
    .frame(height: 44)
    .animation(.easeInOut(duration: 0.15), value: editorState.agentActivity?.id)
  }
}
