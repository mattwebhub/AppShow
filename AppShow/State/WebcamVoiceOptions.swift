import Foundation

struct WebcamVoiceOptions: Codable, Sendable, Equatable {
  var captureVoice = true
  var automaticCaptions = true
  var cleanVoice = true
}
