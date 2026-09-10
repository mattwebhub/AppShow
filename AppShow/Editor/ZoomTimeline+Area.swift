import CoreGraphics
import Foundation

extension ZoomTimeline {
  static func areaKeyframes(rect: CGRect, start: Double, end: Double, transition: Double) throws -> [ZoomKeyframe] {
    guard [rect.minX, rect.minY, rect.width, rect.height, start, end, transition].allSatisfy(\.isFinite),
      rect.width > 0, rect.height > 0, rect.minX >= 0, rect.minY >= 0,
      rect.maxX <= 1.000001, rect.maxY <= 1.000001,
      start >= 0, end - start >= 0.05, transition > 0
    else { throw AgentToolError.invalidArguments("Select an area inside the source frame and a valid time range.") }
    let size = min(1, max(0.125, max(rect.width, rect.height)))
    let originX = max(0, min(1 - size, rect.midX - size / 2))
    let originY = max(0, min(1 - size, rect.midY - size / 2))
    let cx = size < 1 ? originX / (1 - size) : 0.5
    let cy = size < 1 ? originY / (1 - size) : 0.5
    let ramp = min(transition, (end - start) / 3)
    return [(start, 1.0), (start + ramp, 1 / size), (end - ramp, 1 / size), (end, 1.0)].map {
      ZoomKeyframe(t: $0.0, zoomLevel: $0.1, centerX: cx, centerY: cy, isAuto: false, targetRect: rect)
    }
  }
}

extension EditorState {
  func addAreaZoom(rect: CGRect, start: Double, end: Double, transition: Double = 0.5) throws {
    guard !isExporting, end <= duration.seconds else {
      throw AgentToolError.invalidArguments("The zoom range must be inside the recording.")
    }
    let frames = try ZoomTimeline.areaKeyframes(rect: rect, start: start, end: end, transition: transition)
    let existing = zoomTimeline?.allKeyframes ?? []
    guard !groupZoomRegions(from: existing).contains(where: { start < $0.endTime && end > $0.startTime }) else {
      throw AgentToolError.invalidArguments("This zoom overlaps an existing zoom. Choose another time range or remove the existing zoom.")
    }
    zoomEnabled = true
    zoomTimeline = ZoomTimeline(keyframes: existing + frames)
  }
}
