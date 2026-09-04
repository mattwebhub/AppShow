import SwiftUI

extension ZoomKeyframeEditor {
  func effectiveTimes(for region: ZoomRegion) -> (start: Double, zoomStart: Double, zoomEnd: Double, end: Double) {
    guard let edited = groupZoomRegions(from: effectiveKeyframes(for: region)).first else {
      return (region.startTime, region.zoomStartTime, region.zoomEndTime, region.endTime)
    }
    return (edited.startTime, edited.zoomStartTime, edited.zoomEndTime, edited.endTime)
  }

  func effectiveKeyframes(for region: ZoomRegion) -> [ZoomKeyframe] {
    let original = Array(keyframes[region.startIndex..<(region.startIndex + region.count)])
    guard dragRegionStartIndex == region.startIndex, let dragType else { return original }
    let others = regions.filter { $0.startIndex != region.startIndex }
    let previousEnd = others.last(where: { $0.endTime <= region.startTime })?.endTime ?? 0
    let nextStart = others.first(where: { $0.startTime >= region.endTime })?.startTime ?? duration
    return region.editedKeyframes(from: original, drag: dragType, delta: dragSourceDelta, bounds: previousEnd...nextStart)
  }

  func commitDrag(for region: ZoomRegion) {
    guard dragType != nil else { return }
    onUpdateRegion(region.startIndex, region.count, effectiveKeyframes(for: region))
  }
}
