import Foundation
import Testing

@testable import AppShow

struct CutTimelineTests {
  private func slice(_ start: Double, _ end: Double) -> VideoRegionData {
    VideoRegionData(startSeconds: start, endSeconds: end)
  }

  private func timeline(_ ranges: [(Double, Double)], duration: Double = 10) -> CutTimeline {
    CutTimeline(slices: ranges.map { slice($0.0, $0.1) }, duration: duration)
  }

  @Test func splitInsideSliceProducesTwoAdjacentSlices() {
    var original = slice(0, 10)
    original.entryTransition = .fade
    original.entryTransitionDuration = 0.3
    original.exitTransition = .slide
    original.exitTransitionDuration = 0.4
    let result = CutTimeline(slices: [original], duration: 10).split(at: 4)
    #expect(result.slices.count == 2)
    #expect(result.slices[0].startSeconds == 0)
    #expect(result.slices[0].endSeconds == 4)
    #expect(result.slices[1].startSeconds == 4)
    #expect(result.slices[1].endSeconds == 10)
    #expect(result.slices[0].id == original.id)
    #expect(result.slices[1].id != original.id)
    #expect(result.slices[0].entryTransition == .fade)
    #expect(result.slices[0].entryTransitionDuration == 0.3)
    #expect(result.slices[0].exitTransition == nil)
    #expect(result.slices[1].entryTransition == nil)
    #expect(result.slices[1].exitTransition == .slide)
    #expect(result.slices[1].exitTransitionDuration == 0.4)
  }

  @Test func splitInGapIsNoOp() {
    let t = timeline([(0, 3), (6, 10)])
    #expect(t.split(at: 4.5) == t)
  }

  @Test func splitWithinMinLengthOfEdgeIsNoOp() {
    let t = timeline([(0, 10)])
    #expect(t.split(at: 0.03) == t)
    #expect(t.split(at: 9.97) == t)
  }

  @Test func splitAtExactBoundaryIsNoOp() {
    let t = timeline([(0, 4), (4, 10)])
    #expect(t.split(at: 4) == t)
  }

  @Test func removingMiddleRangeSplitsTheKeptSlice() {
    var original = slice(0, 10)
    original.entryTransition = .fade
    original.entryTransitionDuration = 0.3
    original.exitTransition = .slide
    original.exitTransitionDuration = 0.4

    let result = CutTimeline(slices: [original], duration: 10).removing(3...7)

    #expect(result.slices.count == 2)
    #expect(result.slices[0].startSeconds == 0)
    #expect(result.slices[0].endSeconds == 3)
    #expect(result.slices[1].startSeconds == 7)
    #expect(result.slices[1].endSeconds == 10)
    #expect(result.slices[0].id == original.id)
    #expect(result.slices[1].id != original.id)
    #expect(result.slices[0].entryTransition == .fade)
    #expect(result.slices[0].exitTransition == nil)
    #expect(result.slices[1].entryTransition == nil)
    #expect(result.slices[1].exitTransition == .slide)
  }

  @Test func removingRangeTrimsOrDropsEveryOverlappingSlice() {
    let result = timeline([(0, 2), (3, 5), (6, 8), (9, 10)]).removing(1...7)

    #expect(result.slices.map(\.startSeconds) == [0, 7, 9])
    #expect(result.slices.map(\.endSeconds) == [1, 8, 10])
  }

  @Test func removingRangeOutsideKeptSlicesIsNoOp() {
    let original = timeline([(0, 2), (5, 10)])
    #expect(original.removing(3...4) == original)
  }

  @Test func totalDurationSumsSlices() {
    #expect(timeline([(0, 2), (5, 7)]).totalDuration == 4)
  }

  @Test func hasCutsIsFalseForSingleFullRange() {
    let t = timeline([(0, 10)])
    #expect(!t.hasCuts)
    #expect(!t.isSplit)
    #expect(!t.showsTrack)
  }

  @Test func hasCutsIsTrueAfterSplitAndRemove() {
    var t = timeline([(0, 10)]).split(at: 4)
    t.slices.removeFirst()
    #expect(t.hasCuts)
    #expect(t.showsTrack)
  }

  @Test func isSplitIsTrueAfterSplitAlone() {
    let t = timeline([(0, 10)]).split(at: 4)
    #expect(t.isSplit)
    #expect(!t.hasCuts)
    #expect(t.showsTrack)
  }

  @Test func emptyTimelineHasNoCutsAndNoTrack() {
    let t = timeline([])
    #expect(!t.hasCuts)
    #expect(!t.showsTrack)
    #expect(t.totalDuration == 0)
  }

  @Test func elapsedForSourceInsideSecondSliceOffsetsByFirstSliceLength() {
    let t = timeline([(0, 2), (5, 7)])
    #expect(t.elapsed(forSource: 6) == 3)
    #expect(t.elapsed(forSource: 3) == 2)
    #expect(t.elapsed(forSource: 9) == 4)
    #expect(t.elapsed(forSource: 1) == 1)
  }

  @Test func sourceForElapsedMatchesExistingBehavior() {
    let t = timeline([(0, 2), (5, 7)])
    #expect(t.source(forElapsed: 3) == 6)
    #expect(t.source(forElapsed: 2) == 2)
    #expect(t.source(forElapsed: 99) == 7)
    #expect(timeline([]).source(forElapsed: 1) == 0)
  }

  @Test(arguments: [0.25, 0.5, 1.0, 1.75, 5.25, 6.0, 6.9])
  func sourceForElapsedIsInverseOfElapsedForSource(source: Double) {
    let t = timeline([(0, 2), (5, 7)])
    #expect(abs(t.source(forElapsed: t.elapsed(forSource: source)) - source) < 1e-9)
  }

  @Test func nextSliceStartAfterGapReturnsFollowingSlice() {
    let t = timeline([(0, 2), (5, 7)])
    #expect(t.nextSliceStart(after: 3) == 5)
    #expect(t.nextSliceStart(after: 1) == 5)
  }

  @Test func nextSliceStartAfterLastSliceIsNil() {
    #expect(timeline([(0, 2), (5, 7)]).nextSliceStart(after: 7) == nil)
  }

  @Test func normalizedSortsClampsDropsShortAndMergesOverlaps() {
    let t = timeline([(8, 12), (-1, 3), (2, 5), (6, 6.01)], duration: 10).normalized()
    #expect(t.slices.map(\.startSeconds) == [0, 8])
    #expect(t.slices.map(\.endSeconds) == [5, 10])
  }

  @Test func normalizedKeepsTouchingSlicesSeparate() {
    let t = timeline([(4, 10), (0, 4)]).normalized()
    #expect(t.slices.map(\.startSeconds) == [0, 4])
    #expect(t.slices.map(\.endSeconds) == [4, 10])
  }

  @Test func gapsBetweenSlicesCoverUncoveredSource() {
    let gaps = timeline([(0, 2), (5, 7)]).gaps
    #expect(gaps == [2...5, 7...10])
    #expect(timeline([(0, 10)]).gaps.isEmpty)
  }

  @Test func canCutAtIsFalseInGapAndNearEdges() {
    let t = timeline([(0, 2), (5, 7)])
    #expect(!t.canCut(at: 3))
    #expect(!t.canCut(at: 0.02))
    #expect(!t.canCut(at: 6.98))
    #expect(!t.canCut(at: 5))
  }

  @Test func canCutAtIsTrueInsideSlice() {
    let t = timeline([(0, 2), (5, 7)])
    #expect(t.canCut(at: 1))
    #expect(t.canCut(at: 6))
  }

  @Test func sliceEndBoundaryTimesAreSliceEndsExceptLast() {
    #expect(timeline([(0, 2), (5, 7), (8, 10)]).boundaryTimes == [2, 7])
    #expect(timeline([(0, 10)]).boundaryTimes.isEmpty)
  }

  @Test func sliceContainingUsesInclusiveEdges() {
    let t = timeline([(0, 2), (5, 7)])
    #expect(t.slice(containing: 2)?.startSeconds == 0)
    #expect(t.slice(containing: 5)?.startSeconds == 5)
    #expect(t.slice(containing: 3) == nil)
  }
}
