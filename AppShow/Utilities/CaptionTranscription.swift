import Foundation

struct CaptionTranscriptionRequest: Sendable {
  let audioURL: URL
  let model: WhisperModel
  let language: String?
  let onProgress: @MainActor @Sendable (Double) -> Void
}

typealias CaptionTranscriber = @Sendable (CaptionTranscriptionRequest) async throws -> [CaptionSegment]

struct CaptionGenerationError: LocalizedError {
  let message: String
  var errorDescription: String? { message }
}

extension TranscriptionService {
  static func run(_ request: CaptionTranscriptionRequest) async throws -> [CaptionSegment] {
    guard let path = await WhisperModelManager.shared.modelPath(for: request.model) else {
      throw CaptionGenerationError(
        message: "Download the \(request.model.shortLabel) model in Captions, then choose Generate Captions. Audio stays on this Mac."
      )
    }
    return try await transcribe(
      audioURL: request.audioURL,
      model: request.model,
      modelPath: path,
      language: request.language,
      onProgress: request.onProgress
    )
  }
}
