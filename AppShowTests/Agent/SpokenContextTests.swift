import Foundation
import Testing

@testable import AppShow

@MainActor
@Suite(.serialized)
struct SpokenContextTests {
  @Test func narrationSurvivesCaptionEditsAndProjectReopening() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let media = directory.appendingPathComponent("media")
    try FileManager.default.createDirectory(at: media, withIntermediateDirectories: true)
    let result = try await ProjectFixtures.recordingResult(in: media, webcam: true, systemAudio: false, microphone: true, cursor: false)
    let project = try AppShowProject.create(from: result, fps: result.fps, captureMode: .entireScreen, in: directory, cleanupTemp: false)
    let state = EditorState(project: project)
    await state.setup()
    defer { state.teardown() }
    try await state.transcribeCaptions(using: { _ in
      [
        CaptionSegment(
          startSeconds: 0.2,
          endSeconds: 1.2,
          text: "Open the settings panel",
          words: [CaptionWord(word: "settings", startSeconds: 0.5, endSeconds: 0.8)]
        )
      ]
    })
    state.clearCaptions()
    state.saveState()
    let reopened = EditorState(project: try AppShowProject.open(at: project.bundleURL))
    await reopened.setup()
    defer { reopened.teardown() }
    let dispatcher = AgentToolDispatcher(editorState: reopened, framesDirectory: directory.appendingPathComponent("frames"))
    let transcript = try await dispatcher.call("get_transcript", arguments: ["withWords": true])
    #expect(transcript["origin"] == "recordedAudio")
    #expect(transcript["segments"]?[0]?["text"] == "Open the settings panel")
    #expect(transcript["segments"]?[0]?["words"]?[0]?["word"] == "settings")
    let missingSource = try await dispatcher.call("get_transcript", arguments: ["source": "system"])
    #expect(missingSource["count"] == 0)
    #expect(missingSource["source"] == "system")
    let summary = try await dispatcher.call("get_project_summary", arguments: [:])
    #expect(summary["spokenContext"]?["available"] == true)
    #expect(summary["spokenContext"]?["excerpt"] == "Open the settings panel")
    let frame = try await dispatcher.call("render_preview_frame", arguments: ["atSeconds": 0.6, "width": 160])
    #expect(frame["spokenContext"]?["timeBase"] == "source")
    #expect(frame["spokenContext"]?["segments"]?[0]?["text"] == "Open the settings panel")
    #expect(reopened.captionSegments.isEmpty)
  }

  @Test func transcriptOnlyGenerationDoesNotEnableOrReplaceCaptions() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let result = try await ProjectFixtures.recordingResult(
      in: directory,
      webcam: false,
      systemAudio: false,
      microphone: true,
      cursor: false
    )
    let state = EditorState(result: result)
    await state.setup()
    defer { state.teardown() }
    let existing = CaptionSegment(startSeconds: 0, endSeconds: 1, text: "Edited title")
    state.captionSegments = [existing]
    state.captionsEnabled = false
    let tool = AgentGenerateCaptionsTool(
      createCaptions: false,
      transcribe: { _ in
        [CaptionSegment(startSeconds: 0, endSeconds: 1, text: "Narrated explanation")]
      }
    )
    let dispatcher = AgentToolDispatcher(editorState: state, framesDirectory: directory, handlers: [tool], allowsMutations: true)
    _ = try await dispatcher.call("generate_transcript", arguments: [:])
    #expect(state.captionSegments == [existing])
    #expect(!state.captionsEnabled)
    #expect(state.audioTranscripts.first?.segments.first?.text == "Narrated explanation")
    state.undo()
    #expect(state.audioTranscripts.isEmpty)
    #expect(state.captionSegments == [existing])
  }
}
