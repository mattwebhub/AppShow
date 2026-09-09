import Foundation

struct SpeedTimeline: Sendable, Equatable {
  struct Segment: Sendable, Equatable {
    let sourceStart: Double
    let sourceEnd: Double
    let outputStart: Double
    let rate: Double
    var outputEnd: Double { outputStart + (sourceEnd - sourceStart) / rate }
  }

  let segments: [Segment]
  var totalDuration: Double { segments.last?.outputEnd ?? 0 }

  init(duration: Double, regions: [SpeedRegionData], slices: [VideoRegionData]? = nil) {
    let valid = regions.filter {
      $0.startSeconds.isFinite && $0.endSeconds.isFinite && $0.startSeconds >= 0 && $0.endSeconds <= duration
        && $0.endSeconds > $0.startSeconds && SpeedPreset(rawValue: $0.rate) != nil
    }.sorted { $0.startSeconds < $1.startSeconds }
    let kept = (slices ?? [VideoRegionData(startSeconds: 0, endSeconds: duration)]).filter { $0.endSeconds > $0.startSeconds }.sorted {
      $0.startSeconds < $1.startSeconds
    }
    var output = 0.0
    var result: [Segment] = []
    for slice in kept {
      let boundaries = Set(
        [slice.startSeconds, slice.endSeconds]
          + valid.flatMap { [$0.startSeconds, $0.endSeconds] }
          .filter { $0 > slice.startSeconds && $0 < slice.endSeconds }
      ).sorted()
      for (a, b) in zip(boundaries, boundaries.dropFirst()) {
        let rate = valid.first { a >= $0.startSeconds && a < $0.endSeconds }?.rate ?? 1
        let segment = Segment(sourceStart: a, sourceEnd: b, outputStart: output, rate: rate)
        result.append(segment)
        output = segment.outputEnd
      }
    }
    segments = result
  }

  func rate(at source: Double) -> Double {
    segments.first { source >= $0.sourceStart && source < $0.sourceEnd }?.rate ?? 1
  }

  func elapsed(forSource source: Double) -> Double {
    for segment in segments {
      if source < segment.sourceEnd {
        return segment.outputStart + max(0, source - segment.sourceStart) / segment.rate
      }
    }
    return totalDuration
  }

  func source(forElapsed elapsed: Double) -> Double {
    for segment in segments where elapsed < segment.outputEnd {
      return segment.sourceStart + max(0, elapsed - segment.outputStart) * segment.rate
    }
    return segments.last?.sourceEnd ?? 0
  }

  func normalSpeedSource(forSource source: Double) -> Double {
    var remaining = elapsed(forSource: source)
    for segment in segments {
      let length = segment.sourceEnd - segment.sourceStart
      if remaining < length { return segment.sourceStart + max(0, remaining) }
      remaining -= length
    }
    return segments.last?.sourceEnd ?? 0
  }

  func remapCaptions(_ captions: [CaptionSegment]) -> [CaptionSegment] {
    captions.compactMap { caption in
      let start = elapsed(forSource: caption.startSeconds)
      let end = elapsed(forSource: caption.endSeconds)
      guard end > start else { return nil }
      var result = caption
      result.startSeconds = start
      result.endSeconds = end
      return result
    }
  }
}
