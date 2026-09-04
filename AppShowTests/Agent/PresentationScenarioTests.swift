import AVFoundation
import Foundation
import Testing

@testable import AppShow

@MainActor
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["APPSHOW_RUN_SCENARIO_TESTS"] == "1"))
struct PresentationScenarioTests {
  private struct Harness {
    let directory: URL
    let project: AppShowProject
    let state: EditorState
    let dispatcher: AgentToolDispatcher
    let initialSnapshot: EditorStateData
    let initialHistoryCount: Int

    @MainActor
    func tearDown() {
      state.teardown()
      TestPaths.remove(directory)
    }
  }

  @Test func presentationScriptProducesExpectedTimelineAndOneStepUndo() async throws {
    let harness = try await makeHarness()
    defer { harness.tearDown() }

    try await replayScenario(in: harness)

    #expect(abs(harness.state.videoRegionsTotalDuration - 12) < 0.001)
    #expect(harness.state.videoRegions.count == 3)
    #expect(harness.state.spotlightRegions.count == 2)
    #expect(harness.state.textOverlays.count == 1)
    #expect(harness.state.externalAudioTracks.count == 1)
    #expect(harness.state.history.entries.count == harness.initialHistoryCount + 1)
    #expect(harness.state.history.entries.last?.label == "Agent: presentation scenario")

    try harness.project.saveEditorState(harness.state.createSnapshot())
    try harness.project.saveHistory(harness.state.history.toData())
    let reopened = try AppShowProject.open(at: harness.project.bundleURL)
    #expect(reopened.metadata.editorState?.videoRegions?.count == 3)
    #expect(reopened.metadata.editorState?.textOverlays?.count == 1)
    #expect(reopened.metadata.editorState?.externalAudioTracks?.count == 1)
    #expect(reopened.loadHistory()?.entries.count == harness.initialHistoryCount + 1)

    harness.state.undo()
    #expect(harness.state.createSnapshot() == harness.initialSnapshot)
  }

  @Test(.enabled(if: ProcessInfo.processInfo.environment["APPSHOW_RUN_EXPORT_TESTS"] == "1"))
  func exportDraftOfScenarioHasExpectedDurationAndSize() async throws {
    let harness = try await makeHarness()
    defer { harness.tearDown() }
    try await replayScenario(in: harness)
    let historyCount = harness.state.history.entries.count

    let result = try await harness.dispatcher.call(
      "export_draft",
      arguments: ["maxWidth": 640, "fps": 15]
    )

    let path = try #require(result["path"]?.stringValue)
    let url = URL(fileURLWithPath: path).standardizedFileURL
    let drafts = harness.directory.appendingPathComponent("workspace/drafts", isDirectory: true).standardizedFileURL
    #expect(url.path.hasPrefix(drafts.path + "/"))
    #expect(FileManager.default.fileExists(atPath: url.path))
    #expect(harness.state.history.entries.count == historyCount)
    let asset = AVURLAsset(url: url)
    let duration = try await asset.load(.duration).seconds
    let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
    let size = try await track.load(.naturalSize)
    #expect(abs(duration - 12) <= 1.0 / 15 + 0.05)
    #expect(size.width <= 640)
  }

  private func makeHarness() async throws -> Harness {
    let directory = try TestPaths.makeTemporaryDirectory()
    let sources = directory.appendingPathComponent("sources", isDirectory: true)
    try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)
    let screen = try await VideoFixtures.screenMovie(duration: 20, in: sources, name: "scenario-screen")
    let microphone = try AudioFixtures.sineWave(duration: 20, container: .m4a, in: sources, name: "scenario-mic")
    let cursor = try ProjectFixtures.writeCursorMetadata(
      ProjectFixtures.cursorMetadata(duration: 20),
      in: sources,
      name: "scenario-cursor"
    )
    let result = RecordingResult(
      screenVideoURL: screen,
      webcamVideoURL: nil,
      systemAudioURL: nil,
      microphoneAudioURL: microphone,
      cursorMetadataURL: cursor,
      screenSize: VideoFixtures.screenSize,
      webcamSize: nil,
      fps: VideoFixtures.fps,
      captureQuality: .standard,
      isHDR: false
    )
    let project = try AppShowProject.create(
      from: result,
      fps: result.fps,
      captureMode: .entireScreen,
      in: directory,
      cleanupTemp: false
    )
    let state = EditorState(project: project)
    await state.setup()
    let workspace = directory.appendingPathComponent("workspace", isDirectory: true)
    try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
    let dispatcher = AgentToolDispatcher(
      editorState: state,
      framesDirectory: workspace.appendingPathComponent("frames", isDirectory: true),
      workspaceDirectory: workspace,
      handlers: AgentToolCatalog.readOnlyHandlers() + AgentEditingToolCatalog.handlers,
      allowsMutations: true
    )
    return Harness(
      directory: directory,
      project: project,
      state: state,
      dispatcher: dispatcher,
      initialSnapshot: state.createSnapshot(),
      initialHistoryCount: state.history.entries.count
    )
  }

  private func replayScenario(in harness: Harness) async throws {
    let music = try AudioFixtures.sineWave(duration: 20, in: harness.directory, name: "scenario-music")
    let confirmationID = try await requestMusicConfirmation(path: music.path, dispatcher: harness.dispatcher, state: harness.state)
    let fixture = try #require(BundledFixtures.url("presentation-scenario", extension: "json"))
    let calls = try #require(try JSONValue.parse(Data(contentsOf: fixture)).arrayValue)
    let replacements = [
      "$MUSIC_PATH": music.path,
      "$MUSIC_CONFIRMATION": confirmationID.uuidString,
    ]

    for call in calls {
      let name = try #require(call["name"]?.stringValue)
      let arguments = replacing(call["arguments"] ?? [:], with: replacements)
      _ = try await harness.dispatcher.call(name, arguments: arguments)
    }
  }

  private func requestMusicConfirmation(
    path: String,
    dispatcher: AgentToolDispatcher,
    state: EditorState
  ) async throws -> UUID {
    do {
      _ = try await dispatcher.call("add_music", arguments: ["path": .string(path)])
      throw AgentToolError.failed("Music import did not request confirmation")
    } catch AgentToolError.confirmationRequired(let id, _, _) {
      guard state.agentConfirmations.approve(id) else {
        throw AgentToolError.failed("Music confirmation could not be approved")
      }
      return id
    }
  }

  private func replacing(_ value: JSONValue, with replacements: [String: String]) -> JSONValue {
    switch value {
    case .string(let string):
      return .string(replacements[string] ?? string)
    case .array(let values):
      return .array(values.map { replacing($0, with: replacements) })
    case .object(let values):
      return .object(values.mapValues { replacing($0, with: replacements) })
    default:
      return value
    }
  }
}
