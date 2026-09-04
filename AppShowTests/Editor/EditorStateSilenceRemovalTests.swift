import CoreMedia
import Foundation
import Testing

@testable import AppShow

@MainActor
@Suite(.serialized)
struct EditorStateSilenceRemovalTests {
  private let micGap = 0.7...1.5

  private func makeState(microphone: Bool = true, systemAudio: Bool = false) async throws -> (EditorState, URL) {
    let dir = try TestPaths.makeTemporaryDirectory()
    let base = try await ProjectFixtures.recordingResult(
      in: dir,
      webcam: false,
      systemAudio: systemAudio,
      microphone: false,
      cursor: false
    )
    let micURL =
      microphone
      ? try AudioFixtures.toneWithGap(duration: 2, gap: micGap, container: .m4a, in: dir, name: "mic-gap") : nil
    let result = RecordingResult(
      screenVideoURL: base.screenVideoURL,
      webcamVideoURL: nil,
      systemAudioURL: base.systemAudioURL,
      microphoneAudioURL: micURL,
      cursorMetadataURL: nil,
      screenSize: base.screenSize,
      webcamSize: nil,
      fps: base.fps,
      captureQuality: base.captureQuality,
      isHDR: base.isHDR
    )
    let state = EditorState(result: result)
    await state.setup()
    return (state, dir)
  }

  private func region(_ start: Double, _ end: Double) -> VideoRegionData {
    VideoRegionData(startSeconds: start, endSeconds: end)
  }

  private func near(_ a: Double, _ b: Double, tolerance: Double = 0.1) -> Bool {
    abs(a - b) <= tolerance
  }

  @Test func previewReportsCountAndTotalWithoutMutating() async throws {
    let (state, dir) = try await makeState()
    defer { TestPaths.remove(dir) }
    let entriesBefore = state.history.entries.count
    let preview = await state.previewSilenceRemoval(config: SilenceDetectorConfig())
    #expect(preview.count == 1)
    #expect(near(preview.totalRemoved, 0.5))
    #expect(preview.slices.count == 2)
    #expect(preview.canApply)
    #expect(state.videoRegions.count == 1)
    #expect(!state.showCutTrack)
    #expect(state.history.entries.count == entriesBefore)
  }

  @Test func applyWritesSlicesAndPushesOneLabelledSnapshot() async throws {
    let (state, dir) = try await makeState()
    defer { TestPaths.remove(dir) }
    let preview = await state.previewSilenceRemoval(config: SilenceDetectorConfig())
    let entriesBefore = state.history.entries.count
    state.applySilenceRemoval(preview)
    #expect(state.videoRegions.count == 2)
    #expect(near(state.videoRegions[0].startSeconds, 0))
    #expect(near(state.videoRegions[0].endSeconds, micGap.lowerBound + 0.15))
    #expect(near(state.videoRegions[1].startSeconds, micGap.upperBound - 0.15))
    #expect(near(state.videoRegions[1].endSeconds, CMTimeGetSeconds(state.duration), tolerance: 0.01))
    #expect(state.showCutTrack)
    #expect(state.hasVideoRegionCuts)
    #expect(state.history.entries.count == entriesBefore + 1)
    #expect(state.history.entries.last?.label == "Silences removed")
    #expect(state.history.entries.last?.snapshot.videoRegions == state.videoRegions)
    await Task.yield()
    #expect(state.pendingUndoTask?.isCancelled ?? true)
  }

  @Test func undoAfterApplyRestoresPreviousSlices() async throws {
    let (state, dir) = try await makeState()
    defer { TestPaths.remove(dir) }
    state.history.pushSnapshot(state.createSnapshot())
    let before = state.videoRegions
    let preview = await state.previewSilenceRemoval(config: SilenceDetectorConfig())
    state.applySilenceRemoval(preview)
    #expect(state.videoRegions.count == 2)
    state.undo()
    #expect(state.videoRegions == before)
    state.redo()
    #expect(state.videoRegions.count == 2)
  }

  @Test func applyIntersectsWithExistingCuts() async throws {
    let (state, dir) = try await makeState()
    defer { TestPaths.remove(dir) }
    state.videoRegions = [region(0, 1.0)]
    let preview = await state.previewSilenceRemoval(config: SilenceDetectorConfig())
    #expect(preview.count == 1)
    #expect(preview.slices.count == 1)
    state.applySilenceRemoval(preview)
    #expect(state.videoRegions.count == 1)
    #expect(near(state.videoRegions[0].startSeconds, 0))
    #expect(near(state.videoRegions[0].endSeconds, micGap.lowerBound + 0.15))
  }

  @Test func applyIgnoresPreviewThatCannotBeApplied() async throws {
    let (state, dir) = try await makeState()
    defer { TestPaths.remove(dir) }
    let entriesBefore = state.history.entries.count
    let preview = await state.previewSilenceRemoval(config: SilenceDetectorConfig(minimumSilence: 1.5))
    #expect(preview.count == 0)
    #expect(!preview.canApply)
    state.applySilenceRemoval(preview)
    #expect(state.videoRegions.count == 1)
    #expect(state.history.entries.count == entriesBefore)
  }

  @Test func previewUsesRequestedSource() async throws {
    let (state, dir) = try await makeState(microphone: true, systemAudio: true)
    defer { TestPaths.remove(dir) }
    #expect(state.availableSilenceSources == [.microphone, .system, .both])
    let mic = await state.previewSilenceRemoval(config: SilenceDetectorConfig(), source: .microphone)
    #expect(mic.count == 1)
    let system = await state.previewSilenceRemoval(config: SilenceDetectorConfig(), source: .system)
    #expect(system.count == 0)
    let both = await state.previewSilenceRemoval(config: SilenceDetectorConfig(), source: .both)
    #expect(both.count == 0)
  }

  @Test func previewWithNoAudioSourceIsEmpty() async throws {
    let (state, dir) = try await makeState(microphone: false)
    defer { TestPaths.remove(dir) }
    #expect(state.availableSilenceSources.isEmpty)
    let preview = await state.previewSilenceRemoval(config: SilenceDetectorConfig())
    #expect(preview.count == 0)
    #expect(!preview.canApply)
    #expect(state.videoRegions.count == 1)
  }
}
