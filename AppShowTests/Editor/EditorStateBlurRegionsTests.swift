import CoreMedia
import Foundation
import Testing

@testable import AppShow

@MainActor
@Suite(.serialized)
struct EditorStateBlurRegionsTests {
  private func makeState() async throws -> (EditorState, URL) {
    let directory = try TestPaths.makeTemporaryDirectory()
    let screenURL = try await VideoFixtures.screenMovie(
      duration: 6,
      container: .mov,
      in: directory,
      name: "screen-6s"
    )
    let result = RecordingResult(
      screenVideoURL: screenURL,
      webcamVideoURL: nil,
      systemAudioURL: nil,
      microphoneAudioURL: nil,
      cursorMetadataURL: nil,
      screenSize: VideoFixtures.screenSize,
      webcamSize: nil,
      fps: VideoFixtures.fps,
      captureQuality: .standard,
      isHDR: false
    )
    let state = EditorState(result: result)
    await state.setup()
    return (state, directory)
  }

  private func near(_ lhs: Double, _ rhs: Double) -> Bool {
    abs(lhs - rhs) < 0.01
  }

  @Test func addClampsTheRectAndCreatesATimedRegion() async throws {
    let (state, directory) = try await makeState()
    defer { TestPaths.remove(directory) }

    let added = state.addBlurRegion(
      atTime: 1,
      rect: CGRect(x: 0.9, y: 0.8, width: 0.5, height: 0.5)
    )

    #expect(near(added.startSeconds, 1))
    #expect(near(added.endSeconds, 4))
    #expect(abs(added.width - 0.1) < 0.0001)
    #expect(abs(added.height - 0.2) < 0.0001)
    #expect(state.activeBlurRegions(at: 2).map(\.id) == [added.id])
    #expect(state.showOverlayTrack)
  }

  @Test func updateMoveResizeAndRemoveAreBounded() async throws {
    let (state, directory) = try await makeState()
    defer { TestPaths.remove(directory) }
    let added = state.addBlurRegion(atTime: 1)

    state.updateBlurRegion(id: added.id) {
      $0.x = -1
      $0.radius = 400
    }
    #expect(state.blurRegions[0].x == 0)
    #expect(state.blurRegions[0].radius == 100)

    state.moveBlurRegion(id: added.id, newStart: 100)
    #expect(near(state.blurRegions[0].endSeconds, 6))
    state.updateBlurRegionStart(id: added.id, newStart: 100)
    #expect(near(state.blurRegions[0].endSeconds - state.blurRegions[0].startSeconds, BlurRegionData.minimumLength))
    state.updateBlurRegionEnd(id: added.id, newEnd: 100)
    #expect(near(state.blurRegions[0].endSeconds, 6))

    state.removeBlurRegion(id: added.id)
    #expect(state.blurRegions.isEmpty)
  }

  @Test func snapshotRoundTripRestoresBlurRegions() async throws {
    let (state, directory) = try await makeState()
    defer { TestPaths.remove(directory) }
    let added = state.addBlurRegion(atTime: 0.5)
    let snapshot = state.createSnapshot()

    state.removeBlurRegion(id: added.id)
    state.restoreFromSnapshot(snapshot)

    #expect(state.blurRegions == [added])
  }
}
