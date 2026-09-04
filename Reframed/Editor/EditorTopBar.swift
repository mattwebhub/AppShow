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
        .foregroundStyle(ReframedColors.primaryText)

      HStack(spacing: 8) {
        if let activity = editorState.agentActivity {
          HStack(spacing: 6) {
            ProgressView()
              .controlSize(.small)
            Text(activity.label)
              .lineLimit(1)
          }
          .font(.system(size: FontSize.xxs, weight: .medium))
          .foregroundStyle(ReframedColors.primaryText)
          .padding(.horizontal, 10)
          .frame(height: 28)
          .background(ReframedColors.muted)
          .clipShape(Capsule())
        }
        Spacer()

        IconButton(systemName: "folder", color: ReframedColors.secondaryText, action: onOpenFolder)

        IconButton(systemName: "trash", color: ReframedColors.secondaryText, action: onDelete)
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
