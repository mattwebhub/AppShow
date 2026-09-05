import Foundation
import Testing

@testable import AppShow

@MainActor
@Suite(.serialized)
struct CaptionGenerationTests {
  private func state(in directory: URL) async throws -> EditorState {
    let result = try await ProjectFixtures.recordingResult(in: directory, webcam: true, systemAudio: false, microphone: true, cursor: false)
    let state = EditorState(result: result)
    await state.setup()
    return state
  }

  @Test func voicePreferencesPersistWithoutChangingOldConfigs() throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let url = directory.appendingPathComponent("config.json")
    let config = ConfigService(fileURL: url)
    #expect(config.webcamVoice == WebcamVoiceOptions())
    config.webcamVoice = WebcamVoiceOptions(captureVoice: false, automaticCaptions: false, cleanVoice: false)
    #expect(ConfigService(fileURL: url).webcamVoice == config.webcamVoice)
  }

  @Test func failedModelDownloadLeavesThePanelReadyToRetry() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let manager = WhisperModelManager(modelsDirectory: directory)
    do {
      try await manager.downloadModel(.base, using: { _, _, _ in throw CaptionGenerationError(message: "Offline") })
      Issue.record("Expected download error")
    } catch {}
    #expect(!manager.isDownloading)
    #expect(manager.downloadingModel == nil)
    #expect(!manager.isDownloaded(.base))
  }

  @Test func generationUsesProcessedVoiceAndPreservesRecentEditsOnUndo() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let state = try await state(in: directory)
    defer { state.teardown() }
    state.cameraCornerRadius = 31
    let cleaned = directory.appendingPathComponent("cleaned.m4a")
    state.processedMicAudioURL = cleaned
    try await state.transcribeCaptions(using: { request in
      #expect(request.audioURL == cleaned)
      return [CaptionSegment(startSeconds: 0.2, endSeconds: 0.8, text: "Hello there")]
    })
    #expect(state.captionsEnabled)
    #expect(state.captionSegments.first?.text == "Hello there")
    state.undo()
    #expect(state.captionSegments.isEmpty)
    #expect(state.cameraCornerRadius == 31)
  }

  @Test func delayedGenerationCannotOverwriteUserEditedCaptions() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let state = try await state(in: directory)
    defer { state.teardown() }
    let edited = CaptionSegment(startSeconds: 0, endSeconds: 1, text: "My correction")
    do {
      try await state.transcribeCaptions(using: { _ in
        await MainActor.run { state.captionSegments = [edited] }
        return [CaptionSegment(startSeconds: 0, endSeconds: 1, text: "Stale result")]
      })
      Issue.record("Expected stale caption rejection")
    } catch {}
    #expect(state.captionSegments == [edited])
    #expect(!state.isTranscribing)
  }

  @Test func cancellationCannotCommitEvenIfEngineIgnoresCancellation() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let state = try await state(in: directory)
    defer { state.teardown() }
    do {
      try await state.transcribeCaptions(using: { _ in
        await MainActor.run { state.cancelTranscription() }
        return [CaptionSegment(startSeconds: 0, endSeconds: 1, text: "Canceled")]
      })
      Issue.record("Expected cancellation")
    } catch is CancellationError {} catch { Issue.record(error) }
    #expect(state.captionSegments.isEmpty)
    #expect(!state.isTranscribing)
  }

  @Test func automaticVoiceSetupRunsOnlyOnceAndNeverOnReopen() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let state = try await state(in: directory)
    defer { state.teardown() }
    state.pendingRecordedVoice = WebcamVoiceOptions(automaticCaptions: false, cleanVoice: false)
    state.prepareRecordedVoice()
    #expect(state.pendingRecordedVoice == nil)
    #expect(state.captionAudioSource == .microphone)
    #expect(!state.isTranscribing)
    state.captionAudioSource = .system
    state.prepareRecordedVoice()
    #expect(state.captionAudioSource == .system)
  }
}
