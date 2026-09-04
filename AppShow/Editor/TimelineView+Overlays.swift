import AVFoundation
import SwiftUI

extension TimelineView {
  func agentChangeOverlay(contentWidth: CGFloat, inset: CGFloat) -> some View {
    let change = editorState.lastAgentChange
    let start = change.map { xPosition(forSource: $0.startSeconds, width: contentWidth) } ?? 0
    let end = change.map { xPosition(forSource: $0.endSeconds, width: contentWidth) } ?? 0
    let width = max(4, end - start)

    return ZStack(alignment: .leading) {
      if change != nil {
        RoundedRectangle(cornerRadius: Radius.sm)
          .fill(Color.orange.opacity(0.13))
          .frame(width: width, height: timelineHeight - rulerHeight)
          .offset(x: inset + start, y: rulerHeight)
      }
    }
    .frame(width: contentWidth + inset * 2, height: timelineHeight, alignment: .topLeading)
    .allowsHitTesting(false)
  }

  func trimBorderOverlay(
    width: CGFloat,
    height: CGFloat,
    trimStart: Double,
    trimEnd: Double
  ) -> some View {
    let startX = width * trimStart
    let endX = width * trimEnd
    let selectionWidth = endX - startX

    return ZStack(alignment: .leading) {
      Color.clear.frame(width: width, height: height)

      RoundedRectangle(cornerRadius: Track.borderRadius)
        .stroke(Track.borderColor, lineWidth: Track.borderWidth)
        .frame(width: max(0, selectionWidth), height: height)
        .offset(x: startX)
    }
    .allowsHitTesting(false)
  }

  func trimHandleOverlay(
    width: CGFloat,
    height: CGFloat,
    trimStart: Double,
    trimEnd: Double,
    onTrimStart: @escaping (Double) -> Void,
    onTrimEnd: @escaping (Double) -> Void
  ) -> some View {
    ZStack(alignment: .leading) {
      TrimHandle(
        edge: .leading,
        position: trimStart,
        totalWidth: width,
        height: height
      ) { newFraction in
        let clamped = min(newFraction, trimEnd - 0.01)
        onTrimStart(clamped)
      }

      TrimHandle(
        edge: .trailing,
        position: trimEnd,
        totalWidth: width,
        height: height
      ) { newFraction in
        let clamped = max(newFraction, trimStart + 0.01)
        onTrimEnd(clamped)
      }
    }
  }

  func playheadOverlay(contentWidth: CGFloat, inset: CGFloat) -> some View {
    let frameWidth = contentWidth + inset * 2
    let playheadX = xPosition(forSource: CMTimeGetSeconds(editorState.currentTime), width: contentWidth)

    return SwiftUI.TimelineView(.animation(paused: !editorState.isPlaying)) { _ in
      let x: CGFloat =
        if editorState.isPlaying {
          max(
            0,
            min(
              contentWidth,
              xPosition(forSource: CMTimeGetSeconds(editorState.playerController.screenPlayer.currentTime()), width: contentWidth)
            )
          )
        } else {
          playheadX
        }
      let centerX = inset + x
      let lineHeight = timelineHeight - rulerHeight

      ZStack {
        Rectangle()
          .fill(AppShowColors.primaryText.opacity(0.9))
          .frame(width: 2, height: lineHeight)
          .position(x: centerX, y: rulerHeight + lineHeight / 2)
          .allowsHitTesting(false)

        RoundedRectangle(cornerRadius: Radius.md)
          .fill(AppShowColors.primaryText.opacity(0.9))
          .frame(width: 12, height: rulerHeight)
          .position(x: centerX, y: rulerHeight / 2)
          .gesture(
            DragGesture(minimumDistance: 0)
              .onChanged { value in
                let time = CMTime(seconds: sourceTime(forX: value.location.x - inset, width: contentWidth), preferredTimescale: 600)
                onScrub(time)
              }
          )
      }
      .frame(width: frameWidth, height: timelineHeight)
    }
  }
}
