import CoreMedia
import Foundation
import Testing

@testable import Reframed

@MainActor
@Suite(.serialized)
struct MutatingToolsTests {
  private final class ActivityRecorder {
    var value: AgentActivity?
  }

  private struct FailingMutation: AgentToolHandler {
    let definition = AgentToolDefinition(
      name: "failing_mutation",
      description: "Mutate and fail",
      inputSchema: AgentToolSchema.object([:]),
      mutating: true
    )

    func call(arguments: JSONValue, context: AgentToolContext) async throws -> JSONValue {
      context.editorState.padding = 0.5
      throw AgentToolError.failed("boom")
    }
  }

  private struct RecordingMutation: AgentToolHandler {
    let recorder: ActivityRecorder
    let definition = AgentToolDefinition(
      name: "recording_mutation",
      description: "Record activity",
      inputSchema: AgentToolSchema.object(
        [
          "start": AgentToolSchema.number("Start"),
          "end": AgentToolSchema.number("End"),
          "label": AgentToolSchema.string("Label"),
        ],
        required: ["start", "end"]
      ),
      mutating: true
    )

    func call(arguments: JSONValue, context: AgentToolContext) async throws -> JSONValue {
      recorder.value = context.editorState.agentActivity
      context.editorState.padding = 0.25
      return [:]
    }
  }

  private func confirmationError(_ body: () throws -> Void) -> AgentToolError? {
    do {
      try body()
      return nil
    } catch let error as AgentToolError {
      return error
    } catch {
      Issue.record("unexpected error \(error)")
      return nil
    }
  }

  private func makeState(in directory: URL, withAudio: Bool = false) async throws -> EditorState {
    let sources = directory.appendingPathComponent("sources", isDirectory: true)
    try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)
    let result = try await ProjectFixtures.recordingResult(
      in: sources,
      webcam: false,
      systemAudio: withAudio,
      microphone: withAudio,
      cursor: true
    )
    let project = try ReframedProject.create(
      from: result,
      fps: result.fps,
      captureMode: .entireScreen,
      in: directory,
      cleanupTemp: false
    )
    let state = EditorState(project: project)
    await state.setup()
    return state
  }

  private func makeStateWithAudioGap(
    in directory: URL,
    gap: ClosedRange<Double> = 0.7...1.5
  ) async throws -> EditorState {
    let sources = directory.appendingPathComponent("sources", isDirectory: true)
    try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)
    let base = try await ProjectFixtures.recordingResult(
      in: sources,
      webcam: false,
      systemAudio: false,
      microphone: false,
      cursor: false
    )
    let microphone = try AudioFixtures.toneWithGap(
      duration: 2,
      gap: gap,
      container: .m4a,
      in: sources,
      name: "mic-gap"
    )
    let result = RecordingResult(
      screenVideoURL: base.screenVideoURL,
      webcamVideoURL: nil,
      systemAudioURL: nil,
      microphoneAudioURL: microphone,
      cursorMetadataURL: nil,
      screenSize: base.screenSize,
      webcamSize: nil,
      fps: base.fps,
      captureQuality: base.captureQuality,
      isHDR: base.isHDR
    )
    let project = try ReframedProject.create(
      from: result,
      fps: result.fps,
      captureMode: .entireScreen,
      in: directory,
      cleanupTemp: false
    )
    let state = EditorState(project: project)
    await state.setup()
    return state
  }

  private func dispatcher(
    _ state: EditorState,
    in directory: URL,
    batchTimeout: Duration = .seconds(300)
  ) -> AgentToolDispatcher {
    AgentToolDispatcher(
      editorState: state,
      framesDirectory: directory.appendingPathComponent("frames", isDirectory: true),
      workspaceDirectory: directory,
      handlers: AgentToolCatalog.readOnlyHandlers() + AgentEditingToolCatalog.handlers,
      allowsMutations: true,
      batchTimeout: batchTimeout
    )
  }

  @Test func setTrimCreatesOneLabelledUndoStep() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let state = try await makeState(in: directory)
    defer { state.teardown() }
    let initialCount = state.history.entries.count

    let dispatcher = dispatcher(state, in: directory)
    let result = try await dispatcher.call(
      "set_trim",
      arguments: ["start": 0.25, "end": 1.5, "label": "tighten"]
    )

    #expect(CMTimeGetSeconds(state.trimStart) == 0.25)
    #expect(CMTimeGetSeconds(state.trimEnd) == 1.5)
    #expect(state.history.entries.count == initialCount + 1)
    #expect(state.history.entries.last?.label == "Agent: tighten")
    #expect(result["trim"] == ["start": 0.25, "end": 1.5])
    let history = try await dispatcher.call("get_history", arguments: [:])
    #expect(history["entries"]?[initialCount]?["label"] == "Agent: tighten")
    try await Task.sleep(for: .seconds(1.7))
    #expect(state.history.entries.count == initialCount + 1)

    state.undo()
    #expect(CMTimeGetSeconds(state.trimStart) == 0)
  }

  @Test func zoomAndSpotlightToolsApplyExistingEditorPrimitives() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let state = try await makeState(in: directory)
    defer { state.teardown() }
    let dispatcher = dispatcher(state, in: directory)

    _ = try await dispatcher.call(
      "add_zoom",
      arguments: ["at": 1, "centerX": 0.4, "centerY": 0.6, "level": 2.5]
    )
    #expect(state.zoomEnabled)
    #expect(state.zoomLevel == 2.5)
    #expect(state.zoomTimeline?.allKeyframes.count == 4)

    _ = try await dispatcher.call(
      "add_spotlight",
      arguments: ["start": 0.2, "end": 0.8, "radius": 150]
    )
    #expect(state.spotlightEnabled)
    let spotlight = try #require(state.spotlightRegions.first)
    #expect(spotlight.startSeconds == 0.2)
    #expect(spotlight.endSeconds == 0.8)
    #expect(spotlight.customRadius == 150)
  }

  @Test func setKeptSlicesNormalizesRangesAndUndoRestoresTheTimeline() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let state = try await makeState(in: directory)
    defer { state.teardown() }
    let dispatcher = dispatcher(state, in: directory)

    let result = try await dispatcher.call(
      "set_kept_slices",
      arguments: [
        "slices": [
          ["start": 1.25, "end": 3],
          ["start": 0, "end": 0.75],
          ["start": 0.5, "end": 1],
        ]
      ]
    )

    #expect(state.videoRegions.map(\.startSeconds) == [0, 1.25])
    #expect(state.videoRegions.map(\.endSeconds) == [1, 2])
    #expect(result["cuts"]?["slices"]?.arrayValue?.count == 2)
    state.undo()
    #expect(state.videoRegions.map(\.startSeconds) == [0])
    #expect(state.videoRegions.map(\.endSeconds) == [2])
  }

  @Test func removeTimeRangeCreatesExactGapAndUndoRestoresTheTimeline() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let state = try await makeState(in: directory)
    defer { state.teardown() }
    let dispatcher = dispatcher(state, in: directory)

    _ = try await dispatcher.call("remove_time_range", arguments: ["start": 0.4, "end": 0.9])

    #expect(state.videoRegions.map(\.startSeconds) == [0, 0.9])
    #expect(state.videoRegions.map(\.endSeconds) == [0.4, 2])
    state.undo()
    #expect(state.videoRegions.map(\.startSeconds) == [0])
    #expect(state.videoRegions.map(\.endSeconds) == [2])
  }

  @Test func batchProducesOneLabelledUndoStepForSeveralMutations() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let state = try await makeState(in: directory)
    defer { state.teardown() }
    let dispatcher = dispatcher(state, in: directory)
    let before = state.createSnapshot()
    let initialCount = state.history.entries.count

    _ = try await dispatcher.call("begin_batch", arguments: ["label": "polish presentation"])
    _ = try await dispatcher.call("set_trim", arguments: ["start": 0.2, "end": 1.8])
    _ = try await dispatcher.call("remove_time_range", arguments: ["start": 0.7, "end": 0.9])
    _ = try await dispatcher.call("add_spotlight", arguments: ["start": 0.3, "end": 0.6])
    #expect(state.history.entries.count == initialCount)

    _ = try await dispatcher.call("end_batch", arguments: [:])

    #expect(state.history.entries.count == initialCount + 1)
    #expect(state.history.entries.last?.label == "Agent: polish presentation")
    state.undo()
    #expect(state.createSnapshot() == before)
  }

  @Test func batchTimeoutRestoresThePreBatchState() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let state = try await makeState(in: directory)
    defer { state.teardown() }
    let dispatcher = dispatcher(state, in: directory, batchTimeout: .milliseconds(10))
    let before = state.createSnapshot()
    let initialCount = state.history.entries.count

    _ = try await dispatcher.call("begin_batch", arguments: ["label": "expired"])
    _ = try await dispatcher.call("set_trim", arguments: ["start": 0.2, "end": 1.8])
    try await Task.sleep(for: .milliseconds(20))

    await #expect(throws: AgentToolError.batchTimedOut) {
      try await dispatcher.call("get_timeline", arguments: [:])
    }
    #expect(state.createSnapshot() == before)
    #expect(state.history.entries.count == initialCount)
  }

  @Test func userUndoCancelsTheBatchAndRestoresItsStartingState() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let state = try await makeState(in: directory)
    defer { state.teardown() }
    let dispatcher = dispatcher(state, in: directory)

    _ = try await dispatcher.call("set_trim", arguments: ["start": 0.1, "end": 1.9])
    let beforeBatch = state.createSnapshot()
    let startingIndex = state.history.currentIndex
    _ = try await dispatcher.call("begin_batch", arguments: ["label": "cancel me"])
    _ = try await dispatcher.call("add_spotlight", arguments: ["start": 0.3, "end": 0.6])
    state.undo()

    await #expect(throws: AgentToolError.userUndo) {
      try await dispatcher.call("get_timeline", arguments: [:])
    }
    #expect(state.createSnapshot() == beforeBatch)
    #expect(state.history.currentIndex == startingIndex)
  }

  @Test func confirmationApprovesOneNormalizedOperationExactlyOnce() throws {
    let confirmations = AgentConfirmations()
    let operation = AgentConfirmationOperation.externalFile(
      kind: "import_audio",
      url: URL(fileURLWithPath: "/tmp/appshow/music/../song.mp3")
    )

    let required = confirmationError {
      try confirmations.authorize(operation: operation, confirmationID: nil, title: "Import song", detail: "song.mp3")
    }
    guard case .confirmationRequired(let id, _, _) = required else {
      Issue.record("expected confirmation request")
      return
    }
    #expect(operation.arguments["path"] == "/tmp/appshow/song.mp3")
    #expect(confirmations.pending.map(\.id) == [id])
    #expect(required?.jsonRPCError.data?["confirmationId"] == .string(id.uuidString))
    #expect(
      confirmationError {
        try confirmations.authorize(operation: operation, confirmationID: id, title: "Import song", detail: "song.mp3")
      } == .confirmationPending(id)
    )
    #expect(confirmations.approve(id))

    try confirmations.authorize(operation: operation, confirmationID: id, title: "Import song", detail: "song.mp3")

    #expect(confirmations.pending.isEmpty)
    #expect(
      confirmationError {
        try confirmations.authorize(operation: operation, confirmationID: id, title: "Import song", detail: "song.mp3")
      } == .confirmationExpired(id)
    )
  }

  @Test func deniedConfirmationCannotAuthorizeTheOperation() {
    let confirmations = AgentConfirmations()
    let operation = AgentConfirmationOperation(kind: "export", arguments: ["format": "mp4"])
    let required = confirmationError {
      try confirmations.authorize(operation: operation, confirmationID: nil, title: "Export video", detail: "MP4")
    }
    guard case .confirmationRequired(let id, _, _) = required else {
      Issue.record("expected confirmation request")
      return
    }

    #expect(confirmations.deny(id))
    #expect(
      confirmationError {
        try confirmations.authorize(operation: operation, confirmationID: id, title: "Export video", detail: "MP4")
      } == .confirmationDenied(id)
    )
  }

  @Test func confirmationIsConsumedWhenItsOperationDoesNotMatch() {
    let confirmations = AgentConfirmations()
    let approved = AgentConfirmationOperation(kind: "import_audio", arguments: ["path": "/tmp/one.mp3"])
    let different = AgentConfirmationOperation(kind: "import_audio", arguments: ["path": "/tmp/two.mp3"])
    let required = confirmationError {
      try confirmations.authorize(operation: approved, confirmationID: nil, title: "Import song", detail: "one.mp3")
    }
    guard case .confirmationRequired(let id, _, _) = required else {
      Issue.record("expected confirmation request")
      return
    }
    #expect(confirmations.approve(id))

    #expect(
      confirmationError {
        try confirmations.authorize(operation: different, confirmationID: id, title: "Import song", detail: "two.mp3")
      } == .confirmationMismatch(id)
    )
    #expect(
      confirmationError {
        try confirmations.authorize(operation: approved, confirmationID: id, title: "Import song", detail: "one.mp3")
      } == .confirmationExpired(id)
    )
  }

  @Test func confirmationExpiresAndSessionClearInvalidatesEverything() {
    var now = Date(timeIntervalSince1970: 100)
    let confirmations = AgentConfirmations(expirationInterval: 5, now: { now })
    let operation = AgentConfirmationOperation(kind: "export", arguments: ["format": "mov"])
    let first = confirmationError {
      try confirmations.authorize(operation: operation, confirmationID: nil, title: "Export", detail: "MOV")
    }
    guard case .confirmationRequired(let expiredID, _, _) = first else {
      Issue.record("expected confirmation request")
      return
    }
    now.addTimeInterval(6)
    #expect(!confirmations.approve(expiredID))
    #expect(
      confirmationError {
        try confirmations.authorize(operation: operation, confirmationID: expiredID, title: "Export", detail: "MOV")
      } == .confirmationExpired(expiredID)
    )

    let second = confirmationError {
      try confirmations.authorize(operation: operation, confirmationID: nil, title: "Export", detail: "MOV")
    }
    guard case .confirmationRequired(let clearedID, _, _) = second else {
      Issue.record("expected confirmation request")
      return
    }
    confirmations.clear()
    #expect(confirmations.pending.isEmpty)
    #expect(
      confirmationError {
        try confirmations.authorize(operation: operation, confirmationID: clearedID, title: "Export", detail: "MOV")
      } == .confirmationExpired(clearedID)
    )
  }

  @Test func mutationsStayDisabledUnlessTheDispatcherOptsIn() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let state = try await makeState(in: directory)
    defer { state.teardown() }
    let handler = try #require(AgentEditingToolCatalog.handlers.first)
    let dispatcher = AgentToolDispatcher(
      editorState: state,
      framesDirectory: directory,
      handlers: [handler]
    )

    await #expect(throws: AgentToolError.mutationNotAllowed("set_trim")) {
      try await dispatcher.call("set_trim", arguments: ["start": 0, "end": 1])
    }
  }

  @Test func failedMutationRestoresStateAndAddsNoHistory() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let state = try await makeState(in: directory)
    defer { state.teardown() }
    let before = state.createSnapshot()
    let historyCount = state.history.entries.count
    let dispatcher = AgentToolDispatcher(
      editorState: state,
      framesDirectory: directory,
      handlers: [FailingMutation()],
      allowsMutations: true
    )

    await #expect(throws: AgentToolError.failed("boom")) {
      try await dispatcher.call("failing_mutation", arguments: [:])
    }

    #expect(state.createSnapshot() == before)
    #expect(state.history.entries.count == historyCount)
  }

  @Test func mutationPublishesEphemeralActivityAndLastTimelineChange() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let state = try await makeState(in: directory)
    defer { state.teardown() }
    let recorder = ActivityRecorder()
    let dispatcher = AgentToolDispatcher(
      editorState: state,
      framesDirectory: directory,
      handlers: [RecordingMutation(recorder: recorder)],
      allowsMutations: true
    )

    _ = try await dispatcher.call(
      "recording_mutation",
      arguments: ["start": 0.4, "end": 1.2, "label": "highlight change"]
    )

    #expect(recorder.value?.toolName == "recording_mutation")
    #expect(recorder.value?.label == "Agent: highlight change")
    #expect(state.agentActivity == nil)
    #expect(
      state.lastAgentChange
        == AgentTimelineChange(track: "recording", startSeconds: 0.4, endSeconds: 1.2, label: "Agent: highlight change")
    )
    #expect(state.createSnapshot().padding == 0.25)
  }

  @Test func editingDispatcherAdvertisesMutationsWithDestructiveHints() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let state = try await makeState(in: directory)
    defer { state.teardown() }
    let dispatcher = dispatcher(state, in: directory)

    let definitions = dispatcher.advertisedDefinitions
    let names = Set(definitions.map(\.name))
    #expect(
      names.isSuperset(
        of: [
          "set_trim", "add_zoom", "add_spotlight", "set_kept_slices", "remove_time_range", "remove_silences",
          "add_text", "update_text", "remove_text", "add_image", "update_image", "remove_image", "begin_batch", "end_batch",
          "add_blur", "update_blur", "remove_blur",
        ]
      )
    )
    let trim = try #require(definitions.first { $0.name == "set_trim" })
    #expect(trim.mcpValue["annotations"]?["readOnlyHint"] == false)
    #expect(trim.mcpValue["annotations"]?["destructiveHint"] == true)
  }

  @Test func presentationSettingsToolsApplyExistingEditorStateAndUndo() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let state = try await makeState(in: directory, withAudio: true)
    defer { state.teardown() }
    let dispatcher = dispatcher(state, in: directory)

    _ = try await dispatcher.call(
      "set_canvas",
      arguments: [
        "aspect": "ratio16x9", "padding": 0.12, "cornerRadius": 18, "shadow": 0.4,
        "background": "solid", "red": 0.1, "green": 0.2, "blue": 0.3,
      ]
    )
    #expect(state.canvasAspect == .ratio16x9)
    #expect(state.padding == 0.12)
    #expect(state.videoCornerRadius == 18)
    #expect(state.backgroundStyle == .solidColor(CodableColor(r: 0.1, g: 0.2, b: 0.3)))

    _ = try await dispatcher.call(
      "set_captions",
      arguments: [
        "enabled": true, "fontSize": 56, "weight": "semibold", "positionX": 0.4,
        "positionY": 0.8, "maxWordsPerLine": 4,
      ]
    )
    #expect(state.captionsEnabled)
    #expect(state.captionFontSize == 56)
    #expect(state.captionFontWeight == .semibold)
    #expect(state.captionPosition == CaptionPosition(relativeX: 0.4, relativeY: 0.8))
    #expect(state.captionMaxWordsPerLine == 4)

    _ = try await dispatcher.call(
      "replace_captions",
      arguments: [
        "segments": [
          ["start": 0.2, "end": 0.8, "text": "Welcome"],
          ["start": 1.0, "end": 1.6, "text": "Let us begin"],
        ]
      ]
    )
    #expect(state.captionSegments.map(\.text) == ["Welcome", "Let us begin"])

    _ = try await dispatcher.call(
      "set_cursor",
      arguments: ["visible": true, "style": 4, "size": 32, "clickHighlights": true]
    )
    #expect(state.showCursor)
    #expect(state.cursorStyle == .centerDot)
    #expect(state.cursorSize == 32)
    #expect(state.showClickHighlights)

    _ = try await dispatcher.call(
      "set_camera",
      arguments: [
        "enabled": false, "x": 0.7, "y": 0.05, "width": 0.2, "aspect": "ratio1x1",
        "cornerRadius": 20, "mirrored": true,
      ]
    )
    #expect(!state.webcamEnabled)
    #expect(state.cameraLayout == CameraLayout(relativeX: 0.7, relativeY: 0.05, relativeWidth: 0.2))
    #expect(state.cameraAspect == .ratio1x1)
    #expect(state.cameraCornerRadius == 20)
    #expect(state.cameraMirrored)

    _ = try await dispatcher.call(
      "set_audio",
      arguments: ["systemVolume": 0.25, "microphoneVolume": 1.25, "systemMuted": true]
    )
    #expect(state.systemAudioVolume == 0.25)
    #expect(state.micAudioVolume == 1.25)
    #expect(state.systemAudioMuted)
    state.undo()
    #expect(state.systemAudioVolume == 1)
    #expect(state.micAudioVolume == 1)
    #expect(!state.systemAudioMuted)
  }

  @Test func silenceToolsPreviewApplyAndUndoOneAnalysis() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let state = try await makeStateWithAudioGap(in: directory)
    defer { state.teardown() }
    let dispatcher = dispatcher(state, in: directory)
    let initialCount = state.history.entries.count

    let preview = try await dispatcher.call(
      "get_silences",
      arguments: ["source": "mic", "thresholdDb": -40, "minGapSeconds": 0.5]
    )
    #expect(preview["count"] == 1)
    #expect(preview["silences"]?[0]?["start"]?.doubleValue.map { abs($0 - 0.7) < 0.1 } == true)

    _ = try await dispatcher.call(
      "remove_silences",
      arguments: ["source": "mic", "thresholdDb": -40, "minGapSeconds": 0.5, "padding": 0.15]
    )
    #expect(state.videoRegions.count == 2)
    #expect(state.history.entries.count == initialCount + 1)
    #expect(state.history.entries.last?.label == "Agent: remove silences")
    state.undo()
    #expect(state.videoRegions.count == 1)
  }

  @Test func textOverlayToolsCreateUpdateRemoveAndUndo() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let state = try await makeState(in: directory)
    defer { state.teardown() }
    let dispatcher = dispatcher(state, in: directory)

    let added = try await dispatcher.call(
      "add_text",
      arguments: [
        "text": "Introduction", "start": 0.2, "end": 1.2, "position": "top",
        "fontSize": 0.08, "weight": "semibold",
      ]
    )
    let overlay = try #require(state.textOverlays.first)
    #expect(overlay.text == "Introduction")
    #expect(overlay.startSeconds == 0.2)
    #expect(overlay.endSeconds == 1.2)
    #expect(overlay.position == .top)
    #expect(added["overlays"]?["text"]?[0]?["id"] == .string(overlay.id.uuidString))

    _ = try await dispatcher.call(
      "update_text",
      arguments: [
        "id": .string(overlay.id.uuidString), "text": "Chapter one", "start": 0.4,
        "end": 1.6, "position": "bottom", "offsetX": 0.1,
      ]
    )
    #expect(state.textOverlays.first?.text == "Chapter one")
    #expect(state.textOverlays.first?.startSeconds == 0.4)
    #expect(state.textOverlays.first?.endSeconds == 1.6)
    #expect(state.textOverlays.first?.position == .bottom)

    _ = try await dispatcher.call("remove_text", arguments: ["id": .string(overlay.id.uuidString)])
    #expect(state.textOverlays.isEmpty)
    state.undo()
    #expect(state.textOverlays.first?.text == "Chapter one")
  }

  @Test func extensiveSilenceRemovalRequiresApprovalForTheExactAnalysis() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let state = try await makeStateWithAudioGap(in: directory, gap: 0.3...1.7)
    defer { state.teardown() }
    let dispatcher = dispatcher(state, in: directory)

    await #expect(throws: AgentToolError.self) {
      try await dispatcher.call(
        "remove_silences",
        arguments: ["source": "mic", "thresholdDb": -40, "minGapSeconds": 0.5, "padding": 0.05]
      )
    }
    let request = try #require(state.agentConfirmations.pending.first)
    #expect(request.operation.kind == "remove_silences")
    #expect(request.operation.arguments["padding"] == 0.05)
    #expect(state.videoRegions.count == 1)
    #expect(state.agentConfirmations.approve(request.id))

    _ = try await dispatcher.call(
      "remove_silences",
      arguments: [
        "source": "mic", "thresholdDb": -40, "minGapSeconds": 0.5, "padding": 0.05,
        "confirmationId": .string(request.id.uuidString),
      ]
    )
    #expect(state.videoRegions.count == 2)
  }

  @Test func imageOverlayToolsRequireExactFileApprovalAndSupportEdits() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let state = try await makeState(in: directory)
    defer { state.teardown() }
    let dispatcher = dispatcher(state, in: directory)
    let source = try ImageFixtures.solidPNG(width: 24, height: 12, in: directory, name: "Logo.png")

    await #expect(throws: AgentToolError.self) {
      try await dispatcher.call(
        "add_image",
        arguments: ["path": .string(source.path), "start": 0.1, "end": 1.1, "position": "topRight"]
      )
    }
    let request = try #require(state.agentConfirmations.pending.first)
    #expect(request.operation == AgentConfirmationOperation.externalFile(kind: "add_image", url: source))
    #expect(state.agentConfirmations.approve(request.id))

    let added = try await dispatcher.call(
      "add_image",
      arguments: [
        "path": .string(source.path), "start": 0.1, "end": 1.1, "position": "topRight",
        "confirmationId": .string(request.id.uuidString),
      ]
    )
    let overlay = try #require(state.imageOverlays.first)
    #expect(overlay.position == .topRight)
    #expect(added["overlays"]?["images"]?[0]?["id"] == .string(overlay.id.uuidString))
    #expect(FileManager.default.fileExists(atPath: state.imageOverlayURL(overlay)?.path ?? ""))

    _ = try await dispatcher.call(
      "update_image",
      arguments: [
        "id": .string(overlay.id.uuidString), "start": 0.4, "end": 1.6,
        "position": "bottomLeft", "width": 0.5, "opacity": 0.75,
      ]
    )
    #expect(state.imageOverlays.first?.position == .bottomLeft)
    #expect(state.imageOverlays.first?.width == 0.5)
    #expect(state.imageOverlays.first?.opacity == 0.75)

    _ = try await dispatcher.call("remove_image", arguments: ["id": .string(overlay.id.uuidString)])
    #expect(state.imageOverlays.isEmpty)
    state.undo()
    #expect(state.imageOverlays.first?.width == 0.5)
  }

  @Test func blurToolsClampCreateUpdateRemoveAndUndo() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let state = try await makeState(in: directory)
    defer { state.teardown() }
    let dispatcher = dispatcher(state, in: directory)

    let added = try await dispatcher.call(
      "add_blur",
      arguments: [
        "start": 0.2,
        "end": 1.2,
        "rect": ["x": 0.9, "y": 0.8, "width": 0.5, "height": 0.5],
        "radius": 24,
      ]
    )
    let region = try #require(state.blurRegions.first)
    #expect(region.startSeconds == 0.2)
    #expect(region.endSeconds == 1.2)
    #expect(abs(region.width - 0.1) < 0.0001)
    #expect(abs(region.height - 0.2) < 0.0001)
    #expect(region.radius == 24)
    #expect(added["overlays"]?["blurs"]?[0]?["id"] == .string(region.id.uuidString))

    _ = try await dispatcher.call(
      "update_blur",
      arguments: [
        "id": .string(region.id.uuidString),
        "start": 0.4,
        "end": 1.6,
        "rect": ["x": 0.1, "y": 0.2, "width": 0.3, "height": 0.4],
        "radius": 36,
      ]
    )
    #expect(state.blurRegions.first?.startSeconds == 0.4)
    #expect(state.blurRegions.first?.endSeconds == 1.6)
    #expect(state.blurRegions.first?.rect == CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4))
    #expect(state.blurRegions.first?.radius == 36)

    _ = try await dispatcher.call("remove_blur", arguments: ["id": .string(region.id.uuidString)])
    #expect(state.blurRegions.isEmpty)
    state.undo()
    #expect(state.blurRegions.first?.radius == 36)
  }

  @Test func exportRequiresApprovalBoundToAnExactNewDestination() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let state = try await makeState(in: directory)
    defer { state.teardown() }
    let dispatcher = dispatcher(state, in: directory)
    let destination = directory.appendingPathComponent("Presentation.mp4")

    await #expect(throws: AgentToolError.self) {
      try await dispatcher.call(
        "export_video",
        arguments: ["destination": .string(destination.path), "format": "mp4"]
      )
    }
    let request = try #require(state.agentConfirmations.pending.first)
    #expect(request.operation.kind == "export_video")
    #expect(request.operation.arguments["destination"] == .string(destination.path))
    #expect(request.operation.arguments["format"] == "mp4")
    #expect(state.history.entries.count == 1)

    try Data().write(to: destination)
    await #expect(throws: AgentToolError.self) {
      try await dispatcher.call(
        "export_video",
        arguments: [
          "destination": .string(destination.path),
          "format": "mp4",
          "confirmationId": .string(request.id.uuidString),
        ]
      )
    }
    #expect(state.agentConfirmations.pending.map(\.id) == [request.id])
  }
}
