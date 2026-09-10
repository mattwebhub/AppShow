import Foundation
import Testing

@testable import Reframed

struct SilenceDetectorTests {
  private let windowDuration = 0.02
  private let loud: Float = 0.5
  private let quiet: Float = 0.001

  private func windows(duration: Double = 10, silences: [ClosedRange<Double>], level: Float? = nil) -> [Float] {
    let count = Int((duration / windowDuration).rounded())
    return (0..<count).map { index in
      let time = (Double(index) + 0.5) * windowDuration
      let silent = silences.contains { $0.contains(time) }
      return silent ? (level ?? quiet) : loud
    }
  }

  private func near(_ range: ClosedRange<Double>, _ lower: Double, _ upper: Double, tolerance: Double = 0.02) -> Bool {
    abs(range.lowerBound - lower) <= tolerance && abs(range.upperBound - upper) <= tolerance
  }

  private func near(_ slice: VideoRegionData, _ start: Double, _ end: Double, tolerance: Double = 0.001) -> Bool {
    abs(slice.startSeconds - start) <= tolerance && abs(slice.endSeconds - end) <= tolerance
  }

  private func slice(_ start: Double, _ end: Double) -> VideoRegionData {
    VideoRegionData(startSeconds: start, endSeconds: end)
  }

  @Test func rmsWindowsAverageEachWindow() {
    let result = SilenceDetector.rmsWindows(samples: [3, 4, 0, 0, 2], sampleRate: 100, windowSeconds: 0.02)
    #expect(result.count == 3)
    #expect(abs(result[0] - 3.5355) < 0.001)
    #expect(result[1] == 0)
    #expect(result[2] == 2)
  }

  @Test func rmsWindowsOfEmptyInputIsEmpty() {
    #expect(SilenceDetector.rmsWindows(samples: [], sampleRate: 48_000, windowSeconds: 0.02).isEmpty)
  }

  @Test func silentSpansFindGapsBelowRelativeThreshold() {
    let spans = SilenceDetector.silentSpans(
      rms: windows(silences: [3...5, 8...10]),
      windowDuration: windowDuration,
      config: SilenceDetectorConfig()
    )
    #expect(spans.count == 2)
    #expect(near(spans[0], 3, 5))
    #expect(near(spans[1], 8, 10))
  }

  @Test func silentSpansIgnoreGapsShorterThanMinimum() {
    let spans = SilenceDetector.silentSpans(
      rms: windows(silences: [1...1.5, 3...5, 8...10]),
      windowDuration: windowDuration,
      config: SilenceDetectorConfig(minimumSilence: 1.0)
    )
    #expect(spans.count == 2)
    #expect(near(spans[0], 3, 5))
    #expect(near(spans[1], 8, 10))
  }

  @Test func silentSpansAcceptGapsExactlyAtMinimum() {
    let spans = SilenceDetector.silentSpans(
      rms: windows(silences: [3...3.7]),
      windowDuration: windowDuration,
      config: SilenceDetectorConfig()
    )
    #expect(spans.count == 1)
    #expect(near(spans[0], 3, 3.7))
  }

  @Test func thresholdIsRelativeToPeakNotAbsolute() {
    let quietRecording = windows(silences: [3...5, 8...10]).map { $0 * 0.1 }
    let spans = SilenceDetector.silentSpans(
      rms: quietRecording,
      windowDuration: windowDuration,
      config: SilenceDetectorConfig()
    )
    #expect(spans.count == 2)
    #expect(near(spans[0], 3, 5))
    #expect(near(spans[1], 8, 10))

    let shallowDips = windows(silences: [3...5, 8...10], level: loud * 0.0316)
    let none = SilenceDetector.silentSpans(
      rms: shallowDips,
      windowDuration: windowDuration,
      config: SilenceDetectorConfig()
    )
    #expect(none.isEmpty)
    let loosened = SilenceDetector.silentSpans(
      rms: shallowDips,
      windowDuration: windowDuration,
      config: SilenceDetectorConfig(thresholdDb: -20)
    )
    #expect(loosened.count == 2)
  }

  @Test func allSilentSignalIsOneSpan() {
    let spans = SilenceDetector.silentSpans(
      rms: [Float](repeating: 0, count: 500),
      windowDuration: windowDuration,
      config: SilenceDetectorConfig()
    )
    #expect(spans.count == 1)
    #expect(near(spans[0], 0, 10))
  }

  @Test func allLoudSignalHasNoSpans() {
    let spans = SilenceDetector.silentSpans(
      rms: windows(silences: []),
      windowDuration: windowDuration,
      config: SilenceDetectorConfig()
    )
    #expect(spans.isEmpty)
  }

  @Test func emptyWindowsHaveNoSpans() {
    #expect(SilenceDetector.silentSpans(rms: [], windowDuration: windowDuration, config: SilenceDetectorConfig()).isEmpty)
  }

  @Test func keepSlicesPadSpeechEdges() {
    let slices = SilenceDetector.keepSlices(duration: 10, silences: [3...5], config: SilenceDetectorConfig())
    #expect(slices.count == 2)
    #expect(near(slices[0], 0, 3.15))
    #expect(near(slices[1], 4.85, 10))
  }

  @Test func keepSlicesKeepRecordingEdgesUnpadded() {
    let tail = SilenceDetector.keepSlices(duration: 10, silences: [8...10], config: SilenceDetectorConfig())
    #expect(tail.count == 1)
    #expect(near(tail[0], 0, 8.15))

    let head = SilenceDetector.keepSlices(duration: 10, silences: [0...2], config: SilenceDetectorConfig())
    #expect(head.count == 1)
    #expect(near(head[0], 1.85, 10))
  }

  @Test func keepSlicesDropSlicesShorterThanMinimum() {
    let slices = SilenceDetector.keepSlices(
      duration: 10,
      silences: [3...5, 5.03...7],
      config: SilenceDetectorConfig(padding: 0)
    )
    #expect(slices.count == 2)
    #expect(near(slices[0], 0, 3))
    #expect(near(slices[1], 7, 10))
  }

  @Test func keepSlicesDropSilencesSwallowedByPadding() {
    let slices = SilenceDetector.keepSlices(duration: 10, silences: [3...3.2], config: SilenceDetectorConfig())
    #expect(slices.count == 1)
    #expect(near(slices[0], 0, 10))
  }

  @Test func keepSlicesFromNoSilencesIsOneFullSlice() {
    let slices = SilenceDetector.keepSlices(duration: 10, silences: [], config: SilenceDetectorConfig())
    #expect(slices.count == 1)
    #expect(near(slices[0], 0, 10))
  }

  @Test func keepSlicesFromAllSilentIsEmpty() {
    let slices = SilenceDetector.keepSlices(duration: 10, silences: [0...10], config: SilenceDetectorConfig())
    #expect(slices.isEmpty)
  }

  @Test func intersectKeepsExistingCutsAndSplitsAroundSilences() {
    let existing = CutTimeline(slices: [slice(0, 4), slice(6, 10)], duration: 10)
    let result = SilenceDetector.intersect(existing: existing, keep: [slice(0, 3.15), slice(4.85, 10)])
    #expect(result.duration == 10)
    #expect(result.slices.count == 2)
    #expect(near(result.slices[0], 0, 3.15))
    #expect(near(result.slices[1], 6, 10))
  }

  @Test func intersectWithFullKeepLeavesExistingUntouched() {
    let existing = CutTimeline(slices: [slice(0, 4), slice(6, 10)], duration: 10)
    let result = SilenceDetector.intersect(existing: existing, keep: [slice(0, 10)])
    #expect(result == existing)
  }

  @Test func intersectPreservesTransitionsOnOuterPieces() {
    var original = slice(0, 10)
    original.entryTransition = .fade
    original.entryTransitionDuration = 0.3
    original.exitTransition = .slide
    original.exitTransitionDuration = 0.4
    let existing = CutTimeline(slices: [original], duration: 10)
    let result = SilenceDetector.intersect(existing: existing, keep: [slice(0, 3.15), slice(4.85, 8.15)])
    #expect(result.slices.count == 2)
    #expect(result.slices[0].id == original.id)
    #expect(result.slices[0].entryTransition == .fade)
    #expect(result.slices[0].entryTransitionDuration == 0.3)
    #expect(result.slices[0].exitTransition == nil)
    #expect(result.slices[1].id != original.id)
    #expect(result.slices[1].entryTransition == nil)
    #expect(result.slices[1].exitTransition == .slide)
    #expect(result.slices[1].exitTransitionDuration == 0.4)
  }

  @Test func intersectDropsPiecesShorterThanMinimum() {
    let existing = CutTimeline(slices: [slice(0, 10)], duration: 10)
    let result = SilenceDetector.intersect(existing: existing, keep: [slice(0, 0.03), slice(4, 10)])
    #expect(result.slices.count == 1)
    #expect(near(result.slices[0], 4, 10))
  }
}
