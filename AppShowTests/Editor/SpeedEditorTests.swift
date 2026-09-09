import CoreMedia
import Foundation
import Testing

@testable import AppShow

@MainActor
@Suite(.serialized)
struct SpeedEditorTests {
  @Test func speedEditPersistsRestoresAndUndoesWithoutChangingSource() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let result = try await ProjectFixtures.recordingResult(in: dir, webcam: false, systemAudio: false, microphone: false, cursor: false)
    let state = EditorState(result: result)
    await state.setup()
    defer { state.teardown() }
    let bytes = try Data(contentsOf: result.screenVideoURL)
    let region = try state.addSpeedRegion(start: 0.5, end: 1.5, rate: 32)
    #expect(state.videoRegionsTotalDuration == 1.03125)
    let encoded = try JSONEncoder().encode(state.createSnapshot())
    let restored = try JSONDecoder().decode(EditorStateData.self, from: encoded)
    #expect(restored.speedRegions == [region])
    #expect(state.playerController.speedRegions == [region])
    #expect(throws: AgentToolError.self) { try state.addSpeedRegion(start: 1, end: 2, rate: 2) }
    #expect(state.speedRegions == [region])
    state.undo()
    #expect(state.speedRegions.isEmpty)
    #expect(state.playerController.speedRegions.isEmpty)
    state.redo()
    #expect(state.speedRegions == [region])
    #expect(state.playerController.speedRegions == [region])
    #expect(try Data(contentsOf: result.screenVideoURL) == bytes)
  }

  @Test func reopeningProjectRestoresSpeedAndLegacyProjectsDefaultToNormal() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let result = try await ProjectFixtures.recordingResult(in: dir, webcam: false, systemAudio: false, microphone: false, cursor: false)
    let project = try AppShowProject.create(
      from: result,
      fps: result.fps,
      captureMode: .entireScreen,
      in: dir.appendingPathComponent("projects"),
      cleanupTemp: false
    )
    let state = EditorState(project: project)
    await state.setup()
    #expect(state.speedRegions.isEmpty)
    let region = try state.addSpeedRegion(start: 0.25, end: 1.75, rate: 8)
    try project.saveEditorState(state.createSnapshot())
    state.teardown()
    let reopened = EditorState(project: try AppShowProject.open(at: project.bundleURL))
    await reopened.setup()
    defer { reopened.teardown() }
    #expect(reopened.speedRegions == [region])
    #expect(reopened.playerController.speedRegions == [region])
    #expect(reopened.videoRegionsTotalDuration == 0.6875)
  }

  @Test func outputClockClipsSpeedRegionsToTrim() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let result = try await ProjectFixtures.recordingResult(in: dir, webcam: false, systemAudio: false, microphone: false, cursor: false)
    let state = EditorState(result: result)
    await state.setup()
    defer { state.teardown() }
    state.trimStart = CMTime(seconds: 0.5, preferredTimescale: 600)
    state.trimEnd = CMTime(seconds: 1.5, preferredTimescale: 600)
    try state.addSpeedRegion(start: 0, end: 1, rate: 2)
    #expect(state.videoRegionsTotalDuration == 0.75)
    #expect(state.sourceTimeForPreviewElapsed(0) == 0.5)
    #expect(state.sourceTimeForPreviewElapsed(0.25) == 1)
    state.captionSegments = [CaptionSegment(startSeconds: 0.75, endSeconds: 1.25, text: "Voice")]
    state.captionAudioSource = .microphone
    #expect(state.subtitleSegmentsForExport.first?.startSeconds == 0.25)
    #expect(state.subtitleSegmentsForExport.first?.endSeconds == 0.75)
    state.captionAudioSource = .system
    #expect(state.subtitleSegmentsForExport.first?.startSeconds == 0.125)
    #expect(state.subtitleSegmentsForExport.first?.endSeconds == 0.5)
  }

  @Test func seeksSelectRateWithoutStartingPlaybackAndResetAfterRegion() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let result = try await ProjectFixtures.recordingResult(in: dir, webcam: true, systemAudio: true, microphone: true, cursor: false)
    let player = SyncedPlayerController(result: result)
    await player.loadDuration()
    await player.computeDriftRatios()
    defer { player.teardown() }
    player.speedRegions = [SpeedRegionData(startSeconds: 0.25, endSeconds: 1.5, rate: 16)]
    player.seek(to: CMTime(seconds: 1, preferredTimescale: 600))
    #expect(player.playbackRate == 16)
    #expect(player.webcamSourceTime(for: 1) == 0.296875)
    player.play()
    #expect(player.externalAudio.playbackRate == 1)
    #expect(player.webcamPlayer?.rate == 1)
    player.pause()
    #expect(!player.isPlaying)
    player.seek(to: CMTime(seconds: 1.5, preferredTimescale: 600))
    #expect(player.playbackRate == 1)
  }
}
