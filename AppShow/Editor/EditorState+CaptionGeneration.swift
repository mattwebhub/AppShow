import Foundation

extension EditorState {
  func prepareRecordedVoice() {
    guard let options = pendingRecordedVoice else { return }
    pendingRecordedVoice = nil
    guard hasMicAudio, options.captureVoice else { return }
    captionAudioSource = .microphone
    micNoiseReductionEnabled = options.cleanVoice
    if options.cleanVoice { syncNoiseReduction() }
    scheduleSave()
    generateCaptions(createCaptions: options.automaticCaptions)
  }

  func generateCaptions(createCaptions: Bool = true) {
    guard !isTranscribing, !isExporting else { return }
    transcriptionTask = Task { [weak self] in
      guard let self else { return }
      do {
        try await self.transcribeCaptions(
          createCaptions: createCaptions,
          historyLabel: createCaptions ? "Captions generated" : "Audio transcript generated"
        )
      } catch is CancellationError {
      } catch {
        self.logger.error("Transcription failed: \(error)")
      }
    }
  }

  func transcribeCaptions(
    source requestedSource: CaptionAudioSource? = nil,
    model requestedModel: WhisperModel? = nil,
    createCaptions: Bool = true,
    historyLabel: String = "Captions generated",
    using transcribe: CaptionTranscriber = TranscriptionService.run
  ) async throws {
    guard !isTranscribing, !isExporting else { throw CaptionGenerationError(message: "Finish the current transcription or export first.") }
    guard let model = requestedModel ?? WhisperModel(rawValue: captionModel) else {
      throw CaptionGenerationError(message: "Choose a caption model.")
    }
    let id = UUID()
    transcriptionGeneration = id
    isTranscribing = true
    transcriptionError = nil
    transcriptionProgress = 0
    transcriptionDidFinishEmpty = false
    let source = requestedSource ?? captionAudioSource
    let originalSegments = captionSegments
    let originalTranscripts = audioTranscripts
    let originalBatchID = agentMutationBatchID
    let selectedLanguage = captionLanguage
    let language = selectedLanguage.whisperCode
    let drift = source == .microphone ? playerController.micAudioDriftRatio : playerController.systemAudioDriftRatio
    defer {
      if transcriptionGeneration == id {
        transcriptionGeneration = nil
        isTranscribing = false
        transcriptionTask = nil
      }
    }
    do {
      while source == .microphone && isMicProcessing {
        try await Task.sleep(for: .milliseconds(100))
        guard transcriptionGeneration == id else { throw CancellationError() }
      }
      let audioURL = source == .microphone ? (processedMicAudioURL ?? result.microphoneAudioURL) : result.systemAudioURL
      guard let audioURL else {
        throw CaptionGenerationError(message: "No audio on this track. Record with a microphone or select system audio.")
      }
      if source == .microphone, micNoiseReductionEnabled, processedMicAudioURL == nil {
        throw CaptionGenerationError(
          message: "Voice cleanup did not finish. Retry noise reduction in Audio, or turn it off to use the original microphone track."
        )
      }
      let request = CaptionTranscriptionRequest(
        audioURL: audioURL,
        model: model,
        language: language,
        onProgress: { [weak self] value in
          guard let self, self.transcriptionGeneration == id, value.isFinite else { return }
          self.transcriptionProgress = max(self.transcriptionProgress, min(1, max(0, value)))
        }
      )
      let generated = try await transcribe(request)
      try Task.checkCancellation()
      guard transcriptionGeneration == id, agentMutationBatchID == originalBatchID else { throw CancellationError() }
      guard !createCaptions || captionSegments == originalSegments, audioTranscripts == originalTranscripts else {
        throw CaptionGenerationError(
          message: "Captions changed during transcription. Your edits were kept; generate again to replace them."
        )
      }
      guard !isExporting else {
        throw CaptionGenerationError(message: "Export started during transcription. Generate again when it finishes.")
      }
      let ratio = drift.isFinite && drift > 0 ? drift : 1
      let segments = Self.filterNonSpeechSegments(generated).map { segment in
        CaptionSegment(
          id: segment.id,
          startSeconds: segment.startSeconds / ratio,
          endSeconds: segment.endSeconds / ratio,
          text: segment.text,
          words: segment.words?.map { CaptionWord(word: $0.word, startSeconds: $0.startSeconds / ratio, endSeconds: $0.endSeconds / ratio) }
        )
      }
      pendingUndoTask?.cancel()
      if !agentMutationBatchActive { history.pushSnapshot(createSnapshot()) }
      audioTranscripts.removeAll { $0.source == source }
      audioTranscripts.append(AudioTranscript(source: source, language: selectedLanguage, model: model.rawValue, segments: segments))
      if createCaptions {
        captionAudioSource = source
        captionModel = model.rawValue
        captionSegments = segments
        captionsEnabled = !segments.isEmpty
      }
      transcriptionDidFinishEmpty = segments.isEmpty
      transcriptionProgress = 1
      scheduleSave()
      if !agentMutationBatchActive { history.pushSnapshot(createSnapshot(), label: historyLabel) }
    } catch {
      if transcriptionGeneration == id, !(error is CancellationError) { transcriptionError = error.localizedDescription }
      throw error
    }
  }
}
