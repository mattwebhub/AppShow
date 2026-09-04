import CoreMedia
import Foundation

@MainActor
struct AgentToolProjectSummaryHandler: AgentToolHandler {
  var definition: AgentToolDefinition { AgentToolCatalog.getProjectSummary }

  func call(arguments: JSONValue, context: AgentToolContext) async throws -> JSONValue {
    let state = context.editorState
    var webcam: [String: JSONValue] = ["present": .bool(state.hasWebcam), "enabled": .bool(state.webcamEnabled)]
    if let size = state.result.webcamSize {
      webcam["size"] = ["width": .number(Double(size.width)), "height": .number(Double(size.height))]
    }
    var object: [String: JSONValue] = [
      "name": .string(state.projectName),
      "duration": AgentToolSummaries.seconds(CMTimeGetSeconds(state.duration)),
      "fps": JSONValue(state.result.fps),
      "screenSize": [
        "width": .number(Double(state.result.screenSize.width)),
        "height": .number(Double(state.result.screenSize.height)),
      ],
      "webcam": .object(webcam),
      "hasSystemAudio": .bool(state.hasSystemAudio),
      "hasMicAudio": .bool(state.hasMicAudio),
      "hasCursorMetadata": .bool(state.cursorMetadataProvider != nil),
      "isHDR": .bool(state.result.isHDR),
      "history": ["index": JSONValue(state.history.currentIndex), "count": JSONValue(state.history.entries.count)],
    ]
    if let project = state.project {
      object["bundlePath"] = .string(project.bundleURL.path)
      object["createdAt"] = .string(ISO8601DateFormatter().string(from: project.metadata.createdAt))
      if let mode = project.metadata.captureMode {
        object["captureMode"] = .string(mode.rawValue)
      }
    }
    if let workspace = context.workspaceDirectory {
      object["workspacePath"] = .string(workspace.path)
    }
    return .object(object)
  }
}

@MainActor
struct AgentToolTimelineHandler: AgentToolHandler {
  var definition: AgentToolDefinition { AgentToolCatalog.getTimeline }

  func call(arguments: JSONValue, context: AgentToolContext) async throws -> JSONValue {
    let state = context.editorState
    let snapshot = state.createSnapshot()
    var timeline = AgentToolSummaries.timeline(
      snapshot: snapshot,
      duration: CMTimeGetSeconds(state.duration),
      media: state.agentMediaInfo,
      historyIndex: state.history.currentIndex,
      historyCount: state.history.entries.count
    )
    if arguments["detail"] == "full", var object = timeline.objectValue {
      object["snapshot"] = try JSONValue(encoding: snapshot)
      timeline = .object(object)
    }
    return timeline
  }
}

@MainActor
struct AgentToolTranscriptHandler: AgentToolHandler {
  var definition: AgentToolDefinition { AgentToolCatalog.getTranscript }

  func call(arguments: JSONValue, context: AgentToolContext) async throws -> JSONValue {
    let state = context.editorState
    return AgentToolSummaries.transcript(
      segments: state.captionSegments,
      enabled: state.captionsEnabled,
      source: state.captionAudioSource,
      language: state.captionLanguage,
      withWords: arguments["withWords"]?.boolValue ?? false,
      from: arguments["from"]?.doubleValue,
      to: arguments["to"]?.doubleValue
    )
  }
}

@MainActor
struct AgentToolCursorActivityHandler: AgentToolHandler {
  var definition: AgentToolDefinition { AgentToolCatalog.getCursorActivity }

  func call(arguments: JSONValue, context: AgentToolContext) async throws -> JSONValue {
    AgentToolCursorActivity.summary(
      metadata: context.editorState.cursorMetadataProvider?.metadata,
      dwellSeconds: arguments["dwellSeconds"]?.doubleValue ?? AgentToolCursorActivity.defaultDwellSeconds,
      from: arguments["from"]?.doubleValue,
      to: arguments["to"]?.doubleValue
    )
  }
}

@MainActor
struct AgentToolHistoryHandler: AgentToolHandler {
  var definition: AgentToolDefinition { AgentToolCatalog.getHistory }

  func call(arguments: JSONValue, context: AgentToolContext) async throws -> JSONValue {
    let history = context.editorState.history
    return AgentToolSummaries.history(entries: history.entries, currentIndex: history.currentIndex)
  }
}

@MainActor
struct AgentToolSilencesHandler: AgentToolHandler {
  var definition: AgentToolDefinition { AgentToolCatalog.getSilences }

  func call(arguments: JSONValue, context: AgentToolContext) async throws -> JSONValue {
    let sourceName = arguments["source"]?.stringValue ?? "mic"
    let source: SilenceSource = sourceName == "system" ? .system : .microphone
    let config = SilenceDetectorConfig(
      thresholdDb: arguments["thresholdDb"]?.doubleValue ?? -40,
      minimumSilence: arguments["minGapSeconds"]?.doubleValue ?? 0.8
    )
    let preview = await context.editorState.previewSilenceRemoval(config: config, source: source)
    if let error = preview.errorDescription { throw AgentToolError.failed(error) }
    return [
      "source": .string(sourceName),
      "count": JSONValue(preview.count),
      "totalSeconds": AgentToolSummaries.seconds(preview.silences.reduce(0) { $0 + $1.upperBound - $1.lowerBound }),
      "silences": .array(preview.silences.map { AgentToolSummaries.range($0.lowerBound, $0.upperBound) }),
    ]
  }
}

@MainActor
struct AgentToolUnavailableHandler: AgentToolHandler {
  let definition: AgentToolDefinition

  func call(arguments: JSONValue, context: AgentToolContext) async throws -> JSONValue {
    let reason: String
    switch definition.availability {
    case .available: reason = "no handler is registered"
    case .pendingMerge(let branch): reason = "pending merge of \(branch)"
    }
    throw AgentToolError.unavailable(name: definition.name, reason: reason)
  }
}

extension EditorState {
  var agentMediaInfo: AgentToolMediaInfo {
    AgentToolMediaInfo(
      hasWebcam: hasWebcam,
      hasSystemAudio: hasSystemAudio,
      hasMicAudio: hasMicAudio,
      hasCursorMetadata: cursorMetadataProvider != nil
    )
  }
}
