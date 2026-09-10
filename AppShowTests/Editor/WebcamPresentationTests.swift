import CoreMedia
import Foundation
import Testing

@testable import AppShow

@MainActor
@Suite(.serialized)
struct WebcamPresentationTests {
  private func makeState(in directory: URL, webcam: Bool = true, presentation: WebcamPresentation? = nil) async throws -> EditorState {
    let sources = directory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)
    var result = try await ProjectFixtures.recordingResult(
      in: sources,
      webcam: webcam,
      systemAudio: false,
      microphone: false,
      cursor: false
    )
    result.webcamPresentation = presentation
    let project = try AppShowProject.create(from: result, fps: result.fps, captureMode: .entireScreen, in: directory, cleanupTemp: false)
    let state = EditorState(project: project)
    await state.setup()
    return state
  }

  private func tools(_ state: EditorState, directory: URL) -> AgentToolDispatcher {
    AgentToolDispatcher(
      editorState: state,
      framesDirectory: directory.appendingPathComponent("frames"),
      handlers: AgentEditingToolCatalog.handlers,
      allowsMutations: true
    )
  }

  @Test func recordingDefaultsPersistAndKeepCirclesInsideEveryCanvasCorner() throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let file = directory.appendingPathComponent("config.json")
    let config = ConfigService(fileURL: file)
    #expect(config.webcamPresentation.corner == .bottomRight)
    #expect(config.webcamPresentation.relativeWidth == 0.2)
    config.webcamPresentation = WebcamPresentation(corner: .topLeft, relativeWidth: 0.3)
    #expect(ConfigService(fileURL: file).webcamPresentation == config.webcamPresentation)
    for corner in CameraCorner.allCases {
      for canvas in [CGSize(width: 1920, height: 1080), CGSize(width: 1080, height: 1920), CGSize(width: 2000, height: 500)] {
        let layout = WebcamPresentation(corner: corner, relativeWidth: 0.5).layout(canvasSize: canvas)
        let rect = layout.pixelRect(screenSize: canvas, webcamSize: CGSize(width: 640, height: 480), cameraAspect: .ratio1x1)
        #expect(abs(rect.width - rect.height) < 0.001)
        #expect(rect.minX >= 0 && rect.minY >= 0)
        #expect(rect.maxX <= canvas.width && rect.maxY <= canvas.height)
      }
    }
  }

  @Test func newRecordingSeedsCircleAndSavedEditsOverrideRecordingDefaults() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let state = try await makeState(in: directory, presentation: WebcamPresentation(corner: .topLeft, relativeWidth: 0.2))
    defer { state.teardown() }
    #expect(state.cameraAspect == .ratio1x1)
    #expect(state.cameraCornerRadius == 50)
    #expect(state.cameraLayout.relativeX == 0.02)
    #expect(state.cameraLayout.relativeWidth == 0.2)
    #expect(state.cameraFullscreenFillMode == .fill)
    state.cameraLayout.relativeWidth = 0.3
    state.cameraCornerRadius = 10
    state.saveState()
    let project = try AppShowProject.open(at: #require(state.project?.bundleURL))
    #expect(project.recordingResult.webcamPresentation?.corner == .topLeft)
    let reopened = EditorState(project: project)
    defer { reopened.teardown() }
    await reopened.setup()
    #expect(reopened.cameraCornerRadius == 10)
    #expect(reopened.cameraLayout.relativeWidth == 0.3)
  }

  @Test func legacyProjectKeepsExistingCameraStyle() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let state = try await makeState(in: directory)
    defer { state.teardown() }
    #expect(state.cameraAspect == .original)
    #expect(state.cameraCornerRadius == 8)
    #expect(state.project?.metadata.webcamPresentation == nil)
  }

  @Test func focusWebcamCreatesAnimatedRegionAndImmediateUndo() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let state = try await makeState(in: directory, presentation: WebcamPresentation())
    defer { state.teardown() }
    let id = try #require(state.focusWebcam(atTime: 0.5))
    let region = try #require(state.cameraRegions.first)
    #expect(region.id == id && region.startSeconds == 0.5)
    #expect(region.type == .fullscreen)
    #expect(region.entryTransition == .scale && region.exitTransition == .scale)
    #expect(region.entryTransitionDuration == 0.4)
    #expect(!state.isCameraFullscreen(at: 0.25))
    #expect(state.isCameraFullscreen(at: 1))
    state.undo()
    #expect(state.cameraRegions.isEmpty)
  }

  @Test func cameraToolsCreateRetimingAndRemovalArePersistedAndUndoable() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let state = try await makeState(in: directory, presentation: WebcamPresentation())
    defer { state.teardown() }
    let dispatcher = tools(state, directory: directory)
    _ = try await dispatcher.call(
      "set_camera",
      arguments: ["shape": "circle", "corner": "topRight", "width": 0.25, "fullscreenFillMode": "fill"]
    )
    #expect(state.cameraAspect == .ratio1x1 && state.cameraCornerRadius == 50)
    #expect(abs(state.cameraLayout.relativeX - 0.73) < 0.001)
    let added = try await dispatcher.call("add_camera_region", arguments: ["start": 0.5, "end": 1.5, "type": "rightThird"])
    #expect(state.agentPreviewConfiguration().cameraFullscreenRegions?.first?.cameraPresentation == .rightThird)
    let id = try #require(state.cameraRegions.first?.id.uuidString)
    #expect(added["camera"]?["regions"]?[0]?["entryTransition"] == "scale")
    #expect(added["camera"]?["regions"]?[0]?["entryDuration"] == 0.4)
    _ = try await dispatcher.call(
      "update_camera_region",
      arguments: ["id": .string(id), "start": 0.25, "end": 1.25, "exitTransition": "fade"]
    )
    #expect(state.cameraRegions.first?.startSeconds == 0.25)
    #expect(state.cameraRegions.first?.exitTransition == .fade)
    state.saveState()
    let saved = try AppShowProject.open(at: #require(state.project?.bundleURL))
    #expect(saved.metadata.editorState?.cameraRegions == state.cameraRegions)
    _ = try await dispatcher.call("remove_camera_region", arguments: ["id": .string(id)])
    #expect(state.cameraRegions.isEmpty)
    state.undo()
    #expect(state.cameraRegions.first?.startSeconds == 0.25)
  }

  @Test func invalidAndOverlappingCameraRegionsLeaveTheProjectUntouched() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let state = try await makeState(in: directory)
    defer { state.teardown() }
    let dispatcher = tools(state, directory: directory)
    _ = try await dispatcher.call("add_camera_region", arguments: ["start": 0.5, "end": 1.5])
    let before = state.createSnapshot()
    for arguments: JSONValue in [["start": 1, "end": 2], ["start": 1.75, "end": 3], ["start": 1, "end": 0.5]] {
      await #expect(throws: AgentToolError.self) { _ = try await dispatcher.call("add_camera_region", arguments: arguments) }
      #expect(state.createSnapshot() == before)
    }
  }

  @Test func focusRequiresRecordedWebcamMedia() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let state = try await makeState(in: directory, webcam: false)
    defer { state.teardown() }
    #expect(state.focusWebcam(atTime: 0) == nil)
    await #expect(throws: AgentToolError.self) {
      _ = try await tools(state, directory: directory).call("add_camera_region", arguments: ["start": 0, "end": 1])
    }
  }
}
