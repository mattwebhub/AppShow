import AVFoundation
import SwiftUI

extension TimelineView {
  @ViewBuilder
  func screenTrackContent(width: CGFloat) -> some View {
    let h = trackHeight
    if editorState.showCutTrack {
      ZStack {
        RoundedRectangle(cornerRadius: Track.borderRadius)
          .fill(Track.background)
        HStack(spacing: 3) {
          Image(systemName: "film")
            .font(.system(size: Track.fontSize))
          Text(formatTimeRange(start: 0, end: totalSeconds))
            .font(.system(size: Track.fontSize, weight: Track.fontWeight))
            .lineLimit(1)
        }
        .foregroundStyle(Track.regionTextColor)
        RoundedRectangle(cornerRadius: Track.borderRadius)
          .strokeBorder(Track.borderColor, lineWidth: Track.borderWidth)
      }
      .frame(width: width, height: h)
      .clipShape(RoundedRectangle(cornerRadius: Track.borderRadius))
    } else {
      ZStack(alignment: .leading) {
        ForEach(editorState.videoRegions) { region in
          videoRegionView(
            region: region,
            width: width,
            height: h
          )
        }
      }
      .frame(width: width, height: h)
      .clipped()
      .coordinateSpace(name: "videoRegion")
      .contentShape(Rectangle())
      .onTapGesture(count: 2) { location in
        let time = (location.x / width) * totalSeconds
        editorState.addVideoRegion(atTime: time)
      }
    }
  }
}
