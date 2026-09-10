import Foundation
import Testing

@testable import AppShow

struct ExternalAudioImporterTests {
  private func makeBundle(in dir: URL) throws -> URL {
    let bundle = dir.appendingPathComponent("x.frm", isDirectory: true)
    try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
    return bundle
  }

  private func audioFiles(in bundle: URL) throws -> [String] {
    try FileManager.default.contentsOfDirectory(atPath: bundle.path).filter { $0.hasPrefix("audio-") }.sorted()
  }

  private func matchesAudioName(_ name: String, extension ext: String) -> Bool {
    name.range(of: "^audio-[0-9a-f]{8}\\.\(ext)$", options: .regularExpression) != nil
  }

  @Test func copiesFileIntoBundleWithAudioPrefixAndHash() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let bundle = try makeBundle(in: dir)
    let source = try AudioFixtures.sineWave(frequency: 440, in: dir, name: "My Song")

    let imported = try await ExternalAudioImporter.import(sourceURL: source, into: bundle)

    #expect(matchesAudioName(imported.fileName, extension: "wav"))
    #expect(imported.displayName == "My Song")
    #expect(abs(imported.durationSeconds - 2.0) < 0.01)
    #expect(FileManager.default.fileExists(atPath: bundle.appendingPathComponent(imported.fileName).path))
    #expect(FileManager.default.fileExists(atPath: source.path))
    #expect(try audioFiles(in: bundle) == [imported.fileName])
  }

  @Test func secondImportOfIdenticalFileReusesExistingCopy() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let bundle = try makeBundle(in: dir)
    let first = try AudioFixtures.sineWave(frequency: 440, in: dir, name: "first")
    let second = dir.appendingPathComponent("second.wav")
    try FileManager.default.copyItem(at: first, to: second)

    let a = try await ExternalAudioImporter.import(sourceURL: first, into: bundle)
    let b = try await ExternalAudioImporter.import(sourceURL: second, into: bundle)

    #expect(a.fileName == b.fileName)
    #expect(b.displayName == "second")
    #expect(try audioFiles(in: bundle) == [a.fileName])
  }

  @Test func differentContentGetsDifferentFileName() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let bundle = try makeBundle(in: dir)
    let low = try AudioFixtures.sineWave(frequency: 440, in: dir, name: "low")
    let high = try AudioFixtures.sineWave(frequency: 880, in: dir, name: "high")

    let a = try await ExternalAudioImporter.import(sourceURL: low, into: bundle)
    let b = try await ExternalAudioImporter.import(sourceURL: high, into: bundle)

    #expect(a.fileName != b.fileName)
    #expect(try audioFiles(in: bundle).count == 2)
  }

  @Test func rejectsFileWithoutAudioTrack() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let bundle = try makeBundle(in: dir)
    let fake = dir.appendingPathComponent("notes.wav")
    try Data("this is not audio".utf8).write(to: fake)

    await #expect(throws: CaptureError.self) {
      try await ExternalAudioImporter.import(sourceURL: fake, into: bundle)
    }
    #expect(try audioFiles(in: bundle).isEmpty)
  }

  @Test func importsM4aAndMp3() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let bundle = try makeBundle(in: dir)
    let m4a = try AudioFixtures.sineWave(frequency: 440, duration: 1, container: .m4a, in: dir, name: "tone")
    let mp3Source = try #require(BundledFixtures.url("sine-1s", extension: "mp3"))
    let mp3 = dir.appendingPathComponent("Tone.MP3")
    try FileManager.default.copyItem(at: mp3Source, to: mp3)

    let a = try await ExternalAudioImporter.import(sourceURL: m4a, into: bundle)
    let b = try await ExternalAudioImporter.import(sourceURL: mp3, into: bundle)

    #expect(matchesAudioName(a.fileName, extension: "m4a"))
    #expect(matchesAudioName(b.fileName, extension: "mp3"))
    #expect(abs(a.durationSeconds - 1.0) < 0.1)
    #expect(abs(b.durationSeconds - 1.0) < 0.1)
    #expect(try audioFiles(in: bundle).count == 2)
  }
}
