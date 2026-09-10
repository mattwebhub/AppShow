import AppKit
import SwiftUI

extension TimelineView {
  var videoDragTimeline: CutTimeline {
    guard let original = videoDragOriginalTimeline,
      let id = videoDragRegionId,
      let region = original.slices.first(where: { $0.id == id })
    else { return editorState.cutTimeline }
    let delta = Double(videoDragOffset) * videoDragSecondsPerPoint
    switch videoDragType {
    case .resizeLeft:
      return original.adjustingEdge(of: id, leading: true, to: region.startSeconds + delta)
    case .resizeRight:
      return original.adjustingEdge(of: id, leading: false, to: region.endSeconds + delta)
    case .move:
      return original.movingSlice(id, to: region.startSeconds + delta)
    case nil:
      return original
    }
  }

  func effectiveVideoRegion(_ region: VideoRegionData, width: CGFloat) -> (start: Double, end: Double) {
    let effective = videoDragTimeline.slices.first { $0.id == region.id } ?? region
    return (effective.startSeconds, effective.endSeconds)
  }

  func videoRegionDrag(region: VideoRegionData, width: CGFloat) -> some Gesture {
    DragGesture(minimumDistance: 3, coordinateSpace: .named("videoRegion"))
      .onChanged { value in
        guard !editorState.isExporting else { return }
        if videoDragType == nil {
          let startX = xPosition(forSource: region.startSeconds, width: width)
          let endX = xPosition(forSource: region.endSeconds, width: width)
          let edge = min(8.0, (endX - startX) * 0.2)
          let localX = value.startLocation.x - startX
          if localX <= edge {
            videoDragType = .resizeLeft
          } else if localX >= endX - startX - edge {
            videoDragType = .resizeRight
          } else if isTrackEditable {
            videoDragType = .move
          } else {
            return
          }
          NSApp.keyWindow?.makeFirstResponder(nil)
          editorState.pause()
          editorState.selectedVideoRegionID = region.id
          videoDragSecondsPerPoint = visibleSeconds / max(1, Double(width))
          videoDragOriginalTimeline = editorState.cutTimeline
          videoDragRegionId = region.id
        }
        videoDragOffset = value.translation.width
      }
      .onEnded { _ in
        guard videoDragType != nil else { return }
        editorState.commitVideoRegions(videoDragTimeline.slices, label: "Cut adjusted")
        videoDragOffset = 0
        videoDragType = nil
        videoDragRegionId = nil
        videoDragOriginalTimeline = nil
      }
  }
}
