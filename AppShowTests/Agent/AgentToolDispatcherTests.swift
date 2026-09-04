import CoreGraphics
import CoreMedia
import Foundation
import ImageIO
import Testing

@testable import AppShow

@MainActor
@Suite(.serialized)
struct AgentToolDispatcherTests {
  private struct Pixel: Equatable {
    let r: UInt8
    let g: UInt8
    let b: UInt8
  }

  @MainActor
  private final class CallRecorder {
    var calls = 0
  }

  @MainActor
  private struct FakeHandler: AgentToolHandler {
    let definition: AgentToolDefinition
    let recorder: CallRecorder
    let error: (any Error)?

    func call(arguments: JSONValue, context: AgentToolContext) async throws -> JSONValue {
      recorder.calls += 1
      if let error { throw error }
      return ["echo": arguments]
    }
  }

  private struct PlainError: Error, LocalizedError {
    var errorDescription: String? { "disk on fire" }
  }

  private func makeState(in dir: URL, webcam: Bool = true, cursor: Bool = true) async throws -> (EditorState, AppShowProject) {
    let sources = dir.appendingPathComponent("sources", isDirectory: true)
    try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)
    let result = try await ProjectFixtures.recordingResult(
      in: sources,
      webcam: webcam,
      systemAudio: true,
      microphone: false,
      cursor: cursor
    )
    let project = try AppShowProject.create(from: result, fps: result.fps, captureMode: .entireScreen, in: dir, cleanupTemp: false)
    let state = EditorState(project: project)
    await state.setup()
    return (state, project)
  }

  private func makeDispatcher(_ state: EditorState, in dir: URL) -> AgentToolDispatcher {
    AgentToolDispatcher(
      editorState: state,
      framesDirectory: dir.appendingPathComponent("frames", isDirectory: true),
      workspaceDirectory: dir
    )
  }

  private func toolError(_ body: () async throws -> JSONValue) async -> AgentToolError? {
    do {
      _ = try await body()
      return nil
    } catch let error as AgentToolError {
      return error
    } catch {
      Issue.record("unexpected error \(error)")
      return nil
    }
  }

  private func pixels(of url: URL) throws -> (width: Int, height: Int, read: (Int, Int) -> Pixel) {
    let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
    let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    let width = image.width
    let height = image.height
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    let context = try #require(
      bytes.withUnsafeMutableBytes { raw in
        CGContext(
          data: raw.baseAddress,
          width: width,
          height: height,
          bitsPerComponent: 8,
          bytesPerRow: width * 4,
          space: CGColorSpace(name: CGColorSpace.sRGB)!,
          bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        )
      }
    )
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    let copy = bytes
    return (
      width, height,
      { x, y in
        let offset = ((height - 1 - y) * width + x) * 4
        return Pixel(r: copy[offset + 2], g: copy[offset + 1], b: copy[offset])
      }
    )
  }

  @Test func projectSummaryReportsBundleAndMedia() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let (state, project) = try await makeState(in: dir)
    defer { state.teardown() }
    let dispatcher = makeDispatcher(state, in: dir)

    let summary = try await dispatcher.call("get_project_summary", arguments: [:])

    #expect(summary["name"] == .string(project.name))
    #expect(summary["bundlePath"] == .string(project.bundleURL.path))
    #expect(summary["workspacePath"] == .string(dir.path))
    #expect(summary["duration"] == 2)
    #expect(summary["fps"] == 30)
    #expect(summary["screenSize"] == ["width": 320, "height": 180])
    #expect(summary["webcam"] == ["present": true, "enabled": true, "size": ["width": 160, "height": 120]])
    #expect(summary["hasSystemAudio"] == true)
    #expect(summary["hasMicAudio"] == false)
    #expect(summary["hasCursorMetadata"] == true)
    #expect(summary["isHDR"] == false)
    #expect(summary["captureMode"] == "entireScreen")
    #expect(summary["createdAt"]?.stringValue?.contains("T") == true)
    #expect(summary["history"] == ["index": 0, "count": 1])
  }

  @Test func timelineSummaryReflectsCutsAndTracksSetOnTheState() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let (state, _) = try await makeState(in: dir)
    defer { state.teardown() }
    let dispatcher = makeDispatcher(state, in: dir)
    state.splitVideoRegion(atTime: 1.0)
    state.removeVideoRegion(regionId: try #require(state.videoRegions.first?.id))
    state.spotlightEnabled = true
    state.addSpotlightRegion(atTime: 0.5)
    state.addCameraRegion(atTime: 1.5, type: .hidden)
    state.zoomEnabled = true
    state.addManualZoomKeyframe(at: 0.5, center: CGPoint(x: 0.4, y: 0.6))
    let bed = try AudioFixtures.sineWave(frequency: 440, duration: 1, in: dir, name: "Bed")
    state.seek(to: .zero)
    try await state.importExternalAudio(from: bed)
    let historyBefore = state.history.entries.count

    let timeline = try await dispatcher.call("get_timeline", arguments: [:])

    #expect(timeline["duration"] == 2)
    #expect(timeline["cuts"]?["hasCuts"] == true)
    #expect(timeline["cuts"]?["keptDuration"] == 1)
    #expect(timeline["cuts"]?["slices"]?.arrayValue?.count == 1)
    #expect(timeline["cuts"]?["slices"]?[0]?["start"] == 1)
    #expect(timeline["cuts"]?["gaps"] == [["start": 0, "end": 1]])
    #expect(timeline["spotlight"]?["enabled"] == true)
    #expect(timeline["spotlight"]?["regions"]?.arrayValue?.count == 1)
    #expect(timeline["camera"]?["present"] == true)
    #expect(timeline["camera"]?["regions"]?[0]?["type"] == "hidden")
    #expect(timeline["zoom"]?["enabled"] == true)
    #expect(timeline["zoom"]?["keyframes"]?.arrayValue?.count == 4)
    #expect(timeline["audio"]?["system"]?["present"] == true)
    #expect(timeline["audio"]?["mic"]?["present"] == false)
    #expect(timeline["audio"]?["external"]?[0]?["name"] == "Bed")
    #expect(timeline["audio"]?["external"]?[0]?["end"] == 1)
    #expect(timeline["snapshot"] == nil)
    #expect(state.history.entries.count == historyBefore)

    let full = try await dispatcher.call("get_timeline", arguments: ["detail": "full"])
    #expect(full["snapshot"]?["videoRegions"]?.arrayValue?.count == 1)
    #expect(full["snapshot"]?["externalAudioTracks"]?[0]?["displayName"] == "Bed")
  }

  @Test func transcriptIsEmptyUntilCaptionsExist() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let (state, _) = try await makeState(in: dir, webcam: false, cursor: false)
    defer { state.teardown() }
    let dispatcher = makeDispatcher(state, in: dir)

    let empty = try await dispatcher.call("get_transcript", arguments: ["withWords": true])
    #expect(empty["count"] == 0)
    #expect(empty["segments"] == [])
    #expect(empty["hint"]?.stringValue?.isEmpty == false)

    state.captionSegments = try #require(ProjectFixtures.fullEditorState().captionSegments)
    let populated = try await dispatcher.call("get_transcript", arguments: ["withWords": true, "from": 0, "to": 0.95])
    #expect(populated["count"] == 1)
    #expect(populated["segments"]?[0]?["text"] == "hello there world")
    #expect(populated["segments"]?[0]?["words"]?.arrayValue?.count == 3)
    #expect(populated["hint"] == nil)
  }

  @Test func cursorActivityAndHistoryComeFromTheOpenProject() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let (state, _) = try await makeState(in: dir)
    defer { state.teardown() }
    let dispatcher = makeDispatcher(state, in: dir)

    let activity = try await dispatcher.call("get_cursor_activity", arguments: ["dwellSeconds": 0.6])
    #expect(activity["available"] == true)
    #expect(activity["clickCount"] == 3)
    #expect(activity["clickClusters"]?.arrayValue?.count == 2)
    #expect(activity["keystrokeBursts"]?[0]?["count"] == 6)

    let history = try await dispatcher.call("get_history", arguments: nil)
    #expect(history["count"] == 1)
    #expect(history["index"] == 0)
    #expect(history["entries"]?[0]?["label"] == "Initial state")
    #expect(state.history.entries.count == 1)
  }

  @Test func unknownToolIsMethodNotFoundAndLeavesHistoryAlone() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let (state, _) = try await makeState(in: dir, webcam: false, cursor: false)
    defer { state.teardown() }
    let dispatcher = makeDispatcher(state, in: dir)

    let error = await toolError { try await dispatcher.call("nope", arguments: [:]) }
    #expect(error == .unknownTool("nope"))
    #expect(error?.jsonRPCError.code == JSONRPCError.methodNotFoundCode)
    #expect(error?.jsonRPCError.data?["code"] == "UNKNOWN_TOOL")
    #expect(state.history.entries.count == 1)
  }

  @Test func invalidArgumentsAreRejectedBeforeTheToolRuns() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let (state, _) = try await makeState(in: dir, webcam: false, cursor: false)
    defer { state.teardown() }
    let dispatcher = makeDispatcher(state, in: dir)

    let missing = await toolError { try await dispatcher.call("render_preview_frame", arguments: [:]) }
    guard case .invalidArguments(let detail) = missing else {
      Issue.record("expected invalid arguments, got \(String(describing: missing))")
      return
    }
    #expect(detail.contains("atSeconds"))
    #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("frames").path) == false)

    let wrongType = await toolError { try await dispatcher.call("get_timeline", arguments: ["detail": 3]) }
    #expect(wrongType?.code == "TOOL_ARGUMENTS_INVALID")
    let notObject = await toolError { try await dispatcher.call("get_history", arguments: [1]) }
    #expect(notObject?.code == "TOOL_ARGUMENTS_INVALID")
  }

  @Test func mutatingHandlersAreRefusedAndHiddenFromTheList() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let (state, _) = try await makeState(in: dir, webcam: false, cursor: false)
    defer { state.teardown() }
    let dispatcher = makeDispatcher(state, in: dir)
    let recorder = CallRecorder()
    let definition = AgentToolDefinition(
      name: "set_trim",
      description: "test double",
      inputSchema: AgentToolSchema.object(["start": AgentToolSchema.number("start")]),
      mutating: true
    )
    dispatcher.register(FakeHandler(definition: definition, recorder: recorder, error: nil))

    let error = await toolError { try await dispatcher.call("set_trim", arguments: ["start": 1]) }
    #expect(error == .mutationNotAllowed("set_trim"))
    #expect(error?.jsonRPCError.code == -32003)
    #expect(recorder.calls == 0)
    #expect(dispatcher.toolsListResult["tools"]?.arrayValue?.contains { $0["name"] == "set_trim" } == false)
    #expect(dispatcher.definition(named: "set_trim") == definition)
  }

  @Test func registeredReadOnlyHandlersRunAndPlainErrorsBecomeToolFailed() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let (state, _) = try await makeState(in: dir, webcam: false, cursor: false)
    defer { state.teardown() }
    let dispatcher = makeDispatcher(state, in: dir)
    let recorder = CallRecorder()
    let echo = AgentToolDefinition(
      name: "echo_test",
      description: "test double",
      inputSchema: AgentToolSchema.object(["value": AgentToolSchema.string("value")], required: ["value"]),
      mutating: false
    )
    let broken = AgentToolDefinition(
      name: "broken_test",
      description: "test double",
      inputSchema: AgentToolSchema.object([:]),
      mutating: false
    )
    dispatcher.register(FakeHandler(definition: echo, recorder: recorder, error: nil))
    dispatcher.register(FakeHandler(definition: broken, recorder: recorder, error: PlainError()))

    let result = try await dispatcher.call("echo_test", arguments: ["value": "hi"])
    #expect(result == ["echo": ["value": "hi"]])
    #expect(dispatcher.toolsListResult["tools"]?.arrayValue?.contains { $0["name"] == "echo_test" } == true)

    let failure = await toolError { try await dispatcher.call("broken_test", arguments: nil) }
    #expect(failure == .failed("disk on fire"))
    #expect(recorder.calls == 2)
  }

  @Test func getSilencesUsesTheOpenProjectsAudio() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let (state, _) = try await makeState(in: dir, webcam: false, cursor: false)
    defer { state.teardown() }
    let dispatcher = makeDispatcher(state, in: dir)

    let result = try await dispatcher.call("get_silences", arguments: ["source": "system"])
    #expect(result["source"] == "system")
    #expect(result["count"] == 0)
    #expect(result["silences"] == [])
  }

  @Test func renderPreviewFrameWritesADecodablePNGOfTheRequestedSize() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let (state, _) = try await makeState(in: dir)
    defer { state.teardown() }
    let dispatcher = makeDispatcher(state, in: dir)
    state.backgroundStyle = .solidColor(CodableColor(r: 1, g: 0, b: 0))
    state.padding = 0.1
    state.showCursor = false
    let historyBefore = state.history.entries.count

    let result = try await dispatcher.call("render_preview_frame", arguments: ["atSeconds": 1.0, "width": 64])

    let path = try #require(result["path"]?.stringValue)
    #expect(path.hasPrefix(dir.appendingPathComponent("frames").path))
    #expect(path.hasSuffix("frame-1000ms-64w.png"))
    #expect(result["width"] == 64)
    #expect(result["height"] == 36)
    #expect(result["atSeconds"] == 1)
    let image = try pixels(of: URL(fileURLWithPath: path))
    #expect(image.width == 64)
    #expect(image.height == 36)
    let corner = image.read(1, 1)
    #expect(corner.r >= 250 && corner.g <= 45 && corner.b <= 3, "corner \(corner)")
    let centre = image.read(32, 18)
    let frameIndex = VideoFixtures.frameIndex(for: VideoFixtures.RGB(r: centre.r, g: centre.g, b: centre.b))
    #expect(abs(frameIndex - 30) <= 3, "centre \(centre) decodes to frame \(frameIndex)")
    #expect(abs(Int(centre.r) - Int(centre.g)) <= 3 && abs(Int(centre.r) - Int(centre.b)) <= 3, "centre \(centre)")
    #expect(state.history.entries.count == historyBefore)

    let clamped = try await dispatcher.call("render_preview_frame", arguments: ["atSeconds": 9.5, "width": 32])
    #expect(clamped["atSeconds"] == 2)
    #expect(clamped["height"] == 18)
    #expect(FileManager.default.fileExists(atPath: clamped["path"]?.stringValue ?? ""))
  }
}
