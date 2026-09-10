import CoreMedia
import Foundation
import Testing

@testable import AppShow

@MainActor
@Suite(.serialized)
struct EditorStatePlaybackTests {
  @Test func togglePlayPauseFromGapSeeksToNextSliceInEditMode() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let result = try await ProjectFixtures.recordingResult(
      in: dir,
      webcam: false,
      systemAudio: false,
      microphone: false,
      cursor: false
    )
    let state = EditorState(result: result)
    await state.setup()
    state.videoRegions = [
      VideoRegionData(startSeconds: 0, endSeconds: 0.5),
      VideoRegionData(startSeconds: 1.5, endSeconds: 2),
    ]
    state.isPreviewMode = false
    state.seek(to: CMTime(seconds: 1.0, preferredTimescale: 600))
    state.togglePlayPause()
    #expect(abs(CMTimeGetSeconds(state.currentTime) - 1.5) < 0.01)
    #expect(state.isPlaying)
    state.pause()
    #expect(!state.isPlaying)
  }

  @Test func syncVideoRegionsEnablesGapSkippingOnlyWhenCutsExist() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let result = try await ProjectFixtures.recordingResult(
      in: dir,
      webcam: false,
      systemAudio: false,
      microphone: false,
      cursor: false
    )
    let state = EditorState(result: result)
    await state.setup()
    state.syncVideoRegionsToPlayer()
    #expect(!state.playerController.skipsGaps)
    state.videoRegions = [
      VideoRegionData(startSeconds: 0, endSeconds: 0.5),
      VideoRegionData(startSeconds: 1.5, endSeconds: 2),
    ]
    state.syncVideoRegionsToPlayer()
    #expect(state.playerController.skipsGaps)
  }
}
