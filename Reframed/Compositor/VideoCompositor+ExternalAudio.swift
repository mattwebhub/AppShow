import AVFoundation
import CoreMedia
import Foundation

extension VideoCompositor {
  struct ExternalAudioCompositionTrack: Sendable {
    let trackID: CMPersistentTrackID
    let track: ExternalAudioExportTrack
    let insertions: [ExternalAudioInsertion]
  }

  static func insertions(
    for track: ExternalAudioExportTrack,
    trim: CMTimeRange,
    segments: [VideoSegmentInfo]?
  ) -> [ExternalAudioInsertion] {
    if let segments, !segments.isEmpty {
      return segments.compactMap { segment in
        insertion(for: track, sourceRange: segment.sourceRange, compositionStart: segment.compositionStart)
      }
    }
    return insertion(for: track, sourceRange: trim, compositionStart: .zero).map { [$0] } ?? []
  }

  static func volumeRamps(
    for track: ExternalAudioExportTrack,
    insertions: [ExternalAudioInsertion]
  ) -> [ExternalAudioVolumeRamp] {
    let start = track.timelineRange.start.seconds
    let end = track.timelineRange.end.seconds
    let half = max(0, (end - start) / 2)
    let fadeIn = min(max(0, track.fadeIn.seconds), half)
    let fadeOut = min(max(0, track.fadeOut.seconds), half)
    var fades: [(from: Double, to: Double, startVolume: Float, endVolume: Float)] = []
    if fadeIn > 0 {
      fades.append((start, start + fadeIn, 0, 1))
    }
    if fadeOut > 0 {
      fades.append((end - fadeOut, end, 1, 0))
    }
    guard !fades.isEmpty else { return [] }

    var ramps: [ExternalAudioVolumeRamp] = []
    for insertion in insertions {
      let timelineStart = start + (insertion.fileRange.start.seconds - track.fileStart.seconds)
      let timelineEnd = timelineStart + insertion.fileRange.duration.seconds
      for fade in fades {
        let a = max(fade.from, timelineStart)
        let b = min(fade.to, timelineEnd)
        guard b > a else { continue }
        let span = fade.to - fade.from
        func gain(_ t: Double) -> Float {
          fade.startVolume + (fade.endVolume - fade.startVolume) * Float((t - fade.from) / span)
        }
        let compositionStart = insertion.compositionRange.start.seconds + (a - timelineStart)
        ramps.append(
          ExternalAudioVolumeRamp(
            timeRange: CMTimeRange(
              start: CMTime(seconds: compositionStart, preferredTimescale: 600),
              end: CMTime(seconds: compositionStart + (b - a), preferredTimescale: 600)
            ),
            startVolume: gain(a) * track.volume,
            endVolume: gain(b) * track.volume
          )
        )
      }
    }
    return ramps
  }

  static func addExternalAudioTracks(
    to composition: AVMutableComposition,
    tracks: [ExternalAudioExportTrack],
    trim: CMTimeRange,
    segments: [VideoSegmentInfo]?
  ) async throws -> [ExternalAudioCompositionTrack] {
    var added: [ExternalAudioCompositionTrack] = []
    for track in tracks {
      let insertions = insertions(for: track, trim: trim, segments: segments)
      guard !insertions.isEmpty else { continue }
      let asset = AVURLAsset(url: track.url)
      guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
        logger.warning("Skipping external audio without an audio track: \(track.url.lastPathComponent)")
        continue
      }
      let available = try await audioTrack.load(.timeRange)
      guard
        let compTrack = composition.addMutableTrack(
          withMediaType: .audio,
          preferredTrackID: kCMPersistentTrackID_Invalid
        )
      else { continue }
      for insertion in insertions {
        let fileRange = CMTimeRangeGetIntersection(insertion.fileRange, otherRange: available)
        guard CMTimeCompare(fileRange.duration, .zero) > 0 else { continue }
        try compTrack.insertTimeRange(fileRange, of: audioTrack, at: insertion.compositionRange.start)
      }
      added.append(ExternalAudioCompositionTrack(trackID: compTrack.trackID, track: track, insertions: insertions))
    }
    return added
  }

  static func externalMixParameters(for tracks: [ExternalAudioCompositionTrack]) -> [AVMutableAudioMixInputParameters] {
    tracks.map { entry in
      let parameters = AVMutableAudioMixInputParameters()
      parameters.trackID = entry.trackID
      let ramps = volumeRamps(for: entry.track, insertions: entry.insertions)
      let firstRampStartsAtZero = ramps.first.map { CMTimeCompare($0.timeRange.start, .zero) == 0 } ?? false
      if !firstRampStartsAtZero {
        parameters.setVolume(entry.track.volume, at: .zero)
      }
      for ramp in ramps {
        parameters.setVolumeRamp(fromStartVolume: ramp.startVolume, toEndVolume: ramp.endVolume, timeRange: ramp.timeRange)
      }
      return parameters
    }
  }

  static func audioMix(base: AVMutableAudioMix?, adding parameters: [AVMutableAudioMixInputParameters]) -> AVMutableAudioMix? {
    guard !parameters.isEmpty else { return base }
    let mix = base ?? AVMutableAudioMix()
    let externalIDs = Set(parameters.map(\.trackID))
    mix.inputParameters = mix.inputParameters.filter { !externalIDs.contains($0.trackID) } + parameters
    return mix
  }

  private static func insertion(
    for track: ExternalAudioExportTrack,
    sourceRange: CMTimeRange,
    compositionStart: CMTime
  ) -> ExternalAudioInsertion? {
    let overlapStart = CMTimeMaximum(track.timelineRange.start, sourceRange.start)
    let overlapEnd = CMTimeMinimum(track.timelineRange.end, sourceRange.end)
    guard CMTimeCompare(overlapEnd, overlapStart) > 0 else { return nil }
    let duration = CMTimeSubtract(overlapEnd, overlapStart)
    let compositionOffset = CMTimeSubtract(overlapStart, sourceRange.start)
    let fileOffset = CMTimeSubtract(overlapStart, track.timelineRange.start)
    return ExternalAudioInsertion(
      compositionRange: CMTimeRange(start: CMTimeAdd(compositionStart, compositionOffset), duration: duration),
      fileRange: CMTimeRange(start: CMTimeAdd(track.fileStart, fileOffset), duration: duration)
    )
  }
}
