import Foundation
import Testing

@testable import AppShow

@MainActor
@Suite(.serialized)
struct WebcamVoiceToolTests {
  @Test func catalogKeepsNamesAndGroupsEditorFeatures() {
    let definitions = AgentEditingToolCatalog.handlers.map(\.definition)
    #expect(Set(definitions.map(\.name)).count == definitions.count)
    for name in ["add_camera_region", "update_camera_region", "remove_camera_region"] {
      let tool = definitions.first { $0.name == name }
      #expect(tool?.mcpValue["annotations"]?["title"]?.stringValue?.hasPrefix("Webcam · ") == true)
    }
    #expect(definitions.contains { $0.name == "generate_captions" && $0.mutating && $0.slow })
    #expect(
      definitions.first { $0.name == "remove_silences" }?.mcpValue["annotations"]?["title"]?.stringValue?.hasPrefix("Cuts · ") == true
    )
  }

  @Test func captionToolCreatesOneUndoAndFailurePreservesConcurrentEdits() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let result = try await ProjectFixtures.recordingResult(in: directory, webcam: true, systemAudio: false, microphone: true, cursor: false)
    let state = EditorState(result: result)
    await state.setup()
    defer { state.teardown() }
    let tool = AgentGenerateCaptionsTool(transcribe: { _ in [CaptionSegment(startSeconds: 0, endSeconds: 1, text: "Voice caption")] })
    let dispatcher = AgentToolDispatcher(editorState: state, framesDirectory: directory, handlers: [tool], allowsMutations: true)
    let before = state.history.entries.count
    _ = try await dispatcher.call("generate_captions", arguments: [:])
    #expect(state.captionSegments.first?.text == "Voice caption")
    #expect(state.history.entries.count == before + 1)
    #expect(state.history.entries.last?.label == "Agent: generate captions")
    state.undo()
    #expect(state.captionSegments.isEmpty)
    let edited = CaptionSegment(startSeconds: 0, endSeconds: 1, text: "Keep this edit")
    dispatcher.register(
      AgentGenerateCaptionsTool(transcribe: { _ in
        await MainActor.run { state.captionSegments = [edited] }
        throw CaptionGenerationError(message: "Engine failed")
      })
    )
    do { _ = try await dispatcher.call("generate_captions", arguments: [:]); Issue.record("Expected failure") } catch {}
    #expect(state.captionSegments == [edited])
  }
  @Test func cancelingABatchDuringTranscriptionCannotApplyItsLateResult() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let result = try await ProjectFixtures.recordingResult(in: directory, webcam: true, systemAudio: false, microphone: true, cursor: false)
    let state = EditorState(result: result)
    await state.setup()
    defer { state.teardown() }
    let dispatcher = AgentToolDispatcher(
      editorState: state,
      framesDirectory: directory,
      handlers: AgentEditingToolCatalog.handlers,
      allowsMutations: true
    )
    dispatcher.register(
      AgentGenerateCaptionsTool(transcribe: { _ in
        await MainActor.run { dispatcher.cancelBatch() }
        return [CaptionSegment(startSeconds: 0, endSeconds: 1, text: "Late batch result")]
      })
    )
    _ = try await dispatcher.call("begin_batch", arguments: ["label": "Narration"])
    do { _ = try await dispatcher.call("generate_captions", arguments: [:]); Issue.record("Expected canceled batch") } catch {}
    #expect(state.captionSegments.isEmpty)
  }

}
