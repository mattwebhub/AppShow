import Foundation

enum ExternalAudioSchedule {
  static let driftTolerance: Double = 0.04

  struct Segment: Equatable, Sendable {
    let startFrame: Int64
    let frameCount: Int64
    let delayFrames: Int64
  }

  static func effectiveFades(for track: ExternalAudioTrackData) -> (fadeIn: Double, fadeOut: Double) {
    let half = max(0, track.lengthSeconds / 2)
    return (min(max(0, track.fadeInSeconds), half), min(max(0, track.fadeOutSeconds), half))
  }

  static func gain(at time: Double, track: ExternalAudioTrackData) -> Float {
    let start = track.timelineStartSeconds
    let end = track.timelineEndSeconds
    guard time >= start, time < end else { return 0 }
    let fades = effectiveFades(for: track)
    var gain = 1.0
    if fades.fadeIn > 0, time < start + fades.fadeIn {
      gain = (time - start) / fades.fadeIn
    }
    if fades.fadeOut > 0, time > end - fades.fadeOut {
      gain = min(gain, (end - time) / fades.fadeOut)
    }
    return Float(min(max(0, gain), 1))
  }

  static func segment(track: ExternalAudioTrackData, at time: Double, sampleRate: Double) -> Segment? {
    guard time >= track.timelineStartSeconds, time < track.timelineEndSeconds else { return nil }
    let elapsed = time - track.timelineStartSeconds
    let startFrame = frames(track.fileInSeconds + elapsed, sampleRate)
    let endFrame = frames(track.fileOutSeconds, sampleRate)
    guard endFrame > startFrame else { return nil }
    return Segment(startFrame: startFrame, frameCount: endFrame - startFrame, delayFrames: 0)
  }

  static func upcomingSegment(track: ExternalAudioTrackData, at time: Double, sampleRate: Double) -> Segment? {
    guard time < track.timelineStartSeconds else {
      return segment(track: track, at: time, sampleRate: sampleRate)
    }
    let startFrame = frames(track.fileInSeconds, sampleRate)
    let endFrame = frames(track.fileOutSeconds, sampleRate)
    guard endFrame > startFrame else { return nil }
    return Segment(
      startFrame: startFrame,
      frameCount: endFrame - startFrame,
      delayFrames: frames(track.timelineStartSeconds - time, sampleRate)
    )
  }

  static func nextAudibleTime(after time: Double, in videoRegions: [(start: Double, end: Double)]) -> Double? {
    guard !videoRegions.isEmpty else { return time }
    if videoRegions.contains(where: { time >= $0.start && time < $0.end }) {
      return time
    }
    return videoRegions.first(where: { $0.start > time })?.start
  }

  static func exceedsDriftTolerance(anchorTime: Double, playedSeconds: Double, timelineTime: Double) -> Bool {
    abs(anchorTime + playedSeconds - timelineTime) > driftTolerance
  }

  private static func frames(_ seconds: Double, _ sampleRate: Double) -> Int64 {
    Int64((seconds * sampleRate).rounded())
  }
}
