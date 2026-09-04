import CoreGraphics
import Testing

@testable import AppShow

struct ZoomTimelineTests {
  private let unitRect = CGRect(x: 0, y: 0, width: 1, height: 1)

  @Test func emptyTimelineReturnsUnitRect() {
    let timeline = ZoomTimeline()
    #expect(timeline.zoomRect(at: 1.5) == unitRect)
  }

  @Test func zoomLevelAtOrBelowOneReturnsUnitRect() {
    let timeline = ZoomTimeline(keyframes: [
      ZoomKeyframe(t: 0, zoomLevel: 1, centerX: 0.2, centerY: 0.8, isAuto: false),
      ZoomKeyframe(t: 2, zoomLevel: 0.5, centerX: 0.9, centerY: 0.1, isAuto: false),
    ])
    #expect(timeline.zoomRect(at: 0) == unitRect)
    #expect(timeline.zoomRect(at: 1) == unitRect)
    #expect(timeline.zoomRect(at: 2) == unitRect)
  }

  @Test func midpointBetweenZoomOneAndTwoInterpolatesInInverseSpace() {
    let timeline = ZoomTimeline(keyframes: [
      ZoomKeyframe(t: 0, zoomLevel: 1, centerX: 0.5, centerY: 0.5, isAuto: false),
      ZoomKeyframe(t: 2, zoomLevel: 2, centerX: 0.5, centerY: 0.5, isAuto: false),
    ])
    let rect = timeline.zoomRect(at: 1)
    let expectedZoom = 4.0 / 3.0
    #expect(abs(rect.width - 1 / expectedZoom) < 1e-9)
    #expect(abs(rect.height - 0.75) < 1e-9)
    #expect(abs(rect.origin.x - 0.125) < 1e-9)
    #expect(abs(rect.origin.y - 0.125) < 1e-9)
  }

  @Test func timeOutsideKeyframeRangeClampsToNearestKeyframe() {
    let first = ZoomKeyframe(t: 1, zoomLevel: 2, centerX: 0.5, centerY: 0.5, isAuto: false)
    let last = ZoomKeyframe(t: 3, zoomLevel: 4, centerX: 1, centerY: 1, isAuto: false)
    let timeline = ZoomTimeline(keyframes: [last, first])
    #expect(timeline.zoomRect(at: -5) == CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5))
    #expect(timeline.zoomRect(at: 1) == CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5))
    #expect(timeline.zoomRect(at: 3) == CGRect(x: 0.75, y: 0.75, width: 0.25, height: 0.25))
    #expect(timeline.zoomRect(at: 99) == CGRect(x: 0.75, y: 0.75, width: 0.25, height: 0.25))
  }

  @Test func centerAtEdgesKeepsRectInsideUnitSquare() {
    let timeline = ZoomTimeline(keyframes: [
      ZoomKeyframe(t: 0, zoomLevel: 2, centerX: 0, centerY: 0, isAuto: false),
      ZoomKeyframe(t: 1, zoomLevel: 2, centerX: 1, centerY: 1, isAuto: false),
    ])
    #expect(timeline.zoomRect(at: 0) == CGRect(x: 0, y: 0, width: 0.5, height: 0.5))
    #expect(timeline.zoomRect(at: 1) == CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5))
    #expect(unitRect.contains(timeline.zoomRect(at: 0.5)))
  }

  @Test func followCursorClampsOriginToVisibleRange() {
    let zoomed = CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
    let farOutside = ZoomTimeline.followCursor(zoomed, cursorPosition: CGPoint(x: -0.5, y: 1.5))
    #expect(farOutside.origin.x == 0)
    #expect(farOutside.origin.y == 0.5)
    #expect(farOutside.size == zoomed.size)
    let centered = ZoomTimeline.followCursor(zoomed, cursorPosition: CGPoint(x: 0.5, y: 0.5))
    #expect(centered == zoomed)
  }

  @Test func followCursorReturnsInputWhenUnzoomed() {
    let moved = ZoomTimeline.followCursor(unitRect, cursorPosition: CGPoint(x: 0.9, y: 0.1))
    #expect(moved == unitRect)
  }

  @Test func keyframesAreSortedByTime() {
    let timeline = ZoomTimeline(keyframes: [
      ZoomKeyframe(t: 2, zoomLevel: 1, centerX: 0.5, centerY: 0.5, isAuto: false),
      ZoomKeyframe(t: 0, zoomLevel: 1, centerX: 0.5, centerY: 0.5, isAuto: true),
      ZoomKeyframe(t: 1, zoomLevel: 1, centerX: 0.5, centerY: 0.5, isAuto: false),
    ])
    #expect(timeline.allKeyframes.map(\.t) == [0, 1, 2])
  }

  @Test func equalTimeKeyframesResolveToTheLaterOne() {
    let timeline = ZoomTimeline(keyframes: [
      ZoomKeyframe(t: 0, zoomLevel: 1, centerX: 0.5, centerY: 0.5, isAuto: false),
      ZoomKeyframe(t: 1, zoomLevel: 2, centerX: 0.5, centerY: 0.5, isAuto: false),
      ZoomKeyframe(t: 1, zoomLevel: 4, centerX: 0.5, centerY: 0.5, isAuto: false),
      ZoomKeyframe(t: 2, zoomLevel: 1, centerX: 0.5, centerY: 0.5, isAuto: false),
    ])
    #expect(timeline.zoomRect(at: 1) == CGRect(x: 0.375, y: 0.375, width: 0.25, height: 0.25))
    #expect(timeline.zoomRect(at: 0.999).width > 0.49)
  }

  @Test func equalTimeKeyframesAtTheStartResolveToTheFirstOne() {
    let timeline = ZoomTimeline(keyframes: [
      ZoomKeyframe(t: 1, zoomLevel: 2, centerX: 0.5, centerY: 0.5, isAuto: false),
      ZoomKeyframe(t: 1, zoomLevel: 4, centerX: 0.5, centerY: 0.5, isAuto: false),
      ZoomKeyframe(t: 2, zoomLevel: 1, centerX: 0.5, centerY: 0.5, isAuto: false),
    ])
    #expect(timeline.zoomRect(at: 1) == CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5))
  }
}
