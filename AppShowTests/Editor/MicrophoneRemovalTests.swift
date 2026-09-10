import Foundation
import Testing

@testable import AppShow

@MainActor
@Suite(.serialized)
struct MicrophoneRemovalTests {
  @Test func removalIsImmediateUndoableAndPreservesSource() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let result = try await ProjectFixtures.recordingResult(in: dir, webcam: false, systemAudio: true, microphone: true, cursor: false)
    let state = EditorState(result: result)
    await state.setup()
    defer { state.teardown() }
    let url = try #require(result.microphoneAudioURL)
    let original = try Data(contentsOf: url)
    let regions = state.micAudioRegions
    state.removeMicrophone()
    #expect(state.effectiveMicAudioVolume == 0)
    #expect(state.createSnapshot().audioSettings?.micAudioMuted == true)
    #expect(state.systemAudioMuted == false)
    #expect(state.micAudioRegions == regions)
    let snapshot = state.createSnapshot()
    state.micAudioMuted = false
    state.restoreFromSnapshot(try JSONDecoder().decode(EditorStateData.self, from: JSONEncoder().encode(snapshot)))
    #expect(state.effectiveMicAudioVolume == 0)
    state.undo()
    #expect(state.effectiveMicAudioVolume == 1)
    #expect(try Data(contentsOf: url) == original)
  }
}
