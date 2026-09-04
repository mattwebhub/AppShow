import Foundation
import Testing

@testable import AppShow

struct ExternalAudioTrackDataTests {
  private func track(_ n: Int = 1) -> ExternalAudioTrackData {
    ExternalAudioTrackData(
      id: ProjectFixtures.fixedUUID(n),
      fileName: "audio-0badf00d.wav",
      displayName: "Loop",
      sourceDurationSeconds: 12,
      timelineStartSeconds: 3,
      fileInSeconds: 1,
      fileOutSeconds: 4,
      volume: 0.75,
      muted: true,
      fadeInSeconds: 0.5,
      fadeOutSeconds: 1.5
    )
  }

  @Test func decodesTrackWithoutOptionalFieldsUsingDefaults() throws {
    let json = """
      {
        "id": "00000000-0000-0000-0000-000000000001",
        "fileName": "audio-0badf00d.mp3",
        "displayName": "Song",
        "sourceDurationSeconds": 90.5,
        "timelineStartSeconds": 2,
        "fileOutSeconds": 30
      }
      """
    let decoded = try JSONDecoder().decode(ExternalAudioTrackData.self, from: Data(json.utf8))
    #expect(decoded.id == ProjectFixtures.fixedUUID(1))
    #expect(decoded.fileName == "audio-0badf00d.mp3")
    #expect(decoded.displayName == "Song")
    #expect(decoded.sourceDurationSeconds == 90.5)
    #expect(decoded.timelineStartSeconds == 2)
    #expect(decoded.fileInSeconds == 0)
    #expect(decoded.fileOutSeconds == 30)
    #expect(decoded.volume == 1)
    #expect(decoded.muted == false)
    #expect(decoded.fadeInSeconds == 0)
    #expect(decoded.fadeOutSeconds == 0)
  }

  @Test func roundTripsThroughEditorStateData() throws {
    var state = ProjectFixtures.fullEditorState()
    state.externalAudioTracks = [track(1), track(2)]
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(state)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(EditorStateData.self, from: data)
    #expect(decoded.externalAudioTracks == [track(1), track(2)])
  }

  @Test func legacyEditorStateWithoutExternalAudioDecodesToNil() throws {
    let json = ProjectFixtures.legacyV1ProjectJSON()
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let metadata = try decoder.decode(ProjectMetadata.self, from: Data(json.utf8))
    let state = try #require(metadata.editorState)
    #expect(state.externalAudioTracks == nil)
  }

  @Test func timelineEndIsStartPlusTrimmedLength() {
    #expect(track().timelineEndSeconds == 6)
  }

  @Test func effectiveVolumeIsZeroWhenMuted() {
    var t = track()
    t.volume = 1.5
    t.muted = true
    #expect(t.effectiveVolume == 0)
    t.muted = false
    #expect(t.effectiveVolume == 1.5)
  }
}
