import Foundation

enum ExternalAudioTrackMath {
  static let minimumLengthSeconds: Double = 0.05

  static func move(_ track: ExternalAudioTrackData, to newStart: Double, recordingDuration: Double) -> ExternalAudioTrackData {
    var result = track
    let latestStart = max(0, recordingDuration - track.lengthSeconds)
    result.timelineStartSeconds = min(max(0, newStart), latestStart)
    return result
  }

  static func trimStart(_ track: ExternalAudioTrackData, to newTimelineStart: Double) -> ExternalAudioTrackData {
    var result = track
    let earliest = max(0, track.timelineStartSeconds - track.fileInSeconds)
    let latest = track.timelineEndSeconds - minimumLengthSeconds
    let start = min(max(newTimelineStart, earliest), max(earliest, latest))
    result.fileInSeconds = track.fileInSeconds + (start - track.timelineStartSeconds)
    result.timelineStartSeconds = start
    return result
  }

  static func trimEnd(_ track: ExternalAudioTrackData, to newTimelineEnd: Double, recordingDuration: Double) -> ExternalAudioTrackData {
    var result = track
    let earliest = track.timelineStartSeconds + minimumLengthSeconds
    let sourceLimit = track.timelineStartSeconds + (track.sourceDurationSeconds - track.fileInSeconds)
    let latest = min(recordingDuration, sourceLimit)
    let end = min(max(newTimelineEnd, earliest), max(earliest, latest))
    result.fileOutSeconds = track.fileInSeconds + (end - track.timelineStartSeconds)
    return result
  }

  static func clamped(_ track: ExternalAudioTrackData, to recordingDuration: Double) -> ExternalAudioTrackData {
    var result = track
    result.fileInSeconds = min(max(0, track.fileInSeconds), track.sourceDurationSeconds)
    result.fileOutSeconds = min(max(result.fileInSeconds, track.fileOutSeconds), track.sourceDurationSeconds)
    let length = result.lengthSeconds
    let latestStart = max(0, recordingDuration - min(length, minimumLengthSeconds))
    result.timelineStartSeconds = min(max(0, track.timelineStartSeconds), latestStart)
    let available = max(0, recordingDuration - result.timelineStartSeconds)
    if length > available {
      result.fileOutSeconds = result.fileInSeconds + available
    }
    return result
  }
}
