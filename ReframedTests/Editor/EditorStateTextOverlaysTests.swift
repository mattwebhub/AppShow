import CoreMedia
import Foundation
import Testing

@testable import Reframed

@MainActor
@Suite(.serialized)
struct EditorStateTextOverlaysTests {
  private func makeState() async throws -> (EditorState, URL) {
    let dir = try TestPaths.makeTemporaryDirectory()
    let screenURL = try await VideoFixtures.screenMovie(duration: 6, container: .mov, in: dir, name: "screen-6s")
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
    return (state, dir)
  }

  private func near(_ a: Double, _ b: Double, tolerance: Double = 0.01) -> Bool {
    abs(a - b) <= tolerance
  }

  @Test func addOverlayAtTimeCreatesThreeSecondRegion() async throws {
    let (state, dir) = try await makeState()
    defer { TestPaths.remove(dir) }
    #expect(state.textOverlays.isEmpty)
    #expect(!state.showOverlayTrack)

    let added = try #require(state.addTextOverlay(atTime: 1.0))

    #expect(state.textOverlays.count == 1)
    #expect(state.showOverlayTrack)
    #expect(near(added.startSeconds, 1.0))
    #expect(near(added.endSeconds, 4.0))
    #expect(added.text == "Title")
    #expect(added.position == .center)
    #expect(state.textOverlays[0].id == added.id)
  }

  @Test func addOverlayNearEndIsPulledBackAndClamped() async throws {
    let (state, dir) = try await makeState()
    defer { TestPaths.remove(dir) }
    let duration = CMTimeGetSeconds(state.duration)

    let added = try #require(state.addTextOverlay(atTime: duration - 1.0))

    #expect(near(added.startSeconds, duration - 3.0))
    #expect(near(added.endSeconds, duration))

    let late = try #require(state.addTextOverlay(atTime: duration + 5))
    #expect(near(late.endSeconds, duration))
    #expect(near(late.startSeconds, duration - 3.0))
  }

  @Test func overlaysMayOverlapInTime() async throws {
    let (state, dir) = try await makeState()
    defer { TestPaths.remove(dir) }

    let first = try #require(state.addTextOverlay(atTime: 1.0))
    let second = try #require(state.addTextOverlay(atTime: 2.0))

    #expect(state.textOverlays.count == 2)
    #expect(first.id != second.id)
    #expect(second.startSeconds < first.endSeconds)
    #expect(state.textOverlays.map(\.startSeconds) == [1.0, 2.0])
    #expect(state.activeTextOverlays(at: 2.5).count == 2)
    #expect(state.activeTextOverlays(at: 0.5).isEmpty)
  }

  @Test func updateOverlayChangesFields() async throws {
    let (state, dir) = try await makeState()
    defer { TestPaths.remove(dir) }
    let added = try #require(state.addTextOverlay(atTime: 0))

    state.updateTextOverlay(id: added.id) { overlay in
      overlay.text = "Hello"
      overlay.position = .topLeft
      overlay.fontSize = 0.1
      overlay.showBackground = false
      overlay.entryTransition = .slide
    }

    let updated = try #require(state.textOverlays.first)
    #expect(updated.id == added.id)
    #expect(updated.text == "Hello")
    #expect(updated.position == .topLeft)
    #expect(updated.fontSize == 0.1)
    #expect(updated.showBackground == false)
    #expect(updated.entryTransition == .slide)
    #expect(near(updated.startSeconds, added.startSeconds))
    #expect(near(updated.endSeconds, added.endSeconds))
  }

  @Test func moveAndResizeClampToDurationAndMinimumLength() async throws {
    let (state, dir) = try await makeState()
    defer { TestPaths.remove(dir) }
    let duration = CMTimeGetSeconds(state.duration)
    let added = try #require(state.addTextOverlay(atTime: 1.0))

    state.moveTextOverlay(id: added.id, newStart: -1)
    #expect(near(state.textOverlays[0].startSeconds, 0))
    #expect(near(state.textOverlays[0].endSeconds, 3))

    state.moveTextOverlay(id: added.id, newStart: 100)
    #expect(near(state.textOverlays[0].endSeconds, duration))
    #expect(near(state.textOverlays[0].startSeconds, duration - 3))

    state.updateTextOverlayStart(id: added.id, newStart: 100)
    #expect(near(state.textOverlays[0].startSeconds, duration - TextOverlayData.minimumLength))

    state.updateTextOverlayEnd(id: added.id, newEnd: -5)
    #expect(near(state.textOverlays[0].endSeconds, state.textOverlays[0].startSeconds + TextOverlayData.minimumLength))

    state.updateTextOverlayEnd(id: added.id, newEnd: 100)
    #expect(near(state.textOverlays[0].endSeconds, duration))

    state.updateTextOverlayStart(id: added.id, newStart: -3)
    #expect(near(state.textOverlays[0].startSeconds, 0))
  }

  @Test func removeOverlayDeletesIt() async throws {
    let (state, dir) = try await makeState()
    defer { TestPaths.remove(dir) }
    let first = try #require(state.addTextOverlay(atTime: 0))
    let second = try #require(state.addTextOverlay(atTime: 1))

    state.removeTextOverlay(id: first.id)

    #expect(state.textOverlays.map(\.id) == [second.id])
    state.removeTextOverlay(id: second.id)
    #expect(state.textOverlays.isEmpty)
    #expect(!state.showOverlayTrack)
  }

  @Test func snapshotRoundTripRestoresOverlays() async throws {
    let (state, dir) = try await makeState()
    defer { TestPaths.remove(dir) }
    #expect(state.createSnapshot().textOverlays == nil)

    let added = try #require(state.addTextOverlay(atTime: 0.5))
    state.updateTextOverlay(id: added.id) { $0.text = "Persisted" }
    let snapshot = state.createSnapshot()
    #expect(snapshot.textOverlays?.count == 1)

    state.removeTextOverlay(id: added.id)
    #expect(state.textOverlays.isEmpty)

    state.restoreFromSnapshot(snapshot)
    #expect(state.textOverlays.count == 1)
    #expect(state.textOverlays[0].id == added.id)
    #expect(state.textOverlays[0].text == "Persisted")

    var empty = snapshot
    empty.textOverlays = nil
    state.restoreFromSnapshot(empty)
    #expect(state.textOverlays.isEmpty)
  }
}
