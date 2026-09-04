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

  static let setCanvas = AgentToolDefinition(
    name: "set_canvas",
    description: "Set canvas aspect, spacing, video styling, and background.",
    inputSchema: AgentToolSchema.object([
      "aspect": AgentToolSchema.string("Canvas aspect", enum: CanvasAspect.allCases.map(\.rawValue)),
      "padding": AgentToolSchema.number("Canvas padding from 0 to 0.4", minimum: 0, maximum: 0.4),
      "cornerRadius": AgentToolSchema.number("Video corner radius", minimum: 0, maximum: 100),
      "shadow": AgentToolSchema.number("Video shadow from 0 to 1", minimum: 0, maximum: 1),
      "background": AgentToolSchema.string("Background type", enum: ["none", "solid", "gradient"]),
      "gradient": AgentToolSchema.integer("Gradient preset index", minimum: 0, maximum: 32),
      "red": AgentToolSchema.number("Solid background red channel", minimum: 0, maximum: 1),
      "green": AgentToolSchema.number("Solid background green channel", minimum: 0, maximum: 1),
      "blue": AgentToolSchema.number("Solid background blue channel", minimum: 0, maximum: 1),
      "label": AgentToolSchema.string("Short undo-history label"),
    ]),
    mutating: true
  )

  static let setCaptions = AgentToolDefinition(
    name: "set_captions",
    description: "Configure caption visibility, typography, position, and line length.",
    inputSchema: AgentToolSchema.object([
      "enabled": AgentToolSchema.boolean("Whether captions are visible"),
      "fontSize": AgentToolSchema.number("Caption font size", minimum: 12, maximum: 200),
      "weight": AgentToolSchema.string("Caption weight", enum: CaptionFontWeight.allCases.map(\.rawValue)),
      "positionX": AgentToolSchema.number("Horizontal position from 0 to 1", minimum: 0, maximum: 1),
      "positionY": AgentToolSchema.number("Vertical position from 0 to 1", minimum: 0, maximum: 1),
      "maxWordsPerLine": AgentToolSchema.integer("Maximum words per line", minimum: 1, maximum: 20),
      "showBackground": AgentToolSchema.boolean("Whether captions have a background"),
      "backgroundOpacity": AgentToolSchema.number("Caption background opacity", minimum: 0, maximum: 1),
      "label": AgentToolSchema.string("Short undo-history label"),
    ]),
    mutating: true
  )

  static let replaceCaptions = AgentToolDefinition(
    name: "replace_captions",
    description: "Replace all timed caption segments in source time.",
    inputSchema: AgentToolSchema.object(
      [
        "segments": AgentToolSchema.array(
          "Timed caption segments",
          items: AgentToolSchema.object(
            [
              "start": AgentToolSchema.number("Segment start in source seconds", minimum: 0),
              "end": AgentToolSchema.number("Segment end in source seconds", minimum: 0),
              "text": AgentToolSchema.string("Caption text"),
            ],
            required: ["start", "end", "text"]
          )
        ),
        "label": AgentToolSchema.string("Short undo-history label"),
      ],
      required: ["segments"]
    ),
    mutating: true
  )

  static let setCursor = AgentToolDefinition(
    name: "set_cursor",
    description: "Configure cursor visibility, style, size, and click effects.",
    inputSchema: AgentToolSchema.object([
      "visible": AgentToolSchema.boolean("Whether the cursor is visible"),
      "style": AgentToolSchema.integer("Cursor style index from 0 to 21", minimum: 0, maximum: 21),
      "size": AgentToolSchema.number("Cursor size in pixels", minimum: 8, maximum: 128),
      "clickHighlights": AgentToolSchema.boolean("Whether clicks show a highlight"),
      "clickHighlightSize": AgentToolSchema.number("Click highlight size", minimum: 8, maximum: 160),
      "clickSound": AgentToolSchema.boolean("Whether clicks play a sound"),
      "clickSoundVolume": AgentToolSchema.number("Click sound volume", minimum: 0, maximum: 1),
      "label": AgentToolSchema.string("Short undo-history label"),
    ]),
    mutating: true
  )

  static let setCamera = AgentToolDefinition(
    name: "set_camera",
    description: "Configure camera visibility, layout, aspect, and styling.",
    inputSchema: AgentToolSchema.object([
      "enabled": AgentToolSchema.boolean("Whether the camera is visible"),
      "x": AgentToolSchema.number("Horizontal position from 0 to 1", minimum: 0, maximum: 1),
      "y": AgentToolSchema.number("Vertical position from 0 to 1", minimum: 0, maximum: 1),
      "width": AgentToolSchema.number("Relative width from 0.05 to 1", minimum: 0.05, maximum: 1),
      "aspect": AgentToolSchema.string("Camera aspect", enum: CameraAspect.allCases.map(\.rawValue)),
      "cornerRadius": AgentToolSchema.number("Camera corner radius", minimum: 0, maximum: 100),
      "borderWidth": AgentToolSchema.number("Camera border width", minimum: 0, maximum: 20),
      "shadow": AgentToolSchema.number("Camera shadow from 0 to 1", minimum: 0, maximum: 1),
      "mirrored": AgentToolSchema.boolean("Whether the camera is mirrored"),
      "label": AgentToolSchema.string("Short undo-history label"),
    ]),
    mutating: true
  )

  static let setAudio = AgentToolDefinition(
    name: "set_audio",
    description: "Configure captured system and microphone audio levels.",
    inputSchema: AgentToolSchema.object([
      "systemVolume": AgentToolSchema.number("System audio volume", minimum: 0, maximum: 2),
      "microphoneVolume": AgentToolSchema.number("Microphone volume", minimum: 0, maximum: 2),
      "systemMuted": AgentToolSchema.boolean("Whether system audio is muted"),
      "microphoneMuted": AgentToolSchema.boolean("Whether microphone audio is muted"),
      "label": AgentToolSchema.string("Short undo-history label"),
    ]),
    mutating: true
  )

  static let exportVideo = AgentToolDefinition(
    name: "export_video",
    description: "Export to an exact new file after one in-app confirmation. Existing files are never overwritten.",
    inputSchema: AgentToolSchema.object(
      [
        "destination": AgentToolSchema.string("Absolute destination file path"),
        "format": AgentToolSchema.string("Export format", enum: ["mp4", "mov", "gif"]),
        "confirmationId": AgentToolSchema.string("Single-use confirmation identifier"),
        "label": AgentToolSchema.string("Activity label"),
      ],
      required: ["destination", "format"]
    ),
    mutating: true,
    slow: true
  )

  static let removeSilences = AgentToolDefinition(
    name: "remove_silences",
    description: "Detect silent audio gaps and remove them from the kept video, preserving speech padding.",
    inputSchema: AgentToolSchema.object([
      "thresholdDb": AgentToolSchema.number("Silence threshold in dBFS, default -40", minimum: -120, maximum: 0),
      "minGapSeconds": AgentToolSchema.number("Shortest gap to remove, default 0.8", minimum: 0),
      "padding": AgentToolSchema.number("Speech padding on each side, default 0.15", minimum: 0, maximum: 2),
      "source": AgentToolSchema.string("Audio track to analyse", enum: ["mic", "system"]),
      "confirmationId": AgentToolSchema.string("Single-use confirmation required when more than 40% would be removed"),
      "label": AgentToolSchema.string("Short undo-history label"),
    ]),
    mutating: true,
    slow: true
  )

  static let addText = AgentToolDefinition(
    name: "add_text",
    description: "Add a styled text overlay over an exact source-time range.",
    inputSchema: textOverlaySchema(requireIdentity: false),
    mutating: true
  )

  static let updateText = AgentToolDefinition(
    name: "update_text",
    description: "Update an existing text overlay by id.",
    inputSchema: textOverlaySchema(requireIdentity: true, requireContent: false),
    mutating: true
  )

  static let removeText = AgentToolDefinition(
    name: "remove_text",
    description: "Remove a text overlay by id.",
    inputSchema: AgentToolSchema.object(
      ["id": AgentToolSchema.string("Text overlay UUID"), "label": AgentToolSchema.string("Short undo-history label")],
      required: ["id"]
    ),
    mutating: true
  )

  static let addImage = AgentToolDefinition(
    name: "add_image",
    description: "Import an image from an exact path after in-app confirmation and add it as an overlay.",
    inputSchema: imageOverlaySchema(requirePath: true),
    mutating: true
  )

  static let updateImage = AgentToolDefinition(
    name: "update_image",
    description: "Update an existing image overlay by id.",
    inputSchema: imageOverlaySchema(requireIdentity: true),
    mutating: true
  )

  static let removeImage = AgentToolDefinition(
    name: "remove_image",
    description: "Remove an image overlay by id while retaining its bundled asset for undo.",
    inputSchema: AgentToolSchema.object(
      ["id": AgentToolSchema.string("Image overlay UUID"), "label": AgentToolSchema.string("Short undo-history label")],
      required: ["id"]
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
      AgentSetCanvasTool(),
      AgentSetCaptionsTool(),
      AgentReplaceCaptionsTool(),
      AgentSetCursorTool(),
      AgentSetCameraTool(),
      AgentSetAudioTool(),
      AgentExportVideoTool(),
      AgentRemoveSilencesTool(),
      AgentAddTextTool(),
      AgentUpdateTextTool(),
      AgentRemoveTextTool(),
      AgentAddImageTool(),
      AgentUpdateImageTool(),
      AgentRemoveImageTool(),
      AgentBatchBoundaryTool(definition: beginBatch),
      AgentBatchBoundaryTool(definition: endBatch),
    ]
  }

  private static func textOverlaySchema(
    requireIdentity: Bool,
    requireContent: Bool = true
  ) -> JSONValue {
    var properties = overlayProperties()
    properties["id"] = AgentToolSchema.string("Text overlay UUID")
    properties["text"] = AgentToolSchema.string("Displayed text")
    properties["fontSize"] = AgentToolSchema.number("Font size as a canvas-height fraction", minimum: 0.01, maximum: 0.3)
    properties["weight"] = AgentToolSchema.string("Font weight", enum: CaptionFontWeight.allCases.map(\.rawValue))
    properties["showBackground"] = AgentToolSchema.boolean("Whether to draw a background pill")
    properties["backgroundOpacity"] = AgentToolSchema.number("Background opacity", minimum: 0, maximum: 1)
    var required: [String] = []
    if requireIdentity { required.append("id") }
    if requireContent { required.append(contentsOf: ["text", "start", "end"]) }
    return AgentToolSchema.object(properties, required: required)
  }

  private static func imageOverlaySchema(requirePath: Bool = false, requireIdentity: Bool = false) -> JSONValue {
    var properties = overlayProperties()
    properties["id"] = AgentToolSchema.string("Image overlay UUID")
    properties["path"] = AgentToolSchema.string("Absolute source image path")
    properties["confirmationId"] = AgentToolSchema.string("Single-use confirmation identifier")
    properties["width"] = AgentToolSchema.number("Width as a canvas fraction", minimum: 0.01, maximum: 1)
    properties["cornerRadius"] = AgentToolSchema.number("Corner radius relative to image size", minimum: 0, maximum: 1)
    properties["opacity"] = AgentToolSchema.number("Image opacity", minimum: 0, maximum: 1)
    properties["shadow"] = AgentToolSchema.number("Shadow strength", minimum: 0, maximum: 1)
    var required: [String] = []
    if requirePath { required.append(contentsOf: ["path", "start", "end"]) }
    if requireIdentity { required.append("id") }
    return AgentToolSchema.object(properties, required: required)
  }

  private static func overlayProperties() -> [String: JSONValue] {
    [
      "start": AgentToolSchema.number("Start in source seconds", minimum: 0),
      "end": AgentToolSchema.number("End in source seconds", minimum: 0),
      "position": AgentToolSchema.string("Position preset", enum: TextOverlayPosition.allCases.map(\.rawValue)),
      "offsetX": AgentToolSchema.number("Horizontal canvas offset", minimum: -1, maximum: 1),
      "offsetY": AgentToolSchema.number("Vertical canvas offset", minimum: -1, maximum: 1),
      "entryTransition": AgentToolSchema.string("Entry transition", enum: RegionTransitionType.allCases.map(\.rawValue)),
      "entryDuration": AgentToolSchema.number("Entry transition duration", minimum: 0, maximum: 5),
      "exitTransition": AgentToolSchema.string("Exit transition", enum: RegionTransitionType.allCases.map(\.rawValue)),
      "exitDuration": AgentToolSchema.number("Exit transition duration", minimum: 0, maximum: 5),
      "label": AgentToolSchema.string("Short undo-history label"),
    ]
  }
}

extension AgentToolContext {
  @MainActor
  func timelineResult() -> JSONValue {
    let result = AgentToolSummaries.timeline(
      snapshot: editorState.createSnapshot(),
      duration: CMTimeGetSeconds(editorState.duration),
      media: editorState.agentMediaInfo,
      historyIndex: editorState.history.currentIndex,
      historyCount: editorState.history.entries.count
    )
    guard let url = editorState.lastExportedURL, case .object(var object) = result else { return result }
    object["lastExportedPath"] = .string(url.path)
    return .object(object)
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
private struct AgentSetCanvasTool: AgentToolHandler {
  let definition = AgentEditingToolCatalog.setCanvas

  func call(arguments: JSONValue, context: AgentToolContext) async throws -> JSONValue {
    let state = context.editorState
    if let value = arguments["aspect"]?.stringValue, let aspect = CanvasAspect(rawValue: value) {
      state.canvasAspect = aspect
    }
    if let value = arguments["padding"]?.doubleValue { state.padding = value }
    if let value = arguments["cornerRadius"]?.doubleValue { state.videoCornerRadius = value }
    if let value = arguments["shadow"]?.doubleValue { state.videoShadow = value }
    if let background = arguments["background"]?.stringValue {
      switch background {
      case "none":
        state.backgroundStyle = .none
      case "gradient":
        let identifier = arguments["gradient"]?.intValue ?? 0
        guard GradientPresets.all.contains(where: { $0.id == identifier }) else {
          throw AgentToolError.invalidArguments("gradient does not identify a preset")
        }
        state.backgroundStyle = .gradient(identifier)
      case "solid":
        state.backgroundStyle = .solidColor(
          CodableColor(
            r: arguments["red"]?.doubleValue ?? 0,
            g: arguments["green"]?.doubleValue ?? 0,
            b: arguments["blue"]?.doubleValue ?? 0
          )
        )
      default:
        break
      }
    }
    return context.timelineResult()
  }
}

@MainActor
private struct AgentSetCaptionsTool: AgentToolHandler {
  let definition = AgentEditingToolCatalog.setCaptions

  func call(arguments: JSONValue, context: AgentToolContext) async throws -> JSONValue {
    let state = context.editorState
    if let value = arguments["enabled"]?.boolValue { state.captionsEnabled = value }
    if let value = arguments["fontSize"]?.doubleValue { state.captionFontSize = value }
    if let value = arguments["weight"]?.stringValue, let weight = CaptionFontWeight(rawValue: value) {
      state.captionFontWeight = weight
    }
    let x = arguments["positionX"]?.doubleValue ?? Double(state.captionPosition.relativeX)
    let y = arguments["positionY"]?.doubleValue ?? Double(state.captionPosition.relativeY)
    state.captionPosition = CaptionPosition(relativeX: x, relativeY: y)
    if let value = arguments["maxWordsPerLine"]?.intValue { state.captionMaxWordsPerLine = value }
    if let value = arguments["showBackground"]?.boolValue { state.captionShowBackground = value }
    if let value = arguments["backgroundOpacity"]?.doubleValue { state.captionBackgroundOpacity = value }
    return context.timelineResult()
  }
}

@MainActor
private struct AgentReplaceCaptionsTool: AgentToolHandler {
  let definition = AgentEditingToolCatalog.replaceCaptions

  func call(arguments: JSONValue, context: AgentToolContext) async throws -> JSONValue {
    let duration = CMTimeGetSeconds(context.editorState.duration)
    let segments = try (arguments["segments"]?.arrayValue ?? []).map { value -> CaptionSegment in
      let start = min(value["start"]?.doubleValue ?? 0, duration)
      let end = min(value["end"]?.doubleValue ?? duration, duration)
      let text = value["text"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      guard end > start else { throw AgentToolError.invalidArguments("caption end must be greater than start") }
      guard !text.isEmpty else { throw AgentToolError.invalidArguments("caption text must not be empty") }
      return CaptionSegment(startSeconds: start, endSeconds: end, text: text)
    }
    context.editorState.captionSegments = segments.sorted { $0.startSeconds < $1.startSeconds }
    context.editorState.captionsEnabled = !segments.isEmpty
    return context.timelineResult()
  }
}

@MainActor
private struct AgentSetCursorTool: AgentToolHandler {
  let definition = AgentEditingToolCatalog.setCursor

  func call(arguments: JSONValue, context: AgentToolContext) async throws -> JSONValue {
    let state = context.editorState
    if let value = arguments["visible"]?.boolValue { state.showCursor = value }
    if let value = arguments["style"]?.intValue, let style = CursorStyle(rawValue: value) { state.cursorStyle = style }
    if let value = arguments["size"]?.doubleValue { state.cursorSize = value }
    if let value = arguments["clickHighlights"]?.boolValue { state.showClickHighlights = value }
    if let value = arguments["clickHighlightSize"]?.doubleValue { state.clickHighlightSize = value }
    if let value = arguments["clickSound"]?.boolValue { state.clickSoundEnabled = value }
    if let value = arguments["clickSoundVolume"]?.doubleValue { state.clickSoundVolume = Float(value) }
    return context.timelineResult()
  }
}

@MainActor
private struct AgentSetCameraTool: AgentToolHandler {
  let definition = AgentEditingToolCatalog.setCamera

  func call(arguments: JSONValue, context: AgentToolContext) async throws -> JSONValue {
    let state = context.editorState
    if let value = arguments["enabled"]?.boolValue { state.webcamEnabled = value }
    let width = arguments["width"]?.doubleValue ?? Double(state.cameraLayout.relativeWidth)
    state.cameraLayout = CameraLayout(
      relativeX: min(arguments["x"]?.doubleValue ?? Double(state.cameraLayout.relativeX), 1 - width),
      relativeY: arguments["y"]?.doubleValue ?? Double(state.cameraLayout.relativeY),
      relativeWidth: width
    )
    if let value = arguments["aspect"]?.stringValue, let aspect = CameraAspect(rawValue: value) {
      state.cameraAspect = aspect
    }
    if let value = arguments["cornerRadius"]?.doubleValue { state.cameraCornerRadius = value }
    if let value = arguments["borderWidth"]?.doubleValue { state.cameraBorderWidth = value }
    if let value = arguments["shadow"]?.doubleValue { state.cameraShadow = value }
    if let value = arguments["mirrored"]?.boolValue { state.cameraMirrored = value }
    return context.timelineResult()
  }
}

@MainActor
private struct AgentSetAudioTool: AgentToolHandler {
  let definition = AgentEditingToolCatalog.setAudio

  func call(arguments: JSONValue, context: AgentToolContext) async throws -> JSONValue {
    let state = context.editorState
    if let value = arguments["systemVolume"]?.doubleValue { state.systemAudioVolume = Float(value) }
    if let value = arguments["microphoneVolume"]?.doubleValue { state.micAudioVolume = Float(value) }
    if let value = arguments["systemMuted"]?.boolValue { state.systemAudioMuted = value }
    if let value = arguments["microphoneMuted"]?.boolValue { state.micAudioMuted = value }
    state.syncAudioVolumes()
    return context.timelineResult()
  }
}

@MainActor
private struct AgentExportVideoTool: AgentToolHandler {
  let definition = AgentEditingToolCatalog.exportVideo

  func call(arguments: JSONValue, context: AgentToolContext) async throws -> JSONValue {
    guard let rawDestination = arguments["destination"]?.stringValue, rawDestination.hasPrefix("/") else {
      throw AgentToolError.invalidArguments("destination must be an absolute path")
    }
    guard let rawFormat = arguments["format"]?.stringValue, let format = exportFormat(rawFormat) else {
      throw AgentToolError.invalidArguments("unsupported export format")
    }
    let destination = URL(fileURLWithPath: rawDestination).standardizedFileURL
    guard destination.pathExtension.lowercased() == format.fileExtension else {
      throw AgentToolError.invalidArguments("destination extension must be .\(format.fileExtension)")
    }
    guard !FileManager.default.fileExists(atPath: destination.path) else {
      throw AgentToolError.invalidArguments("destination already exists")
    }
    var isDirectory: ObjCBool = false
    guard
      FileManager.default.fileExists(atPath: destination.deletingLastPathComponent().path, isDirectory: &isDirectory),
      isDirectory.boolValue
    else {
      throw AgentToolError.invalidArguments("destination directory does not exist")
    }
    let operation = AgentConfirmationOperation(
      kind: definition.name,
      arguments: ["destination": .string(destination.path), "format": .string(rawFormat)]
    )
    let confirmationID: UUID?
    if let value = arguments["confirmationId"]?.stringValue {
      guard let parsed = UUID(uuidString: value) else {
        throw AgentToolError.invalidArguments("confirmationId must be a UUID")
      }
      confirmationID = parsed
    } else {
      confirmationID = nil
    }
    try context.editorState.agentConfirmations.authorize(
      operation: operation,
      confirmationID: confirmationID,
      title: "Export video",
      detail: "Write a new \(rawFormat.uppercased()) file to \(destination.path)"
    )
    var settings = ExportSettings()
    settings.format = format
    let url = try await context.editorState.export(settings: settings, outputURL: destination)
    return ["path": .string(url.path), "format": .string(rawFormat)]
  }

  private func exportFormat(_ value: String) -> ExportFormat? {
    switch value {
    case "mp4": .mp4
    case "mov": .mov
    case "gif": .gif
    default: nil
    }
  }
}

@MainActor
private struct AgentRemoveSilencesTool: AgentToolHandler {
  let definition = AgentEditingToolCatalog.removeSilences

  func call(arguments: JSONValue, context: AgentToolContext) async throws -> JSONValue {
    let sourceName = arguments["source"]?.stringValue ?? "mic"
    let source: SilenceSource = sourceName == "system" ? .system : .microphone
    let config = SilenceDetectorConfig(
      thresholdDb: arguments["thresholdDb"]?.doubleValue ?? -40,
      minimumSilence: arguments["minGapSeconds"]?.doubleValue ?? 0.8,
      padding: arguments["padding"]?.doubleValue ?? 0.15
    )
    let preview = await context.editorState.previewSilenceRemoval(config: config, source: source)
    if let error = preview.errorDescription { throw AgentToolError.failed(error) }
    guard preview.canApply else { return context.timelineResult() }
    let keptDuration = context.editorState.cutTimeline.totalDuration
    if keptDuration > 0, preview.totalRemoved / keptDuration > 0.4 {
      let operation = AgentConfirmationOperation(
        kind: definition.name,
        arguments: [
          "source": .string(sourceName),
          "thresholdDb": .number(config.thresholdDb),
          "minGapSeconds": .number(config.minimumSilence),
          "padding": .number(config.padding),
        ]
      )
      try context.editorState.agentConfirmations.authorize(
        operation: operation,
        confirmationID: try agentConfirmationID(arguments),
        title: "Remove extensive silence",
        detail: "Remove (Int((preview.totalRemoved / keptDuration * 100).rounded()))% of the kept video"
      )
    }
    context.editorState.videoRegions = preview.slices
    return context.timelineResult()
  }
}

@MainActor
private struct AgentAddTextTool: AgentToolHandler {
  let definition = AgentEditingToolCatalog.addText

  func call(arguments: JSONValue, context: AgentToolContext) async throws -> JSONValue {
    let text = arguments["text"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !text.isEmpty else { throw AgentToolError.invalidArguments("text must not be empty") }
    let range = try agentOverlayRange(arguments, duration: CMTimeGetSeconds(context.editorState.duration))
    guard let overlay = context.editorState.addTextOverlay(atTime: range.lowerBound) else {
      throw AgentToolError.failed("The recording is too short for a text overlay")
    }
    try updateTextOverlay(overlay.id, arguments: arguments, range: range, state: context.editorState)
    return context.timelineResult()
  }
}

@MainActor
private struct AgentUpdateTextTool: AgentToolHandler {
  let definition = AgentEditingToolCatalog.updateText

  func call(arguments: JSONValue, context: AgentToolContext) async throws -> JSONValue {
    let id = try agentOverlayID(arguments)
    guard let overlay = context.editorState.textOverlays.first(where: { $0.id == id }) else {
      throw AgentToolError.invalidArguments("text overlay does not exist")
    }
    let range = try agentOverlayRange(
      arguments,
      duration: CMTimeGetSeconds(context.editorState.duration),
      fallback: overlay.startSeconds...overlay.endSeconds
    )
    try updateTextOverlay(id, arguments: arguments, range: range, state: context.editorState)
    return context.timelineResult()
  }
}

@MainActor
private struct AgentRemoveTextTool: AgentToolHandler {
  let definition = AgentEditingToolCatalog.removeText

  func call(arguments: JSONValue, context: AgentToolContext) async throws -> JSONValue {
    let id = try agentOverlayID(arguments)
    guard context.editorState.textOverlays.contains(where: { $0.id == id }) else {
      throw AgentToolError.invalidArguments("text overlay does not exist")
    }
    context.editorState.removeTextOverlay(id: id)
    return context.timelineResult()
  }
}

@MainActor
private struct AgentAddImageTool: AgentToolHandler {
  let definition = AgentEditingToolCatalog.addImage

  func call(arguments: JSONValue, context: AgentToolContext) async throws -> JSONValue {
    guard let path = arguments["path"]?.stringValue, path.hasPrefix("/") else {
      throw AgentToolError.invalidArguments("path must be absolute")
    }
    let source = URL(fileURLWithPath: path).standardizedFileURL
    try context.editorState.agentConfirmations.authorize(
      operation: .externalFile(kind: definition.name, url: source),
      confirmationID: try agentConfirmationID(arguments),
      title: "Import image",
      detail: "Copy (source.lastPathComponent) into this project"
    )
    let range = try agentOverlayRange(arguments, duration: CMTimeGetSeconds(context.editorState.duration))
    guard let overlay = context.editorState.addImageOverlay(from: source, atTime: range.lowerBound) else {
      throw AgentToolError.failed("The image could not be imported")
    }
    try updateImageOverlay(overlay.id, arguments: arguments, range: range, state: context.editorState)
    return context.timelineResult()
  }
}

@MainActor
private struct AgentUpdateImageTool: AgentToolHandler {
  let definition = AgentEditingToolCatalog.updateImage

  func call(arguments: JSONValue, context: AgentToolContext) async throws -> JSONValue {
    let id = try agentOverlayID(arguments)
    guard let overlay = context.editorState.imageOverlays.first(where: { $0.id == id }) else {
      throw AgentToolError.invalidArguments("image overlay does not exist")
    }
    let range = try agentOverlayRange(
      arguments,
      duration: CMTimeGetSeconds(context.editorState.duration),
      fallback: overlay.startSeconds...overlay.endSeconds
    )
    try updateImageOverlay(id, arguments: arguments, range: range, state: context.editorState)
    return context.timelineResult()
  }
}

@MainActor
private struct AgentRemoveImageTool: AgentToolHandler {
  let definition = AgentEditingToolCatalog.removeImage

  func call(arguments: JSONValue, context: AgentToolContext) async throws -> JSONValue {
    let id = try agentOverlayID(arguments)
    guard context.editorState.imageOverlays.contains(where: { $0.id == id }) else {
      throw AgentToolError.invalidArguments("image overlay does not exist")
    }
    context.editorState.removeImageOverlay(id: id)
    return context.timelineResult()
  }
}

private func agentOverlayID(_ arguments: JSONValue) throws -> UUID {
  guard let value = arguments["id"]?.stringValue, let id = UUID(uuidString: value) else {
    throw AgentToolError.invalidArguments("id must be a UUID")
  }
  return id
}

private func agentConfirmationID(_ arguments: JSONValue) throws -> UUID? {
  guard let value = arguments["confirmationId"]?.stringValue else { return nil }
  guard let id = UUID(uuidString: value) else {
    throw AgentToolError.invalidArguments("confirmationId must be a UUID")
  }
  return id
}

private func agentOverlayRange(
  _ arguments: JSONValue,
  duration: Double,
  fallback: ClosedRange<Double>? = nil
) throws -> ClosedRange<Double> {
  let start = arguments["start"]?.doubleValue ?? fallback?.lowerBound ?? 0
  let end = arguments["end"]?.doubleValue ?? fallback?.upperBound ?? duration
  guard end - start >= TextOverlayData.minimumLength else {
    throw AgentToolError.invalidArguments("overlay end must be at least (TextOverlayData.minimumLength) seconds after start")
  }
  guard start >= 0, end <= duration else {
    throw AgentToolError.invalidArguments("overlay range must fit inside the recording")
  }
  return start...end
}

@MainActor
private func updateTextOverlay(
  _ id: UUID,
  arguments: JSONValue,
  range: ClosedRange<Double>,
  state: EditorState
) throws {
  guard let index = state.textOverlays.firstIndex(where: { $0.id == id }) else {
    throw AgentToolError.invalidArguments("text overlay does not exist")
  }
  var overlay = state.textOverlays[index]
  if let value = arguments["text"]?.stringValue {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { throw AgentToolError.invalidArguments("text must not be empty") }
    overlay.text = trimmed
  }
  if let value = arguments["fontSize"]?.doubleValue { overlay.fontSize = value }
  if let value = arguments["weight"]?.stringValue, let weight = CaptionFontWeight(rawValue: value) { overlay.fontWeight = weight }
  if let value = arguments["showBackground"]?.boolValue { overlay.showBackground = value }
  if let value = arguments["backgroundOpacity"]?.doubleValue { overlay.backgroundOpacity = value }
  applyOverlayValues(arguments, to: &overlay)
  overlay.startSeconds = range.lowerBound
  overlay.endSeconds = range.upperBound
  state.textOverlays[index] = overlay
  state.textOverlays.sort { $0.startSeconds < $1.startSeconds }
}

@MainActor
private func updateImageOverlay(
  _ id: UUID,
  arguments: JSONValue,
  range: ClosedRange<Double>,
  state: EditorState
) throws {
  guard let index = state.imageOverlays.firstIndex(where: { $0.id == id }) else {
    throw AgentToolError.invalidArguments("image overlay does not exist")
  }
  var overlay = state.imageOverlays[index]
  if let value = arguments["width"]?.doubleValue { overlay.width = value }
  if let value = arguments["cornerRadius"]?.doubleValue { overlay.cornerRadius = value }
  if let value = arguments["opacity"]?.doubleValue { overlay.opacity = value }
  if let value = arguments["shadow"]?.doubleValue { overlay.shadow = value }
  applyOverlayValues(arguments, to: &overlay)
  overlay.startSeconds = range.lowerBound
  overlay.endSeconds = range.upperBound
  state.imageOverlays[index] = overlay
  state.imageOverlays.sort { $0.startSeconds < $1.startSeconds }
}

private func applyOverlayValues(_ arguments: JSONValue, to overlay: inout TextOverlayData) {
  if let value = arguments["position"]?.stringValue, let position = TextOverlayPosition(rawValue: value) { overlay.position = position }
  if let value = arguments["offsetX"]?.doubleValue { overlay.offsetX = value }
  if let value = arguments["offsetY"]?.doubleValue { overlay.offsetY = value }
  if let value = arguments["entryTransition"]?.stringValue, let transition = RegionTransitionType(rawValue: value) {
    overlay.entryTransition = transition
  }
  if let value = arguments["entryDuration"]?.doubleValue { overlay.entryTransitionDuration = value }
  if let value = arguments["exitTransition"]?.stringValue, let transition = RegionTransitionType(rawValue: value) {
    overlay.exitTransition = transition
  }
  if let value = arguments["exitDuration"]?.doubleValue { overlay.exitTransitionDuration = value }
}

private func applyOverlayValues(_ arguments: JSONValue, to overlay: inout ImageOverlayData) {
  if let value = arguments["position"]?.stringValue, let position = TextOverlayPosition(rawValue: value) { overlay.position = position }
  if let value = arguments["offsetX"]?.doubleValue { overlay.offsetX = value }
  if let value = arguments["offsetY"]?.doubleValue { overlay.offsetY = value }
  if let value = arguments["entryTransition"]?.stringValue, let transition = RegionTransitionType(rawValue: value) {
    overlay.entryTransition = transition
  }
  if let value = arguments["entryDuration"]?.doubleValue { overlay.entryTransitionDuration = value }
  if let value = arguments["exitTransition"]?.stringValue, let transition = RegionTransitionType(rawValue: value) {
    overlay.exitTransition = transition
  }
  if let value = arguments["exitDuration"]?.doubleValue { overlay.exitTransitionDuration = value }
}

@MainActor
private struct AgentBatchBoundaryTool: AgentToolHandler {
  let definition: AgentToolDefinition

  func call(arguments: JSONValue, context: AgentToolContext) async throws -> JSONValue {
    context.timelineResult()
  }
}
