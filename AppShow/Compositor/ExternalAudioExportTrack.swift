import CoreMedia
import Foundation

struct ExternalAudioExportTrack: Sendable, Equatable {
  let url: URL
  let timelineRange: CMTimeRange
  let fileStart: CMTime
  let volume: Float
  let fadeIn: CMTime
  let fadeOut: CMTime
}

struct ExternalAudioInsertion: Sendable, Equatable {
  let compositionRange: CMTimeRange
  let fileRange: CMTimeRange
}

struct ExternalAudioVolumeRamp: Sendable, Equatable {
  let timeRange: CMTimeRange
  let startVolume: Float
  let endVolume: Float
}
