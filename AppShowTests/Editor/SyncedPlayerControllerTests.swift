import Testing

@testable import AppShow

struct SyncedPlayerControllerTests {
  private let slices: [(start: Double, end: Double)] = [(0, 2), (5, 7)]

  @Test func gapSkipDecisionInsideSliceIsNone() {
    #expect(SyncedPlayerController.gapSkipDecision(at: 1, slices: slices) == .none)
    #expect(SyncedPlayerController.gapSkipDecision(at: 5, slices: slices) == .none)
  }

  @Test func gapSkipDecisionInGapSeeksToNextSlice() {
    #expect(SyncedPlayerController.gapSkipDecision(at: 3, slices: slices) == .seek(5))
    #expect(SyncedPlayerController.gapSkipDecision(at: 2, slices: slices) == .seek(5))
  }

  @Test func gapSkipDecisionAfterLastSliceIsPause() {
    #expect(SyncedPlayerController.gapSkipDecision(at: 7, slices: slices) == .pause)
    #expect(SyncedPlayerController.gapSkipDecision(at: 9, slices: slices) == .pause)
  }

  @Test func gapSkipDecisionWithoutSlicesIsNone() {
    #expect(SyncedPlayerController.gapSkipDecision(at: 3, slices: []) == .none)
  }
}
