import Foundation

enum AgentToolCatalog {
  static let serverName = "appshow"
  static let protocolVersion = "2025-06-18"

  static let getProjectSummary = AgentToolDefinition(
    name: "get_project_summary",
    description:
      "Describe the open recording: name, bundle path, duration, frame rate, screen size, which media tracks exist, and the history position.",
    inputSchema: AgentToolSchema.object([:]),
    mutating: false
  )

  static let getTimeline = AgentToolDefinition(
    name: "get_timeline",
    description:
      "Return the compact timeline: trim, kept slices and gaps, zoom keyframes, spotlight and camera regions, caption segments, audio tracks, background, canvas, history. Times are seconds in source time. detail=full adds the raw editor snapshot.",
    inputSchema: AgentToolSchema.object([
      "detail": AgentToolSchema.string("summary (default) or full", enum: ["summary", "full"])
    ]),
    mutating: false
  )

  static let getTranscript = AgentToolDefinition(
    name: "get_transcript",
    description:
      "Return the caption segments with text and timing; withWords adds per-word timestamps; from/to keep only segments overlapping that range.",
    inputSchema: AgentToolSchema.object([
      "withWords": AgentToolSchema.boolean("Include per-word timestamps when the segment has them"),
      "from": AgentToolSchema.number("Window start in seconds", minimum: 0),
      "to": AgentToolSchema.number("Window end in seconds", minimum: 0),
    ]),
    mutating: false
  )

  static let getCursorActivity = AgentToolDefinition(
    name: "get_cursor_activity",
    description:
      "Return click clusters (clicks closer than dwellSeconds are grouped, with centre and time range) and keystroke bursts from the recorded cursor metadata.",
    inputSchema: AgentToolSchema.object([
      "dwellSeconds": AgentToolSchema.number("Maximum gap between clicks of one cluster, default 0.5", minimum: 0, maximum: 60),
      "from": AgentToolSchema.number("Window start in seconds", minimum: 0),
      "to": AgentToolSchema.number("Window end in seconds", minimum: 0),
    ]),
    mutating: false
  )

  static let getHistory = AgentToolDefinition(
    name: "get_history",
    description:
      "Return the undo history: every entry with its index, timestamp, label, and the changes it introduced, plus the current index.",
    inputSchema: AgentToolSchema.object([:]),
    mutating: false
  )

  static let renderPreviewFrame = AgentToolDefinition(
    name: "render_preview_frame",
    description:
      "Render one frame of the current edit (background, canvas, camera, cursor, zoom, spotlight, captions) at atSeconds to a PNG in the workspace frames folder and return its path. Slow: about a second per call.",
    inputSchema: AgentToolSchema.object(
      [
        "atSeconds": AgentToolSchema.number("Source time of the frame in seconds", minimum: 0),
        "width": AgentToolSchema.integer(
          "Output width in pixels, default 640",
          minimum: Double(AgentToolPreviewFrame.minWidth),
          maximum: Double(AgentToolPreviewFrame.maxWidth)
        ),
      ],
      required: ["atSeconds"]
    ),
    mutating: false,
    slow: true
  )

  static let getSilences = AgentToolDefinition(
    name: "get_silences",
    description: "Return the silent gaps of the microphone or system audio longer than minGapSeconds and quieter than thresholdDb.",
    inputSchema: AgentToolSchema.object([
      "thresholdDb": AgentToolSchema.number("Silence threshold in dBFS, default -40", minimum: -120, maximum: 0),
      "minGapSeconds": AgentToolSchema.number("Shortest gap to report, default 0.8", minimum: 0),
      "source": AgentToolSchema.string("Audio track to analyse", enum: ["mic", "system"]),
    ]),
    mutating: false,
    slow: true
  )

  static let all: [AgentToolDefinition] = [
    getProjectSummary, getTimeline, getTranscript, getCursorActivity, getHistory, renderPreviewFrame, getSilences,
  ]

  static var available: [AgentToolDefinition] {
    all.filter(\.isAvailable)
  }

  static func definition(named name: String) -> AgentToolDefinition? {
    all.first { $0.name == name }
  }

  static var toolsListResult: JSONValue {
    ["tools": .array(available.map(\.mcpValue))]
  }

  @MainActor
  static func readOnlyHandlers() -> [any AgentToolHandler] {
    [
      AgentToolProjectSummaryHandler(),
      AgentToolTimelineHandler(),
      AgentToolTranscriptHandler(),
      AgentToolCursorActivityHandler(),
      AgentToolHistoryHandler(),
      AgentToolPreviewFrameHandler(),
      AgentToolSilencesHandler(),
    ]
  }
}
