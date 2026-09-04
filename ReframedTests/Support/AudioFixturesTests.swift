import AVFoundation
import Testing

@testable import Reframed

struct AudioFixturesTests {
  @Test func mp3FixtureDecodesToAudioTrack() async throws {
    let url = try #require(BundledFixtures.url("sine-1s", extension: "mp3"))
    let asset = AVURLAsset(url: url)
    let tracks = try await asset.loadTracks(withMediaType: .audio)
    #expect(tracks.count == 1)
    let duration = try await asset.load(.duration).seconds
    #expect(abs(duration - 1.0) < 0.1)
    let size = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int ?? 0
    #expect(size > 0 && size <= 10_240)
  }
}
