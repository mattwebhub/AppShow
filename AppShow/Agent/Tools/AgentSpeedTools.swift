import Foundation

@MainActor
struct AgentSpeedTool: AgentToolHandler {
  enum Action: String { case add, update, remove }
  let action: Action

  var definition: AgentToolDefinition {
    var properties: [String: JSONValue] = [
      "id": AgentToolSchema.string("Speed region UUID"),
      "start": AgentToolSchema.number("Start in source seconds", minimum: 0),
      "end": AgentToolSchema.number("End in source seconds", minimum: 0),
      "rate": [
        "type": "number", "enum": .array(SpeedPreset.allCases.map { .number($0.rawValue) }),
        "description": "Playback speed: 1.5, 2, 4, 8, 16, or 32",
      ],
      "label": AgentToolSchema.string("Short undo-history label"),
    ]
    if action == .remove { properties = properties.filter { $0.key == "id" || $0.key == "label" } }
    return AgentToolDefinition(
      name: "\(action.rawValue)_speed",
      description:
        "\(action.rawValue.capitalized) a timed screen-speed region. Speed up screen content, its system audio and screen effects; webcam, microphone and music stay at 1×. The export ends with the shortened screen. Coordinates are source seconds. Regions cannot overlap. Remove restores normal speed.",
      inputSchema: AgentToolSchema.object(properties, required: action == .add ? ["start", "end", "rate"] : ["id"]),
      mutating: true
    )
  }

  func call(arguments: JSONValue, context: AgentToolContext) async throws -> JSONValue {
    let state = context.editorState
    if action == .add {
      guard let start = arguments["start"]?.doubleValue, let end = arguments["end"]?.doubleValue,
        let rate = arguments["rate"]?.doubleValue
      else { throw AgentToolError.invalidArguments("start, end, and rate are required.") }
      try state.addSpeedRegion(start: start, end: end, rate: rate)
    } else {
      guard let raw = arguments["id"]?.stringValue, let id = UUID(uuidString: raw),
        var region = state.speedRegions.first(where: { $0.id == id })
      else { throw AgentToolError.invalidArguments("Speed region does not exist.") }
      if action == .remove {
        state.removeSpeedRegion(id: id)
      } else {
        region.startSeconds = arguments["start"]?.doubleValue ?? region.startSeconds
        region.endSeconds = arguments["end"]?.doubleValue ?? region.endSeconds
        region.rate = arguments["rate"]?.doubleValue ?? region.rate
        try state.updateSpeedRegion(region)
      }
    }
    return context.timelineResult()
  }
}
