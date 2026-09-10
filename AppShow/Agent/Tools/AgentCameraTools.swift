import CoreMedia
import Foundation

@MainActor
enum AgentCameraToolCatalog {
  static var handlers: [any AgentToolHandler] {
    AgentCameraRegionTool.Operation.allCases.map { AgentCameraRegionTool(operation: $0) }
  }
}

@MainActor
private struct AgentCameraRegionTool: AgentToolHandler {
  enum Operation: String, CaseIterable { case add, update, remove }
  let operation: Operation

  var definition: AgentToolDefinition {
    var properties: [String: JSONValue] = [
      "id": AgentToolSchema.string("Camera region UUID"),
      "label": AgentToolSchema.string("Short undo-history label"),
    ]
    if operation != .remove {
      properties.merge([
        "start": AgentToolSchema.number("Start in source seconds", minimum: 0),
        "end": AgentToolSchema.number("End in source seconds", minimum: 0),
        "type": AgentToolSchema.string(
          "Fullscreen focuses the webcam; leftHalf/rightHalf and leftThird/rightThird fit the app beside it; hidden hides it; custom uses its current layout",
          enum: CameraRegionType.allCases.map(\.rawValue)
        ),
        "entryTransition": AgentToolSchema.string("Entry animation", enum: RegionTransitionType.allCases.map(\.rawValue)),
        "exitTransition": AgentToolSchema.string("Exit animation", enum: RegionTransitionType.allCases.map(\.rawValue)),
        "entryDuration": AgentToolSchema.number("Entry animation seconds, limited to half the region", minimum: 0, maximum: 5),
        "exitDuration": AgentToolSchema.number("Exit animation seconds, limited to half the region", minimum: 0, maximum: 5),
      ]) { _, value in value }
    }
    if operation == .add { properties["id"] = nil }
    return AgentToolDefinition(
      name: "\(operation.rawValue)_camera_region",
      description:
        "\(operation.rawValue.capitalized) a timed webcam presentation region. Outside regions the webcam returns to its normal bubble. Times use source seconds.",
      inputSchema: AgentToolSchema.object(properties, required: operation == .add ? ["start", "end"] : ["id"]),
      mutating: true
    )
  }

  func call(arguments: JSONValue, context: AgentToolContext) async throws -> JSONValue {
    let state = context.editorState
    guard state.hasWebcam else { throw AgentToolError.invalidArguments("This recording has no webcam track") }
    let existing: CameraRegionData?
    if operation == .add {
      existing = nil
    } else {
      guard let value = arguments["id"]?.stringValue, let id = UUID(uuidString: value),
        let region = state.cameraRegions.first(where: { $0.id == id })
      else { throw AgentToolError.invalidArguments("Camera region not found") }
      existing = region
    }
    if operation == .remove, let existing {
      state.removeCameraRegion(regionId: existing.id)
      return context.timelineResult()
    }
    var region = existing ?? CameraRegionData(startSeconds: 0, endSeconds: 0)
    region.startSeconds = arguments["start"]?.doubleValue ?? region.startSeconds
    region.endSeconds = arguments["end"]?.doubleValue ?? region.endSeconds
    if let type = arguments["type"]?.stringValue.flatMap(CameraRegionType.init(rawValue:)) { region.type = type }
    guard region.endSeconds <= state.duration.seconds, region.endSeconds - region.startSeconds >= 0.05 else {
      throw AgentToolError.invalidArguments("Camera regions must last at least 0.05 seconds and fit within the recording")
    }
    guard
      !state.cameraRegions.contains(where: {
        $0.id != region.id && $0.startSeconds < region.endSeconds && $0.endSeconds > region.startSeconds
      })
    else {
      throw AgentToolError.invalidArguments("Camera regions cannot overlap")
    }
    let defaultTransition: RegionTransitionType = region.type.isExpanded ? .scale : .fade
    region.entryTransition =
      arguments["entryTransition"]?.stringValue.flatMap(RegionTransitionType.init(rawValue:)) ?? region.entryTransition ?? defaultTransition
    region.exitTransition =
      arguments["exitTransition"]?.stringValue.flatMap(RegionTransitionType.init(rawValue:)) ?? region.exitTransition ?? defaultTransition
    let half = (region.endSeconds - region.startSeconds) / 2
    region.entryTransitionDuration = min(half, arguments["entryDuration"]?.doubleValue ?? region.entryTransitionDuration ?? 0.4)
    region.exitTransitionDuration = min(half, arguments["exitDuration"]?.doubleValue ?? region.exitTransitionDuration ?? 0.4)
    if region.type == .custom && region.customLayout == nil {
      region.customLayout = state.cameraLayout
      region.customCameraAspect = state.cameraAspect
      region.customCornerRadius = state.cameraCornerRadius
      region.customMirrored = state.cameraMirrored
    }
    if let index = state.cameraRegions.firstIndex(where: { $0.id == region.id }) {
      state.cameraRegions[index] = region
    } else {
      state.cameraRegions.append(region)
    }
    state.cameraRegions.sort { $0.startSeconds < $1.startSeconds }
    return context.timelineResult()
  }
}
