import Foundation
import Testing

@testable import AppShow

@MainActor
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["APPSHOW_RUN_AUDIO_ENGINE_TESTS"] == "1"))
struct ExternalAudioPreviewEngineTests {
  private func track(id: UUID, fileName: String) -> ExternalAudioTrackData {
    ExternalAudioTrackData(
      id: id,
      fileName: fileName,
      displayName: "Bed",
      sourceDurationSeconds: 2,
      timelineStartSeconds: 0.5,
      fileOutSeconds: 2,
      volume: 0.8,
      fadeInSeconds: 1
    )
  }

  @Test func engineStartsAndStopsWithoutOutputDevice() throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let url = try AudioFixtures.sineWave(frequency: 440, duration: 2, in: dir, name: "audio-0badf00d")
    let id = UUID()
    let engine = ExternalAudioPreviewEngine()

    engine.setTracks([track(id: id, fileName: url.lastPathComponent)], urls: [id: url], currentTime: 0)
    #expect(engine.trackIDs == [id])

    engine.start(at: 0)
    engine.tick(at: 1.0)
    let volume = try #require(engine.nodeVolume(for: id))
    #expect(abs(volume - 0.8 * 0.5) < 0.001)

    engine.tick(at: 1.5)
    #expect(abs(try #require(engine.nodeVolume(for: id)) - 0.8) < 0.001)

    engine.stop()
    engine.start(at: 1.2)
    engine.tick(at: 3)
    #expect(engine.nodeVolume(for: id) == 0)

    engine.setTracks([], urls: [:], currentTime: 3)
    #expect(engine.trackIDs.isEmpty)
    engine.teardown()
  }

  @Test func volumeChangesApplyWithoutReschedulingAndPositionChangesReschedule() throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let url = try AudioFixtures.sineWave(frequency: 440, duration: 2, in: dir, name: "audio-0badf00d")
    let id = UUID()
    var t = track(id: id, fileName: url.lastPathComponent)
    let engine = ExternalAudioPreviewEngine()
    engine.setTracks([t], urls: [id: url], currentTime: 0)
    engine.start(at: 1.5)
    let scheduledBefore = engine.scheduleCount

    t.volume = 0.25
    engine.setTracks([t], urls: [id: url], currentTime: 1.5)
    #expect(engine.scheduleCount == scheduledBefore)
    #expect(abs(try #require(engine.nodeVolume(for: id)) - 0.25) < 0.001)

    t.timelineStartSeconds = 0
    engine.setTracks([t], urls: [id: url], currentTime: 1.5)
    #expect(engine.scheduleCount == scheduledBefore + 1)
    engine.teardown()
  }
}
