import Foundation
import Testing

@testable import Reframed

struct TimelineGeometryTests {
  private func timeline(_ ranges: [(Double, Double)], duration: Double = 10) -> CutTimeline {
    CutTimeline(slices: ranges.map { VideoRegionData(startSeconds: $0.0, endSeconds: $0.1) }, duration: duration)
  }

  private func geometry(_ mode: TimelineDisplayMode, width: CGFloat = 400) -> TimelineGeometry {
    TimelineGeometry(timeline: timeline([(0, 2), (5, 7)]), width: width, mode: mode)
  }

  @Test func compressedXForSourceTimeSkipsGaps() {
    #expect(geometry(.compressed).x(forSource: 6) == 300)
    #expect(abs(geometry(.source).x(forSource: 6) - 240) < 1e-9)
  }

  @Test(arguments: [0.0, 0.5, 2, 3.7, 6, 9.99, 10])
  func sourceModeXMatchesProportionalMapping(source: Double) {
    let expected = CGFloat(source / 10) * 400
    #expect(geometry(.source).x(forSource: source) == expected)
  }

  @Test func sourceTimeInGapCollapsesToGapStartInCompressedMode() {
    #expect(geometry(.compressed).x(forSource: 3) == 200)
    #expect(geometry(.compressed).x(forSource: 5) == 200)
    #expect(geometry(.compressed).x(forSource: 9) == 400)
  }

  @Test(arguments: [0.25, 0.5, 1.0, 1.75, 5.25, 6.0, 6.9])
  func sourceTimeForCompressedXIsInverse(source: Double) {
    let g = geometry(.compressed)
    #expect(abs(g.sourceTime(forX: g.x(forSource: source)) - source) < 1e-9)
  }

  @Test func compressedXAtCutMarkerMapsToNextSliceStart() {
    #expect(geometry(.compressed).sourceTime(forX: 200) == 5)
  }

  @Test func compressedXBeyondEndMapsToLastSliceEnd() {
    #expect(geometry(.compressed).sourceTime(forX: 400) == 7)
    #expect(geometry(.compressed).sourceTime(forX: 900) == 7)
    #expect(geometry(.compressed).sourceTime(forX: -20) == 0)
  }

  @Test(arguments: [0.0, 40, 200, 333, 400])
  func sourceModeSourceTimeIsProportional(x: CGFloat) {
    #expect(geometry(.source).sourceTime(forX: x) == Double(x / 400) * 10)
  }

  @Test func visibleDurationFollowsMode() {
    #expect(geometry(.source).visibleDuration == 10)
    #expect(geometry(.compressed).visibleDuration == 4)
  }

  @Test func regionPiecesInCompressedModeMirrorRemap() {
    let pieces = geometry(.compressed).pieces(forRegion: 1, end: 6)
    #expect(pieces.map(\.start) == [1, 2])
    #expect(pieces.map(\.end) == [2, 3])
  }

  @Test func regionPiecesInSourceModeAreTheRegionItself() {
    let pieces = geometry(.source).pieces(forRegion: 1, end: 6)
    #expect(pieces.map(\.start) == [1])
    #expect(pieces.map(\.end) == [6])
  }

  @Test func regionInsideGapHasNoPiecesInCompressedMode() {
    #expect(geometry(.compressed).pieces(forRegion: 2.5, end: 4.5).isEmpty)
  }

  @Test func rulerLabelsUseCompressedDuration() {
    #expect(geometry(.compressed).rulerInterval(zoom: 1) == 1)
    #expect(geometry(.source).rulerInterval(zoom: 1) == 2)
    #expect(geometry(.source).rulerInterval(zoom: 4) == 1)
  }

  @Test func emptyTimelineIsSafeInBothModes() {
    let empty = TimelineGeometry(timeline: timeline([], duration: 0), width: 400, mode: .compressed)
    #expect(empty.x(forSource: 3) == 0)
    #expect(empty.sourceTime(forX: 100) == 0)
    #expect(empty.pieces(forRegion: 0, end: 1).isEmpty)
  }
}
