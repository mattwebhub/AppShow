import CoreMedia
import SwiftUI

extension PropertiesPanel {
  var segmentsSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      Button {
        withAnimation(.easeInOut(duration: 0.2)) {
          captionSegmentsExpanded.toggle()
        }
      } label: {
        HStack(spacing: 6) {
          Image(systemName: "list.bullet")
            .font(.system(size: FontSize.xs, weight: .semibold))
            .foregroundStyle(AppShowColors.accent)
          Text("Segments (\(editorState.captionSegments.count))")
            .font(.system(size: FontSize.xs, weight: .semibold))
            .foregroundStyle(AppShowColors.primaryText)
          Spacer()
          Image(systemName: captionSegmentsExpanded ? "chevron.up" : "chevron.down")
            .font(.system(size: FontSize.xs, weight: .semibold))
            .foregroundStyle(AppShowColors.secondaryText)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(PlainCustomButtonStyle())

      if captionSegmentsExpanded {
        ScrollView {
          LazyVStack(spacing: 2) {
            ForEach(editorState.captionSegments) { segment in
              CaptionSegmentRow(
                segment: segment,
                onSeek: {
                  editorState.pause()
                  editorState.seek(
                    to: CMTime(seconds: segment.startSeconds, preferredTimescale: 600)
                  )
                },
                onUpdateText: { newText in
                  editorState.updateSegmentText(segment.id, text: newText)
                },
                onDelete: {
                  editorState.deleteSegment(segment.id)
                }
              )
            }
          }
        }
        .frame(maxHeight: 300)
      }
    }
  }
}
