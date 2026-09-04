import Foundation

struct CutTimeline: Sendable, Equatable {
  static let minSliceLength = 0.05
  static let cutTolerance = 0.01

  var slices: [VideoRegionData]
  var duration: Double

  var totalDuration: Double {
    slices.reduce(0) { $0 + ($1.endSeconds - $1.startSeconds) }
  }

  var hasCuts: Bool {
    guard !slices.isEmpty else { return false }
    return abs(totalDuration - duration) > Self.cutTolerance
  }

  var isSplit: Bool { slices.count > 1 }

  var showsTrack: Bool { isSplit || hasCuts }

  var boundaryTimes: [Double] {
    slices.dropLast().map(\.endSeconds)
  }

  var gaps: [ClosedRange<Double>] {
    var result: [ClosedRange<Double>] = []
    var cursor = 0.0
    for slice in slices {
      if slice.startSeconds > cursor {
        result.append(cursor...slice.startSeconds)
      }
      cursor = max(cursor, slice.endSeconds)
    }
    if cursor < duration {
      result.append(cursor...duration)
    }
    return result
  }

  func slice(containing time: Double) -> VideoRegionData? {
    slices.first { time >= $0.startSeconds && time <= $0.endSeconds }
  }

  func canCut(at time: Double) -> Bool {
    guard let slice = slice(containing: time) else { return false }
    return time - slice.startSeconds >= Self.minSliceLength
      && slice.endSeconds - time >= Self.minSliceLength
  }

  func split(at time: Double) -> CutTimeline {
    guard canCut(at: time),
      let index = slices.firstIndex(where: { time >= $0.startSeconds && time <= $0.endSeconds })
    else { return self }
    var first = slices[index]
    var second = VideoRegionData(startSeconds: time, endSeconds: first.endSeconds)
    second.exitTransition = first.exitTransition
    second.exitTransitionDuration = first.exitTransitionDuration
    first.endSeconds = time
    first.exitTransition = nil
    first.exitTransitionDuration = nil
    var result = self
    result.slices.replaceSubrange(index...index, with: [first, second])
    return result
  }

  func removing(_ range: ClosedRange<Double>) -> CutTimeline {
    let start = max(0, min(duration, range.lowerBound))
    let end = max(0, min(duration, range.upperBound))
    guard end - start >= Self.minSliceLength else { return self }
    var kept: [VideoRegionData] = []

    for slice in normalized().slices {
      if slice.endSeconds <= start || slice.startSeconds >= end {
        kept.append(slice)
        continue
      }

      let keepsLeft = start - slice.startSeconds >= Self.minSliceLength
      let keepsRight = slice.endSeconds - end >= Self.minSliceLength
      if keepsLeft {
        var left = slice
        left.endSeconds = start
        left.exitTransition = nil
        left.exitTransitionDuration = nil
        kept.append(left)
      }
      if keepsRight {
        var right = slice
        if keepsLeft { right.id = UUID() }
        right.startSeconds = end
        right.entryTransition = nil
        right.entryTransitionDuration = nil
        kept.append(right)
      }
    }

    return CutTimeline(slices: kept, duration: duration)
  }

  func elapsed(forSource time: Double) -> Double {
    var elapsed = 0.0
    for slice in slices {
      if time >= slice.endSeconds {
        elapsed += slice.endSeconds - slice.startSeconds
      } else if time >= slice.startSeconds {
        elapsed += time - slice.startSeconds
        break
      } else {
        break
      }
    }
    return elapsed
  }

  func source(forElapsed elapsed: Double) -> Double {
    var remaining = elapsed
    for slice in slices {
      let length = slice.endSeconds - slice.startSeconds
      if remaining <= length {
        return slice.startSeconds + remaining
      }
      remaining -= length
    }
    return slices.last?.endSeconds ?? 0
  }

  func nextSliceStart(after time: Double) -> Double? {
    slices.first { $0.startSeconds > time }?.startSeconds
  }

  func normalized() -> CutTimeline {
    let clamped = slices.compactMap { slice -> VideoRegionData? in
      var copy = slice
      copy.startSeconds = max(0, min(duration, slice.startSeconds))
      copy.endSeconds = max(0, min(duration, slice.endSeconds))
      return copy.endSeconds - copy.startSeconds >= Self.minSliceLength ? copy : nil
    }
    .sorted { $0.startSeconds < $1.startSeconds }
    var merged: [VideoRegionData] = []
    for slice in clamped {
      if let last = merged.last, slice.startSeconds < last.endSeconds {
        merged[merged.count - 1].endSeconds = max(last.endSeconds, slice.endSeconds)
      } else {
        merged.append(slice)
      }
    }
    return CutTimeline(slices: merged, duration: duration)
  }
}
