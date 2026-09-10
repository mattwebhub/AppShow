import CoreMedia
import SwiftUI

extension EditorView {
  var previewProgressBar: some View {
    let totalDuration =
      editorState.hasTimeEdits
      ? editorState.videoRegionsTotalDuration
      : CMTimeGetSeconds(editorState.duration)
    let elapsed =
      editorState.hasTimeEdits
      ? editorState.previewElapsedTime
      : CMTimeGetSeconds(editorState.currentTime)
    let progress = CGFloat(elapsed / max(0.01, totalDuration))
    let barHeight: CGFloat = 4
    let thumbSize: CGFloat = 12

    return GeometryReader { geo in
      let thumbX = max(0, min(geo.size.width, geo.size.width * progress))

      ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: barHeight / 2)
          .fill(AppShowColors.muted)
          .frame(height: barHeight)

        RoundedRectangle(cornerRadius: barHeight / 2)
          .fill(AppShowColors.primaryText)
          .frame(width: thumbX, height: barHeight)

        Circle()
          .fill(AppShowColors.primaryText)
          .frame(width: thumbSize, height: thumbSize)
          .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
          .position(x: thumbX, y: geo.size.height / 2)
      }
      .frame(height: geo.size.height)
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            if editorState.isPlaying {
              editorState.pause()
            }
            seekPreviewProgress(x: value.location.x, width: geo.size.width, totalDuration: totalDuration)
          }
          .onEnded { _ in
            editorState.play()
          }
      )
    }
    .frame(height: thumbSize)
  }

  private func seekPreviewProgress(x: CGFloat, width: CGFloat, totalDuration: Double) {
    let fraction = max(0, min(1, Double(x / width)))
    let targetElapsed = fraction * totalDuration

    if editorState.hasTimeEdits {
      let sourceTime = editorState.sourceTimeForPreviewElapsed(targetElapsed)
      editorState.seek(to: CMTime(seconds: sourceTime, preferredTimescale: 600))
    } else {
      editorState.seek(to: CMTime(seconds: targetElapsed, preferredTimescale: 600))
    }
  }
}
