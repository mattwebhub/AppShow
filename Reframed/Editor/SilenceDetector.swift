import Foundation

struct SilenceDetectorConfig: Sendable, Equatable {
  var thresholdDb: Double = -40
  var minimumSilence: Double = 0.7
  var padding: Double = 0.15
  var windowSeconds: Double = 0.02

  var thresholdGain: Float {
    Float(pow(10.0, thresholdDb / 20.0))
  }
}

struct RmsWindowAccumulator: Sendable {
  let windowFrames: Int
  let windowDuration: Double
  private var sumOfSquares: Double = 0
  private var frameCount = 0
  private var windows: [Float] = []

  init(sampleRate: Double, windowSeconds: Double) {
    windowFrames = max(1, Int((windowSeconds * sampleRate).rounded()))
    windowDuration = Double(windowFrames) / sampleRate
  }

  mutating func append(_ value: Float) {
    sumOfSquares += Double(value) * Double(value)
    frameCount += 1
    if frameCount == windowFrames {
      flush()
    }
  }

  mutating func finish() -> [Float] {
    if frameCount > 0 {
      flush()
    }
    return windows
  }

  private mutating func flush() {
    windows.append(Float((sumOfSquares / Double(frameCount)).squareRoot()))
    sumOfSquares = 0
    frameCount = 0
  }
}

enum SilenceDetector {
  private static let lengthTolerance = 1e-9

  nonisolated static func rmsWindows(samples: [Float], sampleRate: Double, windowSeconds: Double) -> [Float] {
    var accumulator = RmsWindowAccumulator(sampleRate: sampleRate, windowSeconds: windowSeconds)
    for sample in samples {
      accumulator.append(sample)
    }
    return accumulator.finish()
  }

  nonisolated static func silentSpans(
    rms windows: [Float],
    windowDuration: Double,
    config: SilenceDetectorConfig
  ) -> [ClosedRange<Double>] {
    guard let peak = windows.max() else { return [] }
    let threshold = peak * config.thresholdGain
    var spans: [ClosedRange<Double>] = []
    var runStart: Int?

    func close(_ start: Int, at end: Int) {
      let lower = Double(start) * windowDuration
      let upper = Double(end) * windowDuration
      if upper - lower + lengthTolerance >= config.minimumSilence {
        spans.append(lower...upper)
      }
    }

    for (index, value) in windows.enumerated() {
      let silent = peak == 0 || value < threshold
      if silent {
        if runStart == nil { runStart = index }
      } else if let start = runStart {
        close(start, at: index)
        runStart = nil
      }
    }
    if let start = runStart {
      close(start, at: windows.count)
    }
    return spans
  }

  static func keepSlices(
    duration: Double,
    silences: [ClosedRange<Double>],
    config: SilenceDetectorConfig
  ) -> [VideoRegionData] {
    guard duration > 0 else { return [] }
    var slices: [VideoRegionData] = []
    var cursor = 0.0
    for silence in silences.sorted(by: { $0.lowerBound < $1.lowerBound }) {
      let touchesStart = silence.lowerBound <= config.padding
      let touchesEnd = silence.upperBound >= duration - config.padding
      let start = touchesStart ? 0 : silence.lowerBound + config.padding
      let end = touchesEnd ? duration : silence.upperBound - config.padding
      guard end > start else { continue }
      if start > cursor {
        slices.append(VideoRegionData(startSeconds: cursor, endSeconds: start))
      }
      cursor = max(cursor, end)
    }
    if cursor < duration {
      slices.append(VideoRegionData(startSeconds: cursor, endSeconds: duration))
    }
    return CutTimeline(slices: slices, duration: duration).normalized().slices
  }

  static func intersect(existing: CutTimeline, keep: [VideoRegionData]) -> CutTimeline {
    let kept = keep.sorted { $0.startSeconds < $1.startSeconds }
    var slices: [VideoRegionData] = []
    for slice in existing.slices {
      var pieces = kept.compactMap { range -> VideoRegionData? in
        let start = max(slice.startSeconds, range.startSeconds)
        let end = min(slice.endSeconds, range.endSeconds)
        guard end - start >= CutTimeline.minSliceLength else { return nil }
        return VideoRegionData(startSeconds: start, endSeconds: end)
      }
      guard !pieces.isEmpty else { continue }
      pieces[0].id = slice.id
      pieces[0].entryTransition = slice.entryTransition
      pieces[0].entryTransitionDuration = slice.entryTransitionDuration
      pieces[pieces.count - 1].exitTransition = slice.exitTransition
      pieces[pieces.count - 1].exitTransitionDuration = slice.exitTransitionDuration
      slices.append(contentsOf: pieces)
    }
    return CutTimeline(slices: slices, duration: existing.duration).normalized()
  }
}
