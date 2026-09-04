import Foundation

enum TimelineDisplayMode: Sendable, Equatable {
  case source
  case compressed
}

struct TimelineGeometry: Sendable, Equatable {
  let timeline: CutTimeline
  let width: CGFloat
  let mode: TimelineDisplayMode

  var visibleDuration: Double {
    switch mode {
    case .source: max(timeline.duration, 0.001)
    case .compressed: max(timeline.totalDuration, 0.001)
    }
  }

  func displayTime(forSource time: Double) -> Double {
    switch mode {
    case .source: time
    case .compressed: timeline.elapsed(forSource: time)
    }
  }

  func x(forSource time: Double) -> CGFloat {
    CGFloat(displayTime(forSource: time) / visibleDuration) * width
  }

  func x(forDisplay time: Double) -> CGFloat {
    CGFloat(time / visibleDuration) * width
  }

  func sourceTime(forX x: CGFloat) -> Double {
    let fraction = max(0, min(1, x / width))
    let display = Double(fraction) * visibleDuration
    switch mode {
    case .source:
      return display
    case .compressed:
      var cursor = 0.0
      for slice in timeline.slices {
        let length = slice.endSeconds - slice.startSeconds
        if display < cursor + length {
          return slice.startSeconds + (display - cursor)
        }
        cursor += length
      }
      return timeline.slices.last?.endSeconds ?? 0
    }
  }

  func pieces(forRegion start: Double, end: Double) -> [(start: Double, end: Double)] {
    switch mode {
    case .source:
      return [(start, end)]
    case .compressed:
      return timeline.slices.compactMap { slice in
        let pieceStart = max(start, slice.startSeconds)
        let pieceEnd = min(end, slice.endSeconds)
        guard pieceEnd > pieceStart else { return nil }
        return (displayTime(forSource: pieceStart), displayTime(forSource: pieceEnd))
      }
    }
  }

  func rulerInterval(zoom: CGFloat) -> Double {
    let effectiveDuration = visibleDuration / Double(zoom)
    if effectiveDuration <= 5 { return 1 }
    if effectiveDuration <= 15 { return 2 }
    if effectiveDuration <= 30 { return 5 }
    if effectiveDuration <= 60 { return 10 }
    if effectiveDuration <= 180 { return 30 }
    if effectiveDuration <= 600 { return 60 }
    return 120
  }
}
