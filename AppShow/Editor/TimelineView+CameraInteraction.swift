import SwiftUI

extension TimelineView {
  var isCameraTrackEditable: Bool { !editorState.isExporting && totalSeconds > 0 }

  func effectiveCameraRegion(_ region: CameraRegionData, width: CGFloat) -> (start: Double, end: Double) {
    guard cameraDragRegionId == region.id, let dt = cameraDragType else {
      return (region.startSeconds, region.endSeconds)
    }
    let anchor: Double
    switch dt {
    case .move: anchor = cameraDragAnchorTime
    case .resizeLeft: anchor = region.startSeconds
    case .resizeRight: anchor = region.endSeconds
    }
    let timeDelta = sourceTime(forX: xPosition(forSource: anchor, width: width) + cameraDragOffset, width: width) - anchor
    let regions = editorState.cameraRegions
    guard let idx = regions.firstIndex(where: { $0.id == region.id }) else {
      return (region.startSeconds, region.endSeconds)
    }
    let dur = totalSeconds
    let prevEnd: Double = idx > 0 ? regions[idx - 1].endSeconds : 0
    let nextStart: Double = idx < regions.count - 1 ? regions[idx + 1].startSeconds : dur

    let minDuration = 0.05

    switch dt {
    case .move:
      let regionDur = region.endSeconds - region.startSeconds
      let clampedStart = max(prevEnd, min(nextStart - regionDur, region.startSeconds + timeDelta))
      return (clampedStart, clampedStart + regionDur)
    case .resizeLeft:
      let newStart = max(prevEnd, min(region.endSeconds - minDuration, region.startSeconds + timeDelta))
      return (newStart, region.endSeconds)
    case .resizeRight:
      let newEnd = max(region.startSeconds + minDuration, min(nextStart, region.endSeconds + timeDelta))
      return (region.startSeconds, newEnd)
    }
  }

  func commitCameraDrag(region: CameraRegionData, width: CGFloat) {
    guard let type = cameraDragType else { return }
    let effective = effectiveCameraRegion(region, width: width)
    editorState.pendingUndoTask?.cancel()
    editorState.history.pushSnapshot(editorState.createSnapshot())
    switch type {
    case .move: editorState.moveCameraRegion(regionId: region.id, newStart: effective.start)
    case .resizeLeft: editorState.updateCameraRegionStart(regionId: region.id, newStart: effective.start)
    case .resizeRight: editorState.updateCameraRegionEnd(regionId: region.id, newEnd: effective.end)
    }
    editorState.history.pushSnapshot(editorState.createSnapshot(), label: "Webcam timing changed")
  }
}
