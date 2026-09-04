import CoreMedia
import Foundation
import Testing

@testable import Reframed

@MainActor
@Suite(.serialized)
struct EditorStateExternalAudioTests {
  private func makeProject(in dir: URL) async throws -> ReframedProject {
    let sources = dir.appendingPathComponent("sources", isDirectory: true)
    try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)
    let result = try await ProjectFixtures.recordingResult(
      in: sources,
      webcam: false,
      systemAudio: false,
      microphone: false,
      cursor: false
    )
    return try ReframedProject.create(from: result, fps: result.fps, captureMode: .entireScreen, in: dir, cleanupTemp: false)
  }

  private func track(fileName: String, id: Int) -> ExternalAudioTrackData {
    ExternalAudioTrackData(
      id: ProjectFixtures.fixedUUID(id),
      fileName: fileName,
      displayName: fileName,
      sourceDurationSeconds: 2,
      timelineStartSeconds: 0.5,
      fileOutSeconds: 1
    )
  }

  @Test func newTrackIsPlacedAtPlayheadAndClampedToRecording() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let project = try await makeProject(in: dir)
    let state = EditorState(project: project)
    await state.setup()
    defer { state.teardown() }
    let source = try AudioFixtures.sineWave(frequency: 440, duration: 2, in: dir, name: "Bed")

    state.seek(to: CMTime(seconds: 1.5, preferredTimescale: 600))
    try await state.importExternalAudio(from: source)

    let added = try #require(state.externalAudioTracks.first)
    #expect(state.externalAudioTracks.count == 1)
    #expect(abs(added.timelineStartSeconds - 1.5) < 0.01)
    #expect(added.fileInSeconds == 0)
    #expect(abs(added.fileOutSeconds - 0.5) < 0.01)
    #expect(abs(added.sourceDurationSeconds - 2.0) < 0.01)
    #expect(added.displayName == "Bed")
    #expect(added.fileName.hasPrefix("audio-"))
    #expect(FileManager.default.fileExists(atPath: project.bundleURL.appendingPathComponent(added.fileName).path))
    #expect(state.externalAudioURL(for: added) == project.bundleURL.appendingPathComponent(added.fileName))
    #expect(state.createSnapshot().externalAudioTracks == [added])
    #expect(state.history.entries.count == 2)
  }

  @Test func importThrowsWhenTheStateHasNoProjectBundle() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let result = try await ProjectFixtures.recordingResult(in: dir, webcam: false, systemAudio: false, microphone: false, cursor: false)
    let state = EditorState(result: result)
    await state.setup()
    defer { state.teardown() }
    let source = try AudioFixtures.sineWave(frequency: 440, duration: 1, in: dir, name: "Bed")

    await #expect(throws: CaptureError.self) {
      try await state.importExternalAudio(from: source)
    }
    #expect(state.externalAudioTracks.isEmpty)
  }

  @Test func openingProjectDropsTrackWhoseFileIsMissing() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let project = try await makeProject(in: dir)
    let source = try AudioFixtures.sineWave(frequency: 440, duration: 2, in: dir, name: "Bed")
    let imported = try await ExternalAudioImporter.import(sourceURL: source, into: project.bundleURL)
    var saved = ProjectFixtures.editorState()
    saved.externalAudioTracks = [track(fileName: "audio-deadbeef.wav", id: 1), track(fileName: imported.fileName, id: 2)]
    try project.saveEditorState(saved)

    let reopened = try ReframedProject.open(at: project.bundleURL)
    let state = EditorState(project: reopened)
    await state.setup()
    defer { state.teardown() }

    #expect(state.externalAudioTracks.map(\.id) == [ProjectFixtures.fixedUUID(2)])
  }

  @Test func editsGoThroughTrackMathAndRemoveDropsTheTrack() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let project = try await makeProject(in: dir)
    let state = EditorState(project: project)
    await state.setup()
    defer { state.teardown() }
    let source = try AudioFixtures.sineWave(frequency: 440, duration: 2, in: dir, name: "Bed")
    state.seek(to: .zero)
    try await state.importExternalAudio(from: source)
    let id = try #require(state.externalAudioTracks.first?.id)

    state.moveExternalAudioTrack(id: id, newStart: 5)
    #expect(state.externalAudioTracks[0].timelineStartSeconds == 0)
    state.trimExternalAudioTrackEnd(id: id, newEnd: 1)
    #expect(abs(state.externalAudioTracks[0].fileOutSeconds - 1) < 0.001)
    state.trimExternalAudioTrackStart(id: id, newStart: 0.25)
    #expect(abs(state.externalAudioTracks[0].fileInSeconds - 0.25) < 0.001)
    #expect(abs(state.externalAudioTracks[0].timelineStartSeconds - 0.25) < 0.001)
    state.moveExternalAudioTrack(id: id, newStart: 1)
    #expect(abs(state.externalAudioTracks[0].timelineStartSeconds - 1) < 0.001)
    #expect(abs(state.externalAudioTracks[0].timelineEndSeconds - 1.75) < 0.001)

    state.setExternalAudioTrackVolume(id: id, volume: 0.5)
    state.setExternalAudioTrackMuted(id: id, muted: true)
    state.setExternalAudioTrackFadeIn(id: id, seconds: 0.2)
    state.setExternalAudioTrackFadeOut(id: id, seconds: -1)
    #expect(state.externalAudioTracks[0].volume == 0.5)
    #expect(state.externalAudioTracks[0].muted)
    #expect(state.externalAudioTracks[0].fadeInSeconds == 0.2)
    #expect(state.externalAudioTracks[0].fadeOutSeconds == 0)

    state.removeExternalAudioTrack(id: id)
    #expect(state.externalAudioTracks.isEmpty)
    #expect(state.createSnapshot().externalAudioTracks == nil)
  }
}
