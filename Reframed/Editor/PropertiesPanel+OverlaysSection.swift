import CoreMedia
import SwiftUI

extension PropertiesPanel {
  var overlaysSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "textformat", title: "Text Overlays")

      Button {
        editorState.addTextOverlay(atTime: CMTimeGetSeconds(editorState.currentTime))
      } label: {
        Label("Add Text", systemImage: "plus")
      }
      .buttonStyle(PrimaryButtonStyle(size: .small, fullWidth: true))

      Text("Adds a title at the playhead. Drag it on the Overlays track and right-click to edit.")
        .font(.system(size: FontSize.xs))
        .foregroundStyle(ReframedColors.secondaryText)
        .fixedSize(horizontal: false, vertical: true)

      if !editorState.textOverlays.isEmpty {
        VStack(spacing: 2) {
          ForEach(editorState.textOverlays) { overlay in
            TextOverlayRow(overlay: overlay) {
              editorState.pause()
              editorState.seek(to: CMTime(seconds: overlay.startSeconds, preferredTimescale: 600))
            }
          }
        }
      }
    }
  }
}

private struct TextOverlayRow: View {
  let overlay: TextOverlayData
  let onSeek: () -> Void

  var body: some View {
    Button(action: onSeek) {
      HStack(spacing: 8) {
        Text("\(formatCompactTime(seconds: overlay.startSeconds))–\(formatCompactTime(seconds: overlay.endSeconds))")
          .font(.system(size: FontSize.xs, design: .monospaced))
          .foregroundStyle(ReframedColors.secondaryText)
        Text(overlay.text.replacingOccurrences(of: "\n", with: " "))
          .font(.system(size: FontSize.xs))
          .foregroundStyle(ReframedColors.primaryText)
          .lineLimit(1)
          .truncationMode(.tail)
        Spacer()
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 6)
      .background(ReframedColors.muted.opacity(0.5), in: RoundedRectangle(cornerRadius: Radius.md))
      .contentShape(Rectangle())
    }
    .buttonStyle(PlainCustomButtonStyle())
  }
}
