import Testing

@testable import Reframed

struct ZoomDetectorTests {
  private let config = ZoomDetectorConfig(zoomLevel: 2, dwellThresholdSeconds: 0.5, transitionDuration: 0.5)

  private func metadata(clicks: [CursorClickEvent]) -> CursorMetadataFile {
    CursorMetadataFile(captureAreaWidth: 1920, captureAreaHeight: 1080, displayScale: 2, clicks: clicks)
  }

  private func click(_ t: Double, x: Double, y: Double) -> CursorClickEvent {
    CursorClickEvent(t: t, x: x, y: y, button: 0)
  }

  @Test func noClicksProduceNoKeyframes() {
    let keyframes = ZoomDetector.detect(from: metadata(clicks: []), duration: 10, config: config)
    #expect(keyframes.isEmpty)
  }

  @Test func twoClicksCloserThanDwellFormOneRegionOfFourKeyframes() {
    let file = metadata(clicks: [click(1, x: 0.25, y: 0.5), click(1.25, x: 0.75, y: 1)])
    let keyframes = ZoomDetector.detect(from: file, duration: 10, config: config)
    #expect(keyframes.count == 4)
    #expect(keyframes.map(\.t) == [0.5, 1, 1.5, 2])
    #expect(keyframes.map(\.zoomLevel) == [1, 2, 2, 1])
    #expect(keyframes.allSatisfy { $0.isAuto })
    #expect(keyframes.allSatisfy { $0.centerX == 0.5 && $0.centerY == 0.75 })
  }

  @Test func keyframesAreSortedByTime() {
    let file = metadata(clicks: [click(5, x: 0.1, y: 0.1), click(1, x: 0.9, y: 0.9)])
    let keyframes = ZoomDetector.detect(from: file, duration: 10, config: config)
    #expect(keyframes.map(\.t) == keyframes.map(\.t).sorted())
  }

  @Test func zoomInTimeIsClampedToZero() {
    let file = metadata(clicks: [click(0.25, x: 0.5, y: 0.5)])
    let keyframes = ZoomDetector.detect(from: file, duration: 10, config: config)
    #expect(keyframes.map(\.t) == [0, 0.25, 0.75, 1.25])
  }

  @Test func zoomOutTimeIsClampedToDurationButHoldTimeIsNot() {
    let file = metadata(clicks: [click(9.75, x: 0.5, y: 0.5)])
    let keyframes = ZoomDetector.detect(from: file, duration: 10, config: config)
    #expect(keyframes.map(\.t) == [9.25, 9.75, 10, 10.25])
    #expect(keyframes.map(\.zoomLevel) == [1, 2, 1, 2])
  }

  @Test func clicksOutsideDurationAreIgnored() {
    let file = metadata(clicks: [click(-1, x: 0.1, y: 0.1), click(3, x: 0.5, y: 0.5), click(11, x: 0.9, y: 0.9)])
    let keyframes = ZoomDetector.detect(from: file, duration: 10, config: config)
    #expect(keyframes.count == 4)
    #expect(keyframes.allSatisfy { $0.centerX == 0.5 && $0.centerY == 0.5 })
    let onlyOutside = metadata(clicks: [click(-1, x: 0.1, y: 0.1), click(11, x: 0.9, y: 0.9)])
    #expect(ZoomDetector.detect(from: onlyOutside, duration: 10, config: config).isEmpty)
  }

  @Test func clickExactlyAtDurationIsKept() {
    let file = metadata(clicks: [click(10, x: 0.5, y: 0.5)])
    let keyframes = ZoomDetector.detect(from: file, duration: 10, config: config)
    #expect(keyframes.count == 4)
  }

  @Test func regionsWhoseTransitionsOverlapAreMergedWithAWeightedCenter() {
    let file = metadata(clicks: [click(1, x: 0, y: 0), click(2, x: 0.75, y: 0.75), click(2.25, x: 0.75, y: 0.75)])
    let keyframes = ZoomDetector.detect(from: file, duration: 10, config: config)
    #expect(keyframes.count == 4)
    #expect(keyframes.map(\.t) == [0.5, 1, 2.25, 2.75])
    #expect(keyframes.allSatisfy { $0.centerX == 0.5 && $0.centerY == 0.5 })
  }

  @Test func farApartClicksProduceSeparateRegions() {
    let file = metadata(clicks: [click(1, x: 0.2, y: 0.2), click(5, x: 0.8, y: 0.8)])
    let keyframes = ZoomDetector.detect(from: file, duration: 10, config: config)
    #expect(keyframes.count == 8)
    #expect(keyframes.map(\.t) == [0.5, 1, 1.5, 2, 4.5, 5, 5.5, 6])
    #expect(keyframes.prefix(4).allSatisfy { $0.centerX == 0.2 })
    #expect(keyframes.suffix(4).allSatisfy { $0.centerX == 0.8 })
  }

  @Test func holdLastsAtLeastHalfASecondEvenWithAShorterDwellThreshold() {
    let short = ZoomDetectorConfig(zoomLevel: 3, dwellThresholdSeconds: 0.125, transitionDuration: 0.25)
    let file = metadata(clicks: [click(2, x: 0.5, y: 0.5)])
    let keyframes = ZoomDetector.detect(from: file, duration: 10, config: short)
    #expect(keyframes.map(\.t) == [1.75, 2, 2.5, 2.75])
    #expect(keyframes.map(\.zoomLevel) == [1, 3, 3, 1])
  }

  @Test func groupZoomRegionsReturnsOneRegionForDetectedKeyframes() {
    let file = metadata(clicks: [click(1, x: 0.25, y: 0.5), click(1.25, x: 0.75, y: 1)])
    let keyframes = ZoomDetector.detect(from: file, duration: 10, config: config)
    let regions = groupZoomRegions(from: keyframes)
    #expect(regions.count == 1)
    let region = try! #require(regions.first)
    #expect(region.startIndex == 0)
    #expect(region.count == 4)
    #expect(region.startTime == 0.5)
    #expect(region.zoomStartTime == 1)
    #expect(region.zoomEndTime == 1.5)
    #expect(region.endTime == 2)
    #expect(region.isAuto)
    #expect(region.peakZoom == 2)
  }

  @Test func groupZoomRegionsSplitsSeparateDetectedRegions() {
    let file = metadata(clicks: [click(1, x: 0.2, y: 0.2), click(5, x: 0.8, y: 0.8)])
    let regions = groupZoomRegions(from: ZoomDetector.detect(from: file, duration: 10, config: config))
    #expect(regions.map(\.startIndex) == [0, 4])
    #expect(regions.map(\.count) == [4, 4])
    #expect(regions.map(\.startTime) == [0.5, 4.5])
    #expect(regions.map(\.endTime) == [2, 6])
  }

  @Test func groupZoomRegionsNeedsAtLeastTwoKeyframes() {
    #expect(groupZoomRegions(from: []).isEmpty)
    #expect(groupZoomRegions(from: [ZoomKeyframe(t: 0, zoomLevel: 2, centerX: 0.5, centerY: 0.5, isAuto: false)]).isEmpty)
  }

  @Test func groupZoomRegionsReportsThePeakZoomAcrossTheRegion() {
    let keyframes = [
      ZoomKeyframe(t: 0, zoomLevel: 1, centerX: 0.5, centerY: 0.5, isAuto: false),
      ZoomKeyframe(t: 1, zoomLevel: 2, centerX: 0.5, centerY: 0.5, isAuto: false),
      ZoomKeyframe(t: 2, zoomLevel: 3.5, centerX: 0.5, centerY: 0.5, isAuto: false),
      ZoomKeyframe(t: 3, zoomLevel: 2, centerX: 0.5, centerY: 0.5, isAuto: false),
      ZoomKeyframe(t: 4, zoomLevel: 1, centerX: 0.5, centerY: 0.5, isAuto: false),
    ]
    let regions = groupZoomRegions(from: keyframes)
    #expect(regions.count == 1)
    #expect(regions.first?.peakZoom == 3.5)
    #expect(regions.first?.count == 5)
    #expect(regions.first?.zoomEndTime == 3)
    #expect(regions.first?.isAuto == false)
  }

  @Test func groupZoomRegionsStartingZoomedInUsesTheFirstKeyframeAsZoomStart() {
    let keyframes = [
      ZoomKeyframe(t: 0, zoomLevel: 2, centerX: 0.5, centerY: 0.5, isAuto: false),
      ZoomKeyframe(t: 1, zoomLevel: 2, centerX: 0.5, centerY: 0.5, isAuto: false),
      ZoomKeyframe(t: 2, zoomLevel: 1, centerX: 0.5, centerY: 0.5, isAuto: false),
    ]
    let regions = groupZoomRegions(from: keyframes)
    #expect(regions.count == 1)
    #expect(regions.first?.startIndex == 0)
    #expect(regions.first?.count == 3)
    #expect(regions.first?.zoomStartTime == 0)
    #expect(regions.first?.zoomEndTime == 1)
    #expect(regions.first?.endTime == 2)
  }
}
