import CoreMedia
import Foundation
import Testing

@testable import AppShow

@MainActor
@Suite(.serialized)
struct EditorStateVideoRegionsTests {
  private func makeState() async throws -> (EditorState, URL) {
    let dir = try TestPaths.makeTemporaryDirectory()
    let result = try await ProjectFixtures.recordingResult(
      in: dir,
      webcam: false,
      systemAudio: false,
      microphone: false,
      cursor: false
    )
    let state = EditorState(result: result)
    await state.setup()
    return (state, dir)
  }

  private func region(_ start: Double, _ end: Double) -> VideoRegionData {
    VideoRegionData(startSeconds: start, endSeconds: end)
  }

  @Test func previewElapsedTimeMatchesCutTimeline() async throws {
    let (state, dir) = try await makeState()
    defer { TestPaths.remove(dir) }
    state.videoRegions = [region(0, 0.5), region(1.5, 2)]
    state.seek(to: CMTime(seconds: 1.75, preferredTimescale: 600))
    #expect(abs(state.previewElapsedTime - 0.75) < 0.01)
    #expect(abs(state.sourceTimeForPreviewElapsed(0.75) - 1.75) < 0.01)
    #expect(abs(state.videoRegionsTotalDuration - 1.0) < 0.01)
    #expect(state.hasVideoRegionCuts)
    #expect(state.showCutTrack)
  }

  @Test func splitVideoRegionAtPlayheadAddsSliceAndKeepsCurrentTime() async throws {
    let (state, dir) = try await makeState()
    defer { TestPaths.remove(dir) }
    #expect(state.videoRegions.count == 1)
    #expect(!state.showCutTrack)
    state.seek(to: CMTime(seconds: 1.0, preferredTimescale: 600))
    state.splitVideoRegion(atTime: 1.0)
    #expect(state.videoRegions.count == 2)
    #expect(abs(state.videoRegions[0].endSeconds - 1.0) < 0.001)
    #expect(abs(state.videoRegions[1].startSeconds - 1.0) < 0.001)
    #expect(abs(CMTimeGetSeconds(state.currentTime) - 1.0) < 0.01)
    #expect(state.showCutTrack)
    #expect(!state.hasVideoRegionCuts)
  }

  @Test func clearVideoCutsRestoresSingleFullSlice() async throws {
    let (state, dir) = try await makeState()
    defer { TestPaths.remove(dir) }
    state.videoRegions = [region(0, 0.5), region(1.5, 2)]
    state.clearVideoCuts()
    #expect(state.videoRegions.count == 1)
    #expect(state.videoRegions[0].startSeconds == 0)
    #expect(abs(state.videoRegions[0].endSeconds - CMTimeGetSeconds(state.duration)) < 0.001)
    #expect(!state.showCutTrack)
  }

  @Test func restoreFromSnapshotNormalizesOverlappingVideoRegions() async throws {
    let (state, dir) = try await makeState()
    defer { TestPaths.remove(dir) }
    var snapshot = state.createSnapshot()
    snapshot.videoRegions = [region(1.2, 2.5), region(-1, 0.8), region(0.5, 1.0)]
    state.restoreFromSnapshot(snapshot)
    #expect(state.videoRegions.map(\.startSeconds) == [0, 1.2])
    #expect(state.videoRegions.map(\.endSeconds) == [1.0, 2.0])
  }

  @Test func undoAfterSplitRestoresSingleSlice() async throws {
    let (state, dir) = try await makeState()
    defer { TestPaths.remove(dir) }
    state.history.pushSnapshot(state.createSnapshot())
    state.splitVideoRegion(atTime: 1.0)
    state.history.pushSnapshot(state.createSnapshot())
    #expect(state.videoRegions.count == 2)
    state.undo()
    #expect(state.videoRegions.count == 1)
    state.redo()
    #expect(state.videoRegions.count == 2)
  }
}
