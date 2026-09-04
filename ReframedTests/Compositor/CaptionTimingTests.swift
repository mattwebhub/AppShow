import Testing

@testable import Reframed

struct CaptionTimingTests {
  private func segment(_ start: Double, _ end: Double, _ text: String) -> CaptionSegment {
    CaptionSegment(startSeconds: start, endSeconds: end, text: text)
  }

  private var twoSegments: [CaptionSegment] {
    [segment(1, 2, "first"), segment(3, 4, "second")]
  }

  @Test func activeSegmentIsReturnedWhileTimeIsInsideIt() {
    #expect(FrameRenderer.captionSegmentAt(time: 1, in: twoSegments)?.text == "first")
    #expect(FrameRenderer.captionSegmentAt(time: 1.5, in: twoSegments)?.text == "first")
    #expect(FrameRenderer.captionSegmentAt(time: 3.999, in: twoSegments)?.text == "second")
  }

  @Test func nothingIsShownBeforeTheFirstSegment() {
    #expect(FrameRenderer.captionSegmentAt(time: 0.5, in: twoSegments) == nil)
  }

  @Test func emptySegmentsYieldNothing() {
    #expect(FrameRenderer.captionSegmentAt(time: 1, in: []) == nil)
  }

  @Test func previousSegmentLingersForLessThanOneAndAHalfSeconds() {
    #expect(FrameRenderer.captionSegmentAt(time: 2, in: twoSegments)?.text == "first")
    #expect(FrameRenderer.captionSegmentAt(time: 2.9, in: twoSegments)?.text == "first")
    #expect(FrameRenderer.captionSegmentAt(time: 5.4, in: twoSegments)?.text == "second")
    #expect(FrameRenderer.captionSegmentAt(time: 5.5, in: twoSegments) == nil)
    #expect(FrameRenderer.captionSegmentAt(time: 9, in: twoSegments) == nil)
  }

  @Test func lingerEndsWhenTheNextSegmentStarts() {
    let segments = [segment(1, 2, "first"), segment(2.5, 3.5, "second")]
    #expect(FrameRenderer.captionSegmentAt(time: 2.4, in: segments)?.text == "first")
    #expect(FrameRenderer.captionSegmentAt(time: 2.5, in: segments)?.text == "second")
  }

  @Test func lingerDoesNotBridgeAGapLongerThanOneAndAHalfSeconds() {
    let segments = [segment(1, 2, "first"), segment(5, 6, "second")]
    #expect(FrameRenderer.captionSegmentAt(time: 3.4, in: segments)?.text == "first")
    #expect(FrameRenderer.captionSegmentAt(time: 3.5, in: segments) == nil)
    #expect(FrameRenderer.captionSegmentAt(time: 4.9, in: segments) == nil)
  }

  @Test func overlappingSegmentsResolveToTheFirstInArrayOrder() {
    let segments = [segment(1, 3, "first"), segment(2, 4, "second")]
    #expect(FrameRenderer.captionSegmentAt(time: 2.5, in: segments)?.text == "first")
  }

  @Test func shortTextIsReturnedOnOneLine() {
    let text = FrameRenderer.visibleText(for: segment(0, 2, "one two three"), at: 1, maxWordsPerLine: 3)
    #expect(text == "one two three")
  }

  @Test func repeatedSpacesAreCollapsed() {
    let text = FrameRenderer.visibleText(for: segment(0, 2, "one  two   three"), at: 1, maxWordsPerLine: 6)
    #expect(text == "one two three")
  }

  @Test func textWithoutWordsIsReturnedVerbatim() {
    #expect(FrameRenderer.visibleText(for: segment(0, 2, ""), at: 1, maxWordsPerLine: 3) == "")
    #expect(FrameRenderer.visibleText(for: segment(0, 2, "   "), at: 1, maxWordsPerLine: 3) == "   ")
  }

  @Test func textUpToTwoLinesIsShownForTheWholeSegment() {
    let seg = segment(0, 4, "w1 w2 w3 w4")
    #expect(FrameRenderer.visibleText(for: seg, at: 0, maxWordsPerLine: 2) == "w1 w2\nw3 w4")
    #expect(FrameRenderer.visibleText(for: seg, at: 3.9, maxWordsPerLine: 2) == "w1 w2\nw3 w4")
  }

  @Test func longerTextIsWindowedTwoLinesAtATimeAcrossTheSegment() {
    let seg = segment(10, 14, "w1 w2 w3 w4 w5")
    #expect(FrameRenderer.visibleText(for: seg, at: 10, maxWordsPerLine: 2) == "w1 w2\nw3 w4")
    #expect(FrameRenderer.visibleText(for: seg, at: 11.9, maxWordsPerLine: 2) == "w1 w2\nw3 w4")
    #expect(FrameRenderer.visibleText(for: seg, at: 12, maxWordsPerLine: 2) == "w5")
    #expect(FrameRenderer.visibleText(for: seg, at: 13.9, maxWordsPerLine: 2) == "w5")
  }

  @Test func threeWindowsSplitTheSegmentEvenly() {
    let seg = segment(0, 6, "w1 w2 w3 w4 w5 w6")
    #expect(FrameRenderer.visibleText(for: seg, at: 0, maxWordsPerLine: 1) == "w1\nw2")
    #expect(FrameRenderer.visibleText(for: seg, at: 2, maxWordsPerLine: 1) == "w3\nw4")
    #expect(FrameRenderer.visibleText(for: seg, at: 4, maxWordsPerLine: 1) == "w5\nw6")
  }

  @Test func timeAfterTheSegmentShowsTheLastWindow() {
    let seg = segment(0, 4, "w1 w2 w3 w4 w5")
    #expect(FrameRenderer.visibleText(for: seg, at: 5, maxWordsPerLine: 2) == "w5")
    #expect(FrameRenderer.visibleText(for: seg, at: 100, maxWordsPerLine: 2) == "w5")
  }

  @Test func zeroDurationSegmentShowsTheFirstTwoLines() {
    let seg = segment(3, 3, "w1 w2 w3 w4 w5 w6")
    #expect(FrameRenderer.visibleText(for: seg, at: 3, maxWordsPerLine: 2) == "w1 w2\nw3 w4")
    let negative = segment(3, 2, "w1 w2 w3 w4 w5 w6")
    #expect(FrameRenderer.visibleText(for: negative, at: 3, maxWordsPerLine: 2) == "w1 w2\nw3 w4")
  }
}
