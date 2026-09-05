import Foundation

struct AudioTranscript: Codable, Sendable, Equatable {
  var source: CaptionAudioSource
  var language: CaptionLanguage
  var model: String
  var segments: [CaptionSegment]
}
