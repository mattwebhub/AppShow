import CoreMedia
import Foundation
import Testing

@testable import AppShow

struct EditorStateExportConfigTests {
  private let bundleURL = URL(fileURLWithPath: "/tmp/appshow-tests/example.frm", isDirectory: true)

  private func track(_ n: Int, muted: Bool = false, volume: Float = 1) -> ExternalAudioTrackData {
    ExternalAudioTrackData(
      id: ProjectFixtures.fixedUUID(n),
      fileName: "audio-0000000\(n).wav",
      displayName: "Track \(n)",
      sourceDurationSeconds: 12,
      timelineStartSeconds: 3,
      fileInSeconds: 1,
      fileOutSeconds: 4,
      volume: volume,
      muted: muted,
      fadeInSeconds: 0.5,
      fadeOutSeconds: 1.5
    )
  }

  @Test func exportConfigCarriesTracksWithMuteAsZeroVolume() throws {
    let tracks = [track(1, muted: true), track(2, volume: 0.75), track(3, volume: 0)]
    let exported = EditorState.exportExternalAudioTracks(from: tracks, bundleURL: bundleURL)
    let only = try #require(exported.first)
    #expect(exported.count == 1)
    #expect(only.url == bundleURL.appendingPathComponent("audio-00000002.wav"))
    #expect(only.volume == 0.75)
    #expect(abs(only.fileStart.seconds - 1) < 0.001)
    #expect(abs(only.timelineRange.start.seconds - 3) < 0.001)
    #expect(abs(only.timelineRange.end.seconds - 6) < 0.001)
    #expect(abs(only.fadeIn.seconds - 0.5) < 0.001)
    #expect(abs(only.fadeOut.seconds - 1.5) < 0.001)
  }

  @Test func exportConfigIsEmptyWithoutProjectBundle() {
    #expect(EditorState.exportExternalAudioTracks(from: [track(1)], bundleURL: nil).isEmpty)
  }
}
