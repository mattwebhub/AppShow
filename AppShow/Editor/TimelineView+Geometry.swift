import AVFoundation
import SwiftUI

extension TimelineView {
  var effectiveDisplayMode: TimelineDisplayMode {
    editorState.showCutTrack ? displayMode : .source
  }

  var isTrackEditable: Bool {
    effectiveDisplayMode == .source
  }

  var visibleSeconds: Double {
    TimelineGeometry(timeline: editorState.cutTimeline, width: 1, mode: effectiveDisplayMode).visibleDuration
  }

  func geometry(width: CGFloat) -> TimelineGeometry {
    TimelineGeometry(timeline: displayCutTimeline(width: width), width: width, mode: effectiveDisplayMode)
  }

  func xPosition(forSource time: Double, width: CGFloat) -> CGFloat {
    geometry(width: width).x(forSource: time)
  }

  func sourceTime(forX x: CGFloat, width: CGFloat) -> Double {
    geometry(width: width).sourceTime(forX: x)
  }

  func waveformPoints(samples: [Float], width: CGFloat, height: CGFloat) -> (top: [CGPoint], bottom: [CGPoint]) {
    let count = samples.count
    guard count > 1 else { return ([], []) }
    let midY = height / 2
    let maxAmp = height * 0.4
    let step = width / CGFloat(count - 1)
    let sourceStep = totalSeconds / Double(count - 1)
    let g = geometry(width: width)

    var top: [CGPoint] = []
    var bottom: [CGPoint] = []
    for i in 0..<count {
      let x: CGFloat
      switch g.mode {
      case .source:
        x = CGFloat(i) * step
      case .compressed:
        let time = Double(i) * sourceStep
        guard g.timeline.slice(containing: time) != nil else { continue }
        x = g.x(forSource: time)
      }
      let amp = CGFloat(samples[i]) * maxAmp
      top.append(CGPoint(x: x, y: midY - amp))
      bottom.append(CGPoint(x: x, y: midY + amp))
    }
    return (top, bottom)
  }

  private func displayCutTimeline(width: CGFloat) -> CutTimeline {
    var timeline = editorState.cutTimeline
    guard effectiveDisplayMode == .compressed,
      videoDragType != nil,
      let id = videoDragRegionId,
      let index = timeline.slices.firstIndex(where: { $0.id == id })
    else { return timeline }
    let effective = effectiveVideoRegion(timeline.slices[index], width: width)
    timeline.slices[index].startSeconds = effective.start
    timeline.slices[index].endSeconds = effective.end
    return timeline
  }
}
