import CoreMedia
import Testing

@testable import AppShow

struct EditorStateExportTests {
  private func region(_ start: Double, _ end: Double) -> VideoRegionData {
    VideoRegionData(startSeconds: start, endSeconds: end)
  }

  @Test func exportConfigOmitsVideoRegionsForSingleFullSlice() {
    let result = EditorState.exportVideoRegions(from: [region(0, 10)], trimStart: 0, trimEnd: 10)
    #expect(result.isEmpty)
  }

  @Test func exportConfigEmitsAllSlicesAndFullTrimWhenCut() {
    let result = EditorState.exportVideoRegions(from: [region(0, 2), region(5, 7)], trimStart: 0, trimEnd: 10)
    #expect(result.count == 2)
    #expect(result[0].timeRange.start.seconds == 0)
    #expect(result[0].timeRange.end.seconds == 2)
    #expect(result[1].timeRange.start.seconds == 5)
    #expect(result[1].timeRange.end.seconds == 7)
    let trim = EditorState.exportTrimRange(
      videoRegions: result,
      trimStart: .zero,
      trimEnd: CMTime(seconds: 10, preferredTimescale: 600),
      duration: CMTime(seconds: 12, preferredTimescale: 600)
    )
    #expect(trim.start == .zero)
    #expect(trim.end.seconds == 12)
  }

  @Test func exportConfigKeepsSingleSliceWithTransition() {
    var slice = region(0, 10)
    slice.entryTransition = .fade
    let result = EditorState.exportVideoRegions(from: [slice], trimStart: 0, trimEnd: 10)
    #expect(result.count == 1)
    #expect(result[0].entryTransition == .fade)
    #expect(result[0].entryDuration == 0.3)
  }

  @Test func exportTrimRangeUsesTrimWhenNoRegions() {
    let trim = EditorState.exportTrimRange(
      videoRegions: [],
      trimStart: CMTime(seconds: 1, preferredTimescale: 600),
      trimEnd: CMTime(seconds: 9, preferredTimescale: 600),
      duration: CMTime(seconds: 12, preferredTimescale: 600)
    )
    #expect(trim.start.seconds == 1)
    #expect(trim.end.seconds == 9)
  }
}
