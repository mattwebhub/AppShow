import AVFoundation
import Testing

@testable import Reframed

struct FixtureTests {
  @Test func sineWaveFixtureHasRequestedDuration() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let url = try AudioFixtures.sineWave(frequency: 440, duration: 2, container: .wav, in: dir)
    let asset = AVURLAsset(url: url)
    let duration = try await asset.load(.duration)
    #expect(abs(duration.seconds - 2.0) < 0.01)
    let tracks = try await asset.loadTracks(withMediaType: .audio)
    #expect(tracks.count == 1)
  }

  @Test func aacFixtureIsDecodable() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let url = try AudioFixtures.sineWave(frequency: 880, duration: 1, channels: 2, container: .m4a, in: dir)
    let tracks = try await AVURLAsset(url: url).loadTracks(withMediaType: .audio)
    #expect(tracks.count == 1)
  }
}
