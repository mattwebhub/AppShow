import AppKit
import CoreMedia
import SwiftUI
import UniformTypeIdentifiers

extension PropertiesPanel {
  var overlaysSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "square.on.square", title: "Overlays")

      HStack(spacing: Layout.compactSpacing) {
        Button {
          editorState.addTextOverlay(atTime: CMTimeGetSeconds(editorState.currentTime))
        } label: {
          Label("Add Text", systemImage: "textformat")
        }
        .buttonStyle(PrimaryButtonStyle(size: .small, fullWidth: true))

        Button {
          pickOverlayImage()
        } label: {
          Label("Add Image", systemImage: "photo")
        }
        .buttonStyle(PrimaryButtonStyle(size: .small, fullWidth: true))
      }

      Text("Adds content at the playhead. Drag it on the Overlays track and right-click to edit.")
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

      if !editorState.imageOverlays.isEmpty {
        VStack(spacing: 2) {
          ForEach(editorState.imageOverlays) { overlay in
            ImageOverlayRow(overlay: overlay) {
              editorState.pause()
              editorState.seek(to: CMTime(seconds: overlay.startSeconds, preferredTimescale: 600))
            }
          }
        }
      }
    }
  }

  func pickOverlayImage() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff, .gif]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.begin { response in
      guard response == .OK, let url = panel.url else { return }
      DispatchQueue.main.async {
        editorState.addImageOverlay(
          from: url,
          atTime: CMTimeGetSeconds(editorState.currentTime)
        )
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

private struct ImageOverlayRow: View {
  let overlay: ImageOverlayData
  let onSeek: () -> Void

  var body: some View {
    Button(action: onSeek) {
      HStack(spacing: 8) {
        Image(systemName: "photo")
          .font(.system(size: FontSize.xs))
          .foregroundStyle(ReframedColors.secondaryText)
        Text("\(formatCompactTime(seconds: overlay.startSeconds))–\(formatCompactTime(seconds: overlay.endSeconds))")
          .font(.system(size: FontSize.xs, design: .monospaced))
          .foregroundStyle(ReframedColors.secondaryText)
        Text(overlay.displayName)
          .font(.system(size: FontSize.xs))
          .foregroundStyle(ReframedColors.primaryText)
          .lineLimit(1)
          .truncationMode(.middle)
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
