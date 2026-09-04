import CoreMedia
import Foundation
import Testing

@testable import Reframed

@MainActor
@Suite(.serialized)
struct MutatingToolsTests {
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

  private func makeState(in directory: URL) async throws -> EditorState {
    let sources = directory.appendingPathComponent("sources", isDirectory: true)
    try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)
    let result = try await ProjectFixtures.recordingResult(
      in: sources,
      webcam: false,
      systemAudio: false,
      microphone: false,
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
        of: ["set_trim", "add_zoom", "add_spotlight", "set_kept_slices", "remove_time_range", "begin_batch", "end_batch"]
      )
    )
    let trim = try #require(definitions.first { $0.name == "set_trim" })
    #expect(trim.mcpValue["annotations"]?["readOnlyHint"] == false)
    #expect(trim.mcpValue["annotations"]?["destructiveHint"] == true)
  }
}
