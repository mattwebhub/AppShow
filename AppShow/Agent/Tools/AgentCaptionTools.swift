import Foundation

@MainActor
struct AgentGenerateCaptionsTool: AgentToolHandler {
  var createCaptions = true
  var transcribe: CaptionTranscriber = TranscriptionService.run
  var mutatesOnlyOnSuccess: Bool { true }

  var definition: AgentToolDefinition {
    AgentToolDefinition(
      name: createCaptions ? "generate_captions" : "generate_transcript",
      description: createCaptions
        ? "Generate timed captions locally from a recorded audio track, using cleaned microphone audio when enabled. Requires an installed Whisper model; never downloads models. Completes with one undo step. Use set_captions for styling and replace_captions for manual text."
        : "Transcribe recorded audio locally for agent context without enabling or changing visible captions. Saves source-time segments and word timestamps for get_transcript and frame context. Requires an installed Whisper model; never downloads models.",
      inputSchema: AgentToolSchema.object([
        "source": AgentToolSchema.string("Audio source; defaults to the Captions panel selection", enum: ["mic", "system"]),
        "model": AgentToolSchema.string(
          "Installed Whisper model; defaults to the Captions panel selection",
          enum: WhisperModel.allCases.map(\.rawValue)
        ),
        "label": AgentToolSchema.string("Short undo-history label"),
      ]),
      mutating: true,
      slow: true
    )
  }

  func call(arguments: JSONValue, context: AgentToolContext) async throws -> JSONValue {
    let source: CaptionAudioSource? = arguments["source"]?.stringValue.map { $0 == "system" ? .system : .microphone }
    try await context.editorState.transcribeCaptions(
      source: source,
      model: arguments["model"]?.stringValue.flatMap(WhisperModel.init(rawValue:)),
      createCaptions: createCaptions,
      historyLabel: "Agent: \(arguments["label"]?.stringValue ?? (createCaptions ? "generate captions" : "generate transcript"))",
      using: transcribe
    )
    return context.timelineResult()
  }
}
