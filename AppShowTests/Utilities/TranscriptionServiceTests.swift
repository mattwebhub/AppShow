import Foundation
import Testing

@testable import AppShow

struct TranscriptionServiceTests {
  private func segment(_ start: Double, _ end: Double, _ text: String, words: [CaptionWord]? = nil) -> CaptionSegment {
    CaptionSegment(startSeconds: start, endSeconds: end, text: text, words: words)
  }

  private func words(_ count: Int) -> String {
    (1...count).map { "w\($0)" }.joined(separator: " ")
  }

  @Test func shortSegmentIsMergedIntoAShortPredecessorWithinOneAndAHalfSeconds() {
    let first = segment(0, 1, "one two three")
    let second = segment(1.5, 2.5, "four five")
    let merged = TranscriptionService.mergeShortSegments([first, second])
    #expect(merged.count == 1)
    #expect(merged[0].id == first.id)
    #expect(merged[0].startSeconds == 0)
    #expect(merged[0].endSeconds == 2.5)
    #expect(merged[0].text == "one two three four five")
    #expect(merged[0].words == nil)
  }

  @Test func shortSegmentIsMergedIntoALongPredecessor() {
    let merged = TranscriptionService.mergeShortSegments([segment(0, 2, words(10)), segment(2.5, 3, "tail")])
    #expect(merged.count == 1)
    #expect(merged[0].text == words(10) + " tail")
  }

  @Test func longSegmentIsMergedIntoAShortPredecessor() {
    let merged = TranscriptionService.mergeShortSegments([segment(0, 1, "hi"), segment(1.5, 4, words(8))])
    #expect(merged.count == 1)
    #expect(merged[0].text == "hi " + words(8))
  }

  @Test func twoSegmentsOfFourOrMoreWordsAreNotMerged() {
    let merged = TranscriptionService.mergeShortSegments([segment(0, 1, words(4)), segment(1.1, 2, words(4))])
    #expect(merged.count == 2)
  }

  @Test func mergeStopsAtSixteenWords() {
    let sixteen = TranscriptionService.mergeShortSegments([segment(0, 1, words(14)), segment(1.5, 2.5, "a b")])
    #expect(sixteen.count == 1)
    #expect(sixteen[0].text.split(separator: " ").count == 16)
    let seventeen = TranscriptionService.mergeShortSegments([segment(0, 1, words(15)), segment(1.5, 2.5, "a b")])
    #expect(seventeen.count == 2)
  }

  @Test func gapOfOneAndAHalfSecondsOrMorePreventsMerging() {
    let merged = TranscriptionService.mergeShortSegments([segment(0, 1, "one two"), segment(2.5, 3, "three")])
    #expect(merged.count == 2)
    let close = TranscriptionService.mergeShortSegments([segment(0, 1, "one two"), segment(2.4, 3, "three")])
    #expect(close.count == 1)
  }

  @Test func overlappingSegmentsAreNotMerged() {
    let merged = TranscriptionService.mergeShortSegments([segment(0, 1, "one two"), segment(0.9, 2, "three")])
    #expect(merged.count == 2)
  }

  @Test func mergedSegmentKeepsTheLaterEndTime() {
    let merged = TranscriptionService.mergeShortSegments([segment(0, 3, "one two"), segment(3.5, 3.6, "three")])
    #expect(merged[0].endSeconds == 3.6)
    let contained = TranscriptionService.mergeShortSegments([segment(0, 3, "one two"), segment(3, 2.5, "three")])
    #expect(contained[0].endSeconds == 3)
  }

  @Test func wordTimingsAreConcatenatedWhenBothSegmentsHaveThem() {
    let first = segment(
      0,
      1,
      "one two",
      words: [CaptionWord(word: "one", startSeconds: 0, endSeconds: 0.5), CaptionWord(word: "two", startSeconds: 0.5, endSeconds: 1)]
    )
    let second = segment(1.2, 2, "three", words: [CaptionWord(word: "three", startSeconds: 1.2, endSeconds: 2)])
    let merged = TranscriptionService.mergeShortSegments([first, second])
    #expect(merged[0].words?.map(\.word) == ["one", "two", "three"])
  }

  @Test func wordTimingsAreDroppedWhenEitherSegmentLacksThem() {
    let withWords = segment(0, 1, "one two", words: [CaptionWord(word: "one", startSeconds: 0, endSeconds: 1)])
    let merged = TranscriptionService.mergeShortSegments([withWords, segment(1.2, 2, "three")])
    #expect(merged[0].words == nil)
  }

  @Test func chainOfShortSegmentsAccumulatesIntoOne() {
    let merged = TranscriptionService.mergeShortSegments([
      segment(0, 1, "a"), segment(1.2, 2, "b"), segment(2.2, 3, "c"), segment(3.2, 4, "d"),
    ])
    #expect(merged.count == 1)
    #expect(merged[0].text == "a b c d")
    #expect(merged[0].endSeconds == 4)
  }

  @Test func segmentsAreSortedByStartBeforeMerging() {
    let merged = TranscriptionService.mergeShortSegments([segment(1.5, 2.5, "four five"), segment(0, 1, "one two three")])
    #expect(merged.count == 1)
    #expect(merged[0].text == "one two three four five")
  }

  @Test func zeroOrOneSegmentsAreReturnedVerbatim() {
    #expect(TranscriptionService.mergeShortSegments([]).isEmpty)
    let single = segment(0, 1, "a")
    #expect(TranscriptionService.mergeShortSegments([single]) == [single])
  }

  @Test func specialTokensAreStripped() {
    let cleaned = TranscriptionService.stripSpecialTokens("<|startoftranscript|><|en|> Hello there<|endoftext|>")
    #expect(cleaned == " Hello there")
  }

  @Test func textWithoutTokensIsUnchanged() {
    #expect(TranscriptionService.stripSpecialTokens("plain <text> | with bars") == "plain <text> | with bars")
    #expect(TranscriptionService.stripSpecialTokens("") == "")
  }

  @Test func emptyOrNestedTokensAreNotStripped() {
    #expect(TranscriptionService.stripSpecialTokens("<||>") == "<||>")
    #expect(TranscriptionService.stripSpecialTokens("<|a|b|>") == "<|a|b|>")
  }
}
