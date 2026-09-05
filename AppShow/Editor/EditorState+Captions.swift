import Foundation
import Logging

extension EditorState {
  var captionAudioURL: URL? {
    switch captionAudioSource {
    case .microphone: processedMicAudioURL ?? result.microphoneAudioURL
    case .system: result.systemAudioURL
    }
  }

  func cancelTranscription() {
    transcriptionGeneration = nil
    transcriptionTask?.cancel()
    transcriptionTask = nil
    isTranscribing = false
    transcriptionProgress = 0
  }

  func clearCaptions() {
    captionSegments = []
    captionsEnabled = false
    transcriptionDidFinishEmpty = false
    scheduleSave()
    history.pushSnapshot(createSnapshot())
  }

  func updateSegmentText(_ id: UUID, text: String) {
    guard let idx = captionSegments.firstIndex(where: { $0.id == id }) else { return }
    captionSegments[idx].text = text
    captionSegments[idx].words = nil
    scheduleSave()
    history.pushSnapshot(createSnapshot())
  }

  func deleteSegment(_ id: UUID) {
    captionSegments.removeAll { $0.id == id }
    if captionSegments.isEmpty {
      captionsEnabled = false
    }
    scheduleSave()
    history.pushSnapshot(createSnapshot())
  }

  func captionAtTime(_ time: Double) -> CaptionSegment? {
    FrameRenderer.captionSegmentAt(time: time, in: captionSegments)
  }

  func visibleCaptionText(at time: Double) -> String? {
    guard captionsEnabled, let segment = captionAtTime(time) else { return nil }
    let text = FrameRenderer.visibleText(
      for: segment,
      at: time,
      maxWordsPerLine: captionMaxWordsPerLine
    )
    return text.isEmpty ? nil : text
  }

  private static let nonSpeechPattern: Regex = /^\s*[\[\(].*[\]\)]\s*$/

  static func filterNonSpeechSegments(_ segments: [CaptionSegment]) -> [CaptionSegment] {
    segments.filter { seg in
      let text = seg.text.trimmingCharacters(in: .whitespaces)
      if text.isEmpty { return false }
      if text.wholeMatch(of: nonSpeechPattern) != nil { return false }
      return true
    }
  }
}
