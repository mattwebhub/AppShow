import AVFoundation

extension VideoCompositor {
  static func speedMap(regions: [SpeedRegionData], trim: CMTimeRange, segments: [VideoSegment], duration: Double) -> SpeedTimeline {
    let sourceSegments = segments.isEmpty ? [VideoSegment(sourceRange: trim, compositionStart: .zero)] : segments
    let mapped = sourceSegments.flatMap { segment in
      regions.compactMap { region -> SpeedRegionData? in
        let start = max(region.startSeconds, segment.sourceRange.start.seconds)
        let end = min(region.endSeconds, segment.sourceRange.end.seconds)
        guard end > start else { return nil }
        return SpeedRegionData(
          startSeconds: segment.compositionStart.seconds + start - segment.sourceRange.start.seconds,
          endSeconds: segment.compositionStart.seconds + end - segment.sourceRange.start.seconds,
          rate: region.rate
        )
      }
    }
    return SpeedTimeline(duration: duration, regions: mapped)
  }

  static func applySpeed(_ map: SpeedTimeline, to composition: AVMutableComposition, preserving trackIDs: Set<CMPersistentTrackID> = []) {
    for segment in map.segments.reversed() where segment.rate != 1 {
      let range = CMTimeRange(
        start: CMTime(seconds: segment.sourceStart, preferredTimescale: 60000),
        end: CMTime(seconds: segment.sourceEnd, preferredTimescale: 60000)
      )
      for track in composition.tracks where !trackIDs.contains(track.trackID) {
        track.scaleTimeRange(range, toDuration: CMTimeMultiplyByFloat64(range.duration, multiplier: 1 / segment.rate))
      }
    }
  }

  static func retimeRamp(_ ramp: ExternalAudioVolumeRamp, using map: SpeedTimeline) -> [ExternalAudioVolumeRamp] {
    let start = ramp.timeRange.start.seconds
    let end = ramp.timeRange.end.seconds
    return map.segments.compactMap { segment in
      let a = max(start, segment.sourceStart)
      let b = min(end, segment.sourceEnd)
      guard b > a, end > start else { return nil }
      func gain(_ time: Double) -> Float {
        ramp.startVolume + (ramp.endVolume - ramp.startVolume) * Float((time - start) / (end - start))
      }
      return ExternalAudioVolumeRamp(
        timeRange: CMTimeRange(
          start: CMTime(seconds: map.elapsed(forSource: a), preferredTimescale: 60000),
          end: CMTime(seconds: map.elapsed(forSource: b), preferredTimescale: 60000)
        ),
        startVolume: gain(a),
        endVolume: gain(b)
      )
    }
  }
}
