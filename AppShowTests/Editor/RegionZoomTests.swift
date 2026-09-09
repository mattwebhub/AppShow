import CoreGraphics
import Foundation
import Testing

@testable import AppShow

struct RegionZoomTests {
  @Test func selectedAreaFitsAndIgnoresCursor() throws {
    let target = CGRect(x: 0.65, y: 0.1, width: 0.25, height: 0.2)
    let frames = try ZoomTimeline.areaKeyframes(rect: target, start: 1, end: 5, transition: 0.5)
    let timeline = ZoomTimeline(keyframes: frames)
    let rect = timeline.zoomRect(at: 3, cursorPosition: CGPoint(x: 0, y: 1))
    #expect(abs(rect.width - 0.25) < 0.0001)
    #expect(rect.minX <= target.minX + 0.0001)
    #expect(rect.maxX >= target.maxX - 0.0001)
    #expect(rect.minY <= target.minY && rect.maxY >= target.maxY)
    #expect(rect == timeline.zoomRect(at: 3, cursorPosition: CGPoint(x: 1, y: 0)))
    #expect(timeline.zoomRect(at: 1).width == 1)
    #expect(timeline.zoomRect(at: 5).width == 1)
    let saved = try JSONEncoder().encode(frames)
    #expect(try JSONDecoder().decode([ZoomKeyframe].self, from: saved) == frames)
  }

  @Test func legacyKeyframesStillFollowCursor() throws {
    let data = Data("[{\"t\":0,\"zoomLevel\":2,\"centerX\":0.5,\"centerY\":0.5,\"isAuto\":false}]".utf8)
    let frames = try JSONDecoder().decode([ZoomKeyframe].self, from: data)
    let timeline = ZoomTimeline(keyframes: frames)
    #expect(timeline.zoomRect(at: 0, cursorPosition: .zero) == ZoomTimeline.followCursor(timeline.zoomRect(at: 0), cursorPosition: .zero))
  }

  @Test func invalidAreasAndDurationsAreRejected() {
    for rect in [CGRect.zero, CGRect(x: -0.1, y: 0, width: 0.2, height: 0.2), CGRect(x: 0.9, y: 0, width: 0.2, height: 0.2)] {
      #expect(throws: (any Error).self) { try ZoomTimeline.areaKeyframes(rect: rect, start: 0, end: 2, transition: 0.4) }
    }
    #expect(throws: (any Error).self) {
      try ZoomTimeline.areaKeyframes(rect: CGRect(x: 0, y: 0, width: 0.5, height: 0.5), start: 2, end: 1, transition: 0.4)
    }
  }
}
