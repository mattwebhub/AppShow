import Foundation
import Testing

@testable import AppShow

struct SpeedTimelineTests {
  @Test(arguments: [1.5, 2.0, 4.0, 8.0, 16.0, 32.0])
  func speedsShortenOnlyTheirSelectedRange(rate: Double) {
    let timeline = SpeedTimeline(duration: 10, regions: [SpeedRegionData(startSeconds: 2, endSeconds: 6, rate: rate)])
    #expect(abs(timeline.totalDuration - (6 + 4 / rate)) < 0.00001)
    #expect(timeline.rate(at: 1) == 1)
    #expect(timeline.rate(at: 2) == rate)
    #expect(timeline.rate(at: 6) == 1)
    for source in [0.0, 1, 2, 3, 5, 6, 9, 10] {
      #expect(abs(timeline.source(forElapsed: timeline.elapsed(forSource: source)) - source) < 0.00001)
    }
  }

  @Test func normalSpeedContentAdvancesOnOutputClockAcrossCutsAndTrim() {
    let map = SpeedTimeline(
      duration: 10,
      regions: [SpeedRegionData(startSeconds: 2, endSeconds: 8, rate: 4)],
      slices: [VideoRegionData(startSeconds: 1, endSeconds: 4), VideoRegionData(startSeconds: 6, endSeconds: 9)]
    )
    #expect(map.normalSpeedSource(forSource: 2) == 2)
    #expect(map.normalSpeedSource(forSource: 6) == 2.5)
    #expect(map.normalSpeedSource(forSource: 8) == 3)
    #expect(map.normalSpeedSource(forSource: 9) == 6)
  }

  @Test func cutsTrimAndSpeedShareOneOutputClock() {
    let timeline = SpeedTimeline(
      duration: 10,
      regions: [SpeedRegionData(startSeconds: 2, endSeconds: 8, rate: 4)],
      slices: [VideoRegionData(startSeconds: 1, endSeconds: 4), VideoRegionData(startSeconds: 6, endSeconds: 9)]
    )
    #expect(timeline.totalDuration == 3)
    #expect(timeline.elapsed(forSource: 5) == 1.5)
    #expect(timeline.source(forElapsed: 1.5) == 6)
    #expect(timeline.elapsed(forSource: 8) == 2)
    #expect(timeline.source(forElapsed: 2.5) == 8.5)
  }

  @Test func subtitlesFollowSpeedCutsAndTrim() {
    let map = SpeedTimeline(
      duration: 10,
      regions: [SpeedRegionData(startSeconds: 2, endSeconds: 8, rate: 4)],
      slices: [VideoRegionData(startSeconds: 1, endSeconds: 4), VideoRegionData(startSeconds: 6, endSeconds: 9)]
    )
    let captions = map.remapCaptions([
      CaptionSegment(startSeconds: 0, endSeconds: 2, text: "Intro"),
      CaptionSegment(startSeconds: 3, endSeconds: 7, text: "Across the cut"),
      CaptionSegment(startSeconds: 4.5, endSeconds: 5.5, text: "Deleted"),
    ])
    #expect(captions.map(\.text) == ["Intro", "Across the cut"])
    #expect(captions[0].startSeconds == 0 && captions[0].endSeconds == 1)
    #expect(captions[1].startSeconds == 1.25 && captions[1].endSeconds == 1.75)
  }

  @Test func regionsValidateAndPersist() throws {
    let region = SpeedRegionData(startSeconds: 1, endSeconds: 5, rate: 32)
    #expect(try JSONDecoder().decode(SpeedRegionData.self, from: JSONEncoder().encode(region)) == region)
    #expect(region.isValid(duration: 10))
    #expect(!SpeedRegionData(startSeconds: -1, endSeconds: 5, rate: 2).isValid(duration: 10))
    #expect(!SpeedRegionData(startSeconds: 1, endSeconds: 5, rate: 3).isValid(duration: 10))
    #expect(!SpeedRegionData(startSeconds: 1, endSeconds: 11, rate: 2).isValid(duration: 10))
  }

  @Test func compressedGeometryUsesSpeedAndRemainsEditableInSourceTime() {
    let cuts = CutTimeline(slices: [VideoRegionData(startSeconds: 0, endSeconds: 10)], duration: 10)
    let geometry = TimelineGeometry(
      timeline: cuts,
      width: 800,
      mode: .compressed,
      speedRegions: [SpeedRegionData(startSeconds: 2, endSeconds: 6, rate: 2)]
    )
    #expect(geometry.visibleDuration == 8)
    #expect(geometry.x(forSource: 6) == 400)
    #expect(geometry.sourceTime(forX: 300) == 4)
  }
}
