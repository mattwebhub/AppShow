import Foundation

struct ExternalAudioTrackData: Codable, Sendable, Identifiable, Equatable {
  var id: UUID = UUID()
  var fileName: String
  var displayName: String
  var sourceDurationSeconds: Double
  var timelineStartSeconds: Double
  var fileInSeconds: Double = 0
  var fileOutSeconds: Double
  var volume: Float = 1.0
  var muted: Bool = false
  var fadeInSeconds: Double = 0
  var fadeOutSeconds: Double = 0

  var lengthSeconds: Double { fileOutSeconds - fileInSeconds }
  var timelineEndSeconds: Double { timelineStartSeconds + lengthSeconds }
  var effectiveVolume: Float { muted ? 0 : volume }
}

extension ExternalAudioTrackData {
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(UUID.self, forKey: .id)
    fileName = try c.decode(String.self, forKey: .fileName)
    displayName = try c.decode(String.self, forKey: .displayName)
    sourceDurationSeconds = try c.decode(Double.self, forKey: .sourceDurationSeconds)
    timelineStartSeconds = try c.decodeOrDefault(.timelineStartSeconds, 0)
    fileInSeconds = try c.decodeOrDefault(.fileInSeconds, 0)
    fileOutSeconds = try c.decodeOrDefault(.fileOutSeconds, sourceDurationSeconds)
    volume = try c.decodeOrDefault(.volume, 1.0)
    muted = try c.decodeOrDefault(.muted, false)
    fadeInSeconds = try c.decodeOrDefault(.fadeInSeconds, 0)
    fadeOutSeconds = try c.decodeOrDefault(.fadeOutSeconds, 0)
  }
}
