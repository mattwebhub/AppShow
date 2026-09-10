import Foundation
import Testing

@testable import Reframed

@MainActor
@Suite(.serialized)
struct ExternalAudioWaveformStoreTests {
  private func readSidecar(_ url: URL) throws -> [Float] {
    try JSONDecoder().decode([Float].self, from: Data(contentsOf: url))
  }

  @Test func generatesTwoHundredSamplesForSineFixture() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let url = try AudioFixtures.sineWave(frequency: 440, duration: 2, channels: 2, in: dir, name: "audio-1234abcd")
    let sidecar = ExternalAudioWaveformStore.sidecarURL(for: url)
    #expect(sidecar.lastPathComponent == "audio-1234abcd.waveform.json")
    let store = ExternalAudioWaveformStore()
    let id = UUID()

    await store.generate(for: id, url: url)

    let samples = try #require(store.samples[id])
    #expect(samples.count == 200)
    #expect(samples.allSatisfy { $0 >= 0 && $0 <= 1 })
    #expect(samples.max() == 1)
    #expect(samples.min()! > 0.9)
    #expect(!store.isGenerating(id))
    let cached = try readSidecar(sidecar)
    #expect(cached.count == 200)
    #expect(zip(cached, samples).allSatisfy { abs($0 - $1) < 0.0001 })
  }

  @Test func loadsSidecarInsteadOfDecodingWhenPresent() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let url = dir.appendingPathComponent("audio-cafef00d.wav")
    try Data("not audio".utf8).write(to: url)
    let zeros = [Float](repeating: 0, count: 200)
    try JSONEncoder().encode(zeros).write(to: ExternalAudioWaveformStore.sidecarURL(for: url))
    let store = ExternalAudioWaveformStore()
    let id = UUID()

    await store.generate(for: id, url: url)

    #expect(store.samples[id] == zeros)
  }

  @Test func staleSidecarIsRegenerated() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let url = try AudioFixtures.sineWave(frequency: 440, duration: 1, in: dir, name: "audio-0badf00d")
    let sidecar = ExternalAudioWaveformStore.sidecarURL(for: url)
    try JSONEncoder().encode([Float](repeating: 0, count: 5)).write(to: sidecar)
    let store = ExternalAudioWaveformStore()
    let id = UUID()

    await store.generate(for: id, url: url)

    #expect(store.samples[id]?.count == 200)
    #expect(try readSidecar(sidecar).count == 200)
    store.remove(id)
    #expect(store.samples[id] == nil)
  }

  @Test func undecodableFileWithoutSidecarYieldsNoSamples() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let url = dir.appendingPathComponent("audio-00000000.wav")
    try Data("not audio".utf8).write(to: url)
    let store = ExternalAudioWaveformStore()
    let id = UUID()

    await store.generate(for: id, url: url)

    #expect(store.samples[id] == nil)
    #expect(!FileManager.default.fileExists(atPath: ExternalAudioWaveformStore.sidecarURL(for: url).path))
  }
}
