import CoreMedia
import Foundation

enum AgentEditingToolCatalog {
  static let setTrim = AgentToolDefinition(
    name: "set_trim",
    description: "Set the source-time trim range and return the updated timeline.",
    inputSchema: AgentToolSchema.object(
      [
        "start": AgentToolSchema.number("Trim start in source seconds", minimum: 0),
        "end": AgentToolSchema.number("Trim end in source seconds", minimum: 0),
        "label": AgentToolSchema.string("Short undo-history label"),
      ],
      required: ["start", "end"]
    ),
    mutating: true
  )

  static let addZoom = AgentToolDefinition(
    name: "add_zoom",
    description: "Add a manual zoom centred at a source time and return the updated timeline.",
    inputSchema: AgentToolSchema.object(
      [
        "at": AgentToolSchema.number("Zoom centre time in source seconds", minimum: 0),
        "centerX": AgentToolSchema.number("Horizontal centre from 0 to 1", minimum: 0, maximum: 1),
        "centerY": AgentToolSchema.number("Vertical centre from 0 to 1", minimum: 0, maximum: 1),
        "level": AgentToolSchema.number("Zoom level from 1 to 8", minimum: 1, maximum: 8),
        "label": AgentToolSchema.string("Short undo-history label"),
      ],
      required: ["at", "centerX", "centerY"]
    ),
    mutating: true
  )

  static let addSpotlight = AgentToolDefinition(
    name: "add_spotlight",
    description: "Add a spotlight region over a source-time range and return the updated timeline.",
    inputSchema: AgentToolSchema.object(
      [
        "start": AgentToolSchema.number("Region start in source seconds", minimum: 0),
        "end": AgentToolSchema.number("Region end in source seconds", minimum: 0),
        "radius": AgentToolSchema.number("Spotlight radius in pixels", minimum: 50, maximum: 500),
        "dimOpacity": AgentToolSchema.number("Dim opacity from 0.1 to 0.95", minimum: 0.1, maximum: 0.95),
        "edgeSoftness": AgentToolSchema.number("Edge softness in pixels", minimum: 0, maximum: 200),
        "fadeDuration": AgentToolSchema.number("Fade duration in seconds", minimum: 0, maximum: 1),
        "label": AgentToolSchema.string("Short undo-history label"),
      ],
      required: ["start", "end"]
    ),
    mutating: true
  )

  static let setKeptSlices = AgentToolDefinition(
    name: "set_kept_slices",
    description: "Replace the source-time slices kept in the final video and return the normalized timeline.",
    inputSchema: AgentToolSchema.object(
      [
        "slices": AgentToolSchema.array(
          "Source-time ranges to keep",
          items: AgentToolSchema.object(
            [
              "start": AgentToolSchema.number("Slice start in source seconds", minimum: 0),
              "end": AgentToolSchema.number("Slice end in source seconds", minimum: 0),
            ],
            required: ["start", "end"]
          ),
          minimumItems: 1
        ),
        "label": AgentToolSchema.string("Short undo-history label"),
      ],
      required: ["slices"]
    ),
    mutating: true
  )

  static let removeTimeRange = AgentToolDefinition(
    name: "remove_time_range",
    description: "Remove an exact source-time range from the kept video and return the updated timeline.",
    inputSchema: AgentToolSchema.object(
      [
        "start": AgentToolSchema.number("Removed range start in source seconds", minimum: 0),
        "end": AgentToolSchema.number("Removed range end in source seconds", minimum: 0),
        "label": AgentToolSchema.string("Short undo-history label"),
      ],
      required: ["start", "end"]
    ),
    mutating: true
  )

  static let beginBatch = AgentToolDefinition(
    name: "begin_batch",
    description: "Begin a labeled edit transaction whose mutations become one undo step.",
    inputSchema: AgentToolSchema.object(
      ["label": AgentToolSchema.string("Short undo-history label")],
      required: ["label"]
    ),
    mutating: true
  )

  static let endBatch = AgentToolDefinition(
    name: "end_batch",
    description: "Commit the active edit transaction as one undo step.",
    inputSchema: AgentToolSchema.object([:]),
    mutating: true
  )

  @MainActor
  static var handlers: [any AgentToolHandler] {
    [
      AgentSetTrimTool(),
      AgentAddZoomTool(),
      AgentAddSpotlightTool(),
      AgentSetKeptSlicesTool(),
      AgentRemoveTimeRangeTool(),
      AgentBatchBoundaryTool(definition: beginBatch),
      AgentBatchBoundaryTool(definition: endBatch),
    ]
  }
}

extension AgentToolContext {
  @MainActor
  func timelineResult() -> JSONValue {
    AgentToolSummaries.timeline(
      snapshot: editorState.createSnapshot(),
      duration: CMTimeGetSeconds(editorState.duration),
      media: editorState.agentMediaInfo,
      historyIndex: editorState.history.currentIndex,
      historyCount: editorState.history.entries.count
    )
  }
}

@MainActor
private struct AgentSetTrimTool: AgentToolHandler {
  let definition = AgentEditingToolCatalog.setTrim

  func call(arguments: JSONValue, context: AgentToolContext) async throws -> JSONValue {
    let duration = CMTimeGetSeconds(context.editorState.duration)
    let start = min(arguments["start"]?.doubleValue ?? 0, duration)
    let end = min(arguments["end"]?.doubleValue ?? duration, duration)
    guard end > start else {
      throw AgentToolError.invalidArguments("end must be greater than start")
    }
    context.editorState.updateTrimStart(CMTime(seconds: start, preferredTimescale: 600))
    context.editorState.updateTrimEnd(CMTime(seconds: end, preferredTimescale: 600))
    return context.timelineResult()
  }
}

@MainActor
private struct AgentAddZoomTool: AgentToolHandler {
  let definition = AgentEditingToolCatalog.addZoom

  func call(arguments: JSONValue, context: AgentToolContext) async throws -> JSONValue {
    let state = context.editorState
    let duration = CMTimeGetSeconds(state.duration)
    let time = min(arguments["at"]?.doubleValue ?? 0, duration)
    state.zoomLevel = arguments["level"]?.doubleValue ?? state.zoomLevel
    state.zoomEnabled = true
    state.addManualZoomKeyframe(
      at: time,
      center: CGPoint(
        x: arguments["centerX"]?.doubleValue ?? 0.5,
        y: arguments["centerY"]?.doubleValue ?? 0.5
      )
    )
    return context.timelineResult()
  }
}

@MainActor
private struct AgentAddSpotlightTool: AgentToolHandler {
  let definition = AgentEditingToolCatalog.addSpotlight

  func call(arguments: JSONValue, context: AgentToolContext) async throws -> JSONValue {
    let state = context.editorState
    let duration = CMTimeGetSeconds(state.duration)
    let start = min(arguments["start"]?.doubleValue ?? 0, duration)
    let end = min(arguments["end"]?.doubleValue ?? duration, duration)
    guard end > start else {
      throw AgentToolError.invalidArguments("end must be greater than start")
    }
    let radius = arguments["radius"]?.doubleValue.map { CGFloat($0) }
    let dimOpacity = arguments["dimOpacity"]?.doubleValue.map { CGFloat($0) }
    let edgeSoftness = arguments["edgeSoftness"]?.doubleValue.map { CGFloat($0) }
    state.spotlightEnabled = true
    state.spotlightRegions.append(
      SpotlightRegionData(
        startSeconds: start,
        endSeconds: end,
        customRadius: radius,
        customDimOpacity: dimOpacity,
        customEdgeSoftness: edgeSoftness,
        fadeDuration: arguments["fadeDuration"]?.doubleValue
      )
    )
    state.spotlightRegions.sort { $0.startSeconds < $1.startSeconds }
    return context.timelineResult()
  }
}

@MainActor
private struct AgentSetKeptSlicesTool: AgentToolHandler {
  let definition = AgentEditingToolCatalog.setKeptSlices

  func call(arguments: JSONValue, context: AgentToolContext) async throws -> JSONValue {
    let duration = CMTimeGetSeconds(context.editorState.duration)
    let slices = try (arguments["slices"]?.arrayValue ?? []).map { value -> VideoRegionData in
      let start = min(value["start"]?.doubleValue ?? 0, duration)
      let end = min(value["end"]?.doubleValue ?? duration, duration)
      guard end - start >= CutTimeline.minSliceLength else {
        throw AgentToolError.invalidArguments("every kept slice must be at least \(CutTimeline.minSliceLength) seconds")
      }
      return VideoRegionData(startSeconds: start, endSeconds: end)
    }
    let timeline = CutTimeline(slices: slices, duration: duration).normalized()
    guard !timeline.slices.isEmpty else {
      throw AgentToolError.invalidArguments("at least one kept slice must remain")
    }
    context.editorState.videoRegions = timeline.slices
    return context.timelineResult()
  }
}

@MainActor
private struct AgentRemoveTimeRangeTool: AgentToolHandler {
  let definition = AgentEditingToolCatalog.removeTimeRange

  func call(arguments: JSONValue, context: AgentToolContext) async throws -> JSONValue {
    let duration = CMTimeGetSeconds(context.editorState.duration)
    let start = min(arguments["start"]?.doubleValue ?? 0, duration)
    let end = min(arguments["end"]?.doubleValue ?? duration, duration)
    guard end - start >= CutTimeline.minSliceLength else {
      throw AgentToolError.invalidArguments("end must be at least \(CutTimeline.minSliceLength) seconds after start")
    }
    let timeline = context.editorState.cutTimeline.removing(start...end)
    guard !timeline.slices.isEmpty else {
      throw AgentToolError.invalidArguments("removing the entire video is not allowed")
    }
    context.editorState.videoRegions = timeline.slices
    return context.timelineResult()
  }
}

@MainActor
private struct AgentBatchBoundaryTool: AgentToolHandler {
  let definition: AgentToolDefinition

  func call(arguments: JSONValue, context: AgentToolContext) async throws -> JSONValue {
    context.timelineResult()
  }
}
