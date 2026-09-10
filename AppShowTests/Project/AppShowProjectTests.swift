import Foundation
import Testing

@testable import AppShow

@Suite(.serialized)
struct AppShowProjectTests {
  private func makeProject(
    in dir: URL,
    captureMode: CaptureMode = .entireScreen,
    sourceName: String? = nil,
    screenContainer: VideoFixtures.Container = .mov,
    webcam: Bool = true,
    cursor: Bool = true
  ) async throws -> (AppShowProject, RecordingResult) {
    let sources = dir.appendingPathComponent("sources", isDirectory: true)
    try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)
    let result = try await ProjectFixtures.recordingResult(in: sources, screenContainer: screenContainer, webcam: webcam, cursor: cursor)
    let projects = dir.appendingPathComponent("projects", isDirectory: true)
    let project = try AppShowProject.create(
      from: result,
      fps: result.fps,
      captureMode: captureMode,
      sourceName: sourceName,
      in: projects,
      cleanupTemp: false
    )
    return (project, result)
  }

  private func readMetadata(_ project: AppShowProject) throws -> ProjectMetadata {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(ProjectMetadata.self, from: Data(contentsOf: project.bundleURL.appendingPathComponent("project.json")))
  }

  @Test func createMovesRecordingFilesIntoBundleAndWritesProjectJSON() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let before = Date()
    let (project, result) = try await makeProject(in: dir)
    let fm = FileManager.default
    let bundleName = project.bundleURL.lastPathComponent
    #expect(bundleName.hasPrefix("Screen-"))
    #expect(bundleName.hasSuffix(".appshow"))
    #expect(bundleName == "\(project.name).appshow")
    #expect(project.bundleURL.deletingLastPathComponent().lastPathComponent == "projects")
    let expected = ["screen.mov", "webcam.mp4", "system-audio.m4a", "mic-audio.m4a", "cursor-metadata.json", "project.json"]
    let contents = try fm.contentsOfDirectory(atPath: project.bundleURL.path).sorted()
    #expect(contents == expected.sorted())
    #expect(!fm.fileExists(atPath: result.screenVideoURL.path))
    #expect(!fm.fileExists(atPath: result.webcamVideoURL!.path))
    #expect(!fm.fileExists(atPath: result.systemAudioURL!.path))
    #expect(!fm.fileExists(atPath: result.microphoneAudioURL!.path))
    #expect(!fm.fileExists(atPath: result.cursorMetadataURL!.path))
    let metadata = try readMetadata(project)
    #expect(metadata.version == 1)
    #expect(metadata.name == project.name)
    #expect(metadata.createdAt >= before.addingTimeInterval(-1))
    #expect(metadata.fps == 30)
    #expect(metadata.screenSize.cgSize == VideoFixtures.screenSize)
    #expect(metadata.webcamSize?.cgSize == VideoFixtures.webcamSize)
    #expect(metadata.hasSystemAudio == true)
    #expect(metadata.hasMicrophoneAudio == true)
    #expect(metadata.hasCursorMetadata == true)
    #expect(metadata.hasWebcam == true)
    #expect(metadata.captureMode == .entireScreen)
    #expect(metadata.captureQuality == "standard")
    #expect(metadata.isHDR == false)
    #expect(metadata.editorState == nil)
  }

  @Test func createUsesSanitizedSourceNameAsPrefix() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let (project, _) = try await makeProject(in: dir, captureMode: .selectedWindow, sourceName: "Safari (Main) / Tab")
    #expect(project.bundleURL.lastPathComponent.hasPrefix("Safari-Main--Tab-"))
  }

  @Test(arguments: [
    (CaptureMode.entireScreen, "Screen-"), (.selectedWindow, "Window-"), (.selectedArea, "Area-"), (.device, "Device-"),
    (.none, "Recording-"),
  ])
  func createFallsBackToCaptureModePrefix(mode: CaptureMode, prefix: String) async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let (project, _) = try await makeProject(in: dir, captureMode: mode, sourceName: "   ", webcam: false, cursor: false)
    #expect(project.bundleURL.lastPathComponent.hasPrefix(prefix))
  }

  @Test func openRestoresMetadataAndOptionalMedia() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let (created, _) = try await makeProject(in: dir)
    let opened = try AppShowProject.open(at: created.bundleURL)
    #expect(opened.bundleURL == created.bundleURL)
    #expect(opened.name == created.name)
    #expect(opened.metadata.fps == 30)
    #expect(opened.metadata.captureMode == .entireScreen)
    #expect(opened.metadata.hasWebcam == true)
    #expect(opened.screenVideoURL.lastPathComponent == "screen.mov")
    #expect(opened.webcamVideoURL?.lastPathComponent == "webcam.mp4")
    #expect(opened.systemAudioURL?.lastPathComponent == "system-audio.m4a")
    #expect(opened.microphoneAudioURL?.lastPathComponent == "mic-audio.m4a")
    #expect(opened.cursorMetadataURL?.lastPathComponent == "cursor-metadata.json")
    #expect(opened.denoisedMicAudioURL == nil)
    let result = opened.recordingResult
    #expect(result.screenVideoURL == opened.screenVideoURL)
    #expect(result.screenSize == VideoFixtures.screenSize)
    #expect(result.captureQuality == .standard)
  }

  @Test func openPrefersScreenMovOverScreenMp4() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let (created, _) = try await makeProject(in: dir, screenContainer: .mp4, webcam: false, cursor: false)
    #expect(try AppShowProject.open(at: created.bundleURL).screenVideoURL.lastPathComponent == "screen.mp4")
    try Data().write(to: created.bundleURL.appendingPathComponent("screen.mov"))
    #expect(try AppShowProject.open(at: created.bundleURL).screenVideoURL.lastPathComponent == "screen.mov")
  }

  @Test func openWithoutMediaReportsNilOptionalFiles() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let sources = dir.appendingPathComponent("sources", isDirectory: true)
    try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)
    let result = try await ProjectFixtures.recordingResult(in: sources, webcam: false, systemAudio: false, microphone: false, cursor: false)
    let project = try AppShowProject.create(from: result, fps: 30, captureMode: .selectedArea, in: dir, cleanupTemp: false)
    let opened = try AppShowProject.open(at: project.bundleURL)
    #expect(opened.webcamVideoURL == nil)
    #expect(opened.systemAudioURL == nil)
    #expect(opened.microphoneAudioURL == nil)
    #expect(opened.cursorMetadataURL == nil)
    #expect(opened.metadata.hasWebcam == false)
    #expect(opened.metadata.hasCursorMetadata == false)
    #expect(opened.metadata.webcamSize == nil)
    #expect(opened.recordingResult.webcamSize == nil)
  }

  @Test func saveEditorStateThenOpenReturnsTheState() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let (project, _) = try await makeProject(in: dir)
    let original = ProjectFixtures.fullEditorState()
    try project.saveEditorState(original)
    let opened = try AppShowProject.open(at: project.bundleURL)
    let state = try #require(opened.metadata.editorState)
    #expect(state.trimStartSeconds == original.trimStartSeconds)
    #expect(state.trimEndSeconds == original.trimEndSeconds)
    #expect(state.backgroundStyle == original.backgroundStyle)
    #expect(state.cameraLayout == original.cameraLayout)
    #expect(state.cursorSettings == original.cursorSettings)
    #expect(state.zoomSettings == original.zoomSettings)
    #expect(state.cameraRegions == original.cameraRegions)
    #expect(state.videoRegions == original.videoRegions)
    #expect(state.captionSettings == original.captionSettings)
    #expect(state.captionSegments == original.captionSegments)
    #expect(state.spotlightRegions == original.spotlightRegions)
    #expect(opened.metadata.name == project.name)
    #expect(opened.metadata.hasWebcam == true)
  }

  @Test func saveHistoryThenLoadHistoryRoundTrips() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let (project, _) = try await makeProject(in: dir, webcam: false, cursor: false)
    #expect(project.loadHistory() == nil)
    let entries = (0..<3).map { HistoryEntry(snapshot: ProjectFixtures.editorState(marker: Double($0)), timestamp: Date()) }
    try project.saveHistory(HistoryData(entries: entries, currentIndex: 1))
    #expect(FileManager.default.fileExists(atPath: project.bundleURL.appendingPathComponent("history.json").path))
    let loaded = try #require(project.loadHistory())
    #expect(loaded.currentIndex == 1)
    #expect(loaded.entries.map(\.snapshot.trimStartSeconds) == [0, 1, 2])
  }

  @Test func renameSanitizesDirectoryNameAndKeepsRawNameInMetadata() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    var (project, _) = try await makeProject(in: dir, webcam: false, cursor: false)
    let oldURL = project.bundleURL
    try project.rename(to: "My Clip: v2/final_cut!")
    #expect(project.bundleURL.lastPathComponent == "My Clip v2final_cut.appshow")
    #expect(project.bundleURL.deletingLastPathComponent() == oldURL.deletingLastPathComponent())
    #expect(project.metadata.name == "My Clip: v2/final_cut!")
    #expect(project.name == "My Clip: v2/final_cut!")
    let fm = FileManager.default
    #expect(!fm.fileExists(atPath: oldURL.path))
    #expect(fm.fileExists(atPath: project.bundleURL.appendingPathComponent("screen.mov").path))
    let reopened = try AppShowProject.open(at: project.bundleURL)
    #expect(reopened.metadata.name == "My Clip: v2/final_cut!")
    #expect(try readMetadata(project).name == "My Clip: v2/final_cut!")
  }

  @Test func renameToExistingBundleKeepsCurrentDirectory() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    var (project, _) = try await makeProject(in: dir, webcam: false, cursor: false)
    let oldURL = project.bundleURL
    let occupied = oldURL.deletingLastPathComponent().appendingPathComponent("Taken.appshow")
    try FileManager.default.createDirectory(at: occupied, withIntermediateDirectories: true)
    try project.rename(to: "Taken")
    #expect(project.bundleURL == oldURL)
    #expect(project.metadata.name == "Taken")
    #expect(try readMetadata(project).name == "Taken")
  }

  @Test func renameWithOnlyDisallowedCharactersFallsBackToRawName() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    var (project, _) = try await makeProject(in: dir, webcam: false, cursor: false)
    try project.rename(to: "***")
    #expect(project.bundleURL.lastPathComponent == "***.appshow")
    #expect(FileManager.default.fileExists(atPath: project.bundleURL.appendingPathComponent("project.json").path))
  }

  @Test func openThrowsWhenScreenRecordingIsMissing() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let (project, _) = try await makeProject(in: dir, webcam: false, cursor: false)
    try FileManager.default.removeItem(at: project.bundleURL.appendingPathComponent("screen.mov"))
    #expect(throws: CaptureError.self) {
      try AppShowProject.open(at: project.bundleURL)
    }
    do {
      _ = try AppShowProject.open(at: project.bundleURL)
      Issue.record("open should have thrown")
    } catch CaptureError.recordingFailed(let reason) {
      #expect(reason.contains("Screen recording file missing"))
    }
  }

  @Test func openThrowsWhenProjectJSONIsMissing() throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let bundle = dir.appendingPathComponent("Empty.frm", isDirectory: true)
    try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
    #expect(throws: (any Error).self) {
      try AppShowProject.open(at: bundle)
    }
  }

  @Test func legacyFrmProjectOpensAndKeepsItsExtensionWhenRenamed() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let (created, _) = try await makeProject(in: dir, webcam: false, cursor: false)
    let legacyURL = created.bundleURL.deletingPathExtension().appendingPathExtension("frm")
    try FileManager.default.moveItem(at: created.bundleURL, to: legacyURL)

    var legacy = try AppShowProject.open(at: legacyURL)
    try legacy.rename(to: "Legacy Renamed")

    #expect(legacy.bundleURL.lastPathComponent == "Legacy Renamed.frm")
    #expect(try AppShowProject.open(at: legacy.bundleURL).metadata.name == "Legacy Renamed")
  }

  @Test func deleteRemovesTheBundle() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let (project, _) = try await makeProject(in: dir, webcam: false, cursor: false)
    try project.delete()
    #expect(!FileManager.default.fileExists(atPath: project.bundleURL.path))
  }

  @Test(.enabled(if: ProcessInfo.processInfo.environment["APPSHOW_TMP"] != nil))
  func createWithCleanupDisabledLeavesSharedTempDirUntouched() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let temp = AppShowPaths.temp
    try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
    let sentinel = temp.appendingPathComponent("sentinel-\(UUID().uuidString).txt")
    try Data("keep".utf8).write(to: sentinel)
    defer { try? FileManager.default.removeItem(at: sentinel) }
    _ = try await makeProject(in: dir, webcam: false, cursor: false)
    #expect(FileManager.default.fileExists(atPath: sentinel.path))
  }

  @Test(.enabled(if: ProcessInfo.processInfo.environment["APPSHOW_TMP"] != nil))
  func createWithDefaultCleanupWipesSharedTempDir() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let temp = AppShowPaths.temp
    try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
    let sentinel = temp.appendingPathComponent("sentinel-\(UUID().uuidString).txt")
    try Data("wipe".utf8).write(to: sentinel)
    defer { try? FileManager.default.removeItem(at: sentinel) }
    let result = try await ProjectFixtures.recordingResult(in: dir, webcam: false, systemAudio: false, microphone: false, cursor: false)
    _ = try AppShowProject.create(from: result, fps: 30, captureMode: .entireScreen, in: dir)
    #expect(!FileManager.default.fileExists(atPath: sentinel.path))
  }
}
