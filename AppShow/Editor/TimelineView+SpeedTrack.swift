import SwiftUI

extension TimelineView {
  func speedTrackContent(width: CGFloat) -> some View {
    let geometry = geometry(width: width)
    return ZStack(alignment: .leading) {
      RoundedRectangle(cornerRadius: Track.borderRadius)
        .fill(AppShowColors.backgroundCard)
      ForEach(editorState.speedRegions) { region in
        let previous = editorState.speedRegions.last { $0.endSeconds <= region.startSeconds }?.endSeconds ?? 0
        let next = editorState.speedRegions.first { $0.startSeconds >= region.endSeconds }?.startSeconds ?? totalSeconds
        SpeedRegionChip(
          region: region,
          geometry: geometry,
          height: trackHeight,
          bounds: previous...next,
          isEditable: !editorState.isExporting,
          duration: totalSeconds,
          onUpdate: { try editorState.updateSpeedRegion($0) },
          onRemove: { editorState.removeSpeedRegion(id: region.id) }
        )
      }
    }
    .frame(width: width, height: trackHeight)
    .coordinateSpace(name: "speedTrack")
  }
}
