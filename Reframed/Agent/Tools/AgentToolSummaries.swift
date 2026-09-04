import Foundation

struct AgentToolMediaInfo: Sendable, Equatable {
  var hasWebcam: Bool
  var hasSystemAudio: Bool
  var hasMicAudio: Bool
  var hasCursorMetadata: Bool
}

enum AgentToolSummaries {
  static let transcriptHint =
    "No captions exist yet. Generate them in the editor's Captions tab, or with the generate_captions tool once the mutating catalog is enabled."

  static func seconds(_ value: Double) -> JSONValue {
    .number((value * 1000).rounded() / 1000)
  }

  static func level(_ value: Float) -> JSONValue {
    .number((Double(value) * 10000).rounded() / 10000)
  }

  static func range(_ start: Double, _ end: Double) -> JSONValue {
    ["start": seconds(start), "end": seconds(end)]
  }

  static func timeline(
    snapshot: EditorStateData,
    duration: Double,
    media: AgentToolMediaInfo,
    historyIndex: Int,
    historyCount: Int
  ) -> JSONValue {
    let slices = snapshot.videoRegions ?? [VideoRegionData(startSeconds: 0, endSeconds: duration)]
    let cuts = CutTimeline(slices: slices, duration: duration)
    let zoom = snapshot.zoomSettings
    let cursor = snapshot.cursorSettings
    let audio = snapshot.audioSettings
    return [
      "duration": seconds(duration),
      "trim": range(snapshot.trimStartSeconds, snapshot.trimEndSeconds),
      "cuts": [
        "hasCuts": .bool(cuts.hasCuts),
        "keptDuration": seconds(cuts.totalDuration),
        "slices": .array(cuts.slices.map(slice)),
        "gaps": .array(cuts.gaps.map { range($0.lowerBound, $0.upperBound) }),
      ],
      "zoom": [
        "enabled": .bool(zoom?.zoomEnabled ?? false),
        "autoZoom": .bool(zoom?.autoZoomEnabled ?? false),
        "level": .number(zoom?.zoomLevel ?? 2.0),
        "keyframes": .array((zoom?.keyframes ?? []).map(keyframe)),
      ],
      "spotlight": [
        "enabled": .bool(cursor?.spotlightEnabled ?? false),
        "regions": .array((snapshot.spotlightRegions ?? []).map(spotlightRegion)),
      ],
      "camera": [
        "present": .bool(media.hasWebcam),
        "enabled": .bool(snapshot.webcamEnabled ?? true),
        "regions": .array((snapshot.cameraRegions ?? []).map(cameraRegion)),
      ],
      "captions": [
        "enabled": .bool(snapshot.captionSettings?.enabled ?? false),
        "count": JSONValue(snapshot.captionSegments?.count ?? 0),
        "segments": .array((snapshot.captionSegments ?? []).map { caption($0, withWords: false) }),
      ],
      "overlays": [
        "text": .array((snapshot.textOverlays ?? []).map(textOverlay)),
        "images": .array((snapshot.imageOverlays ?? []).map(imageOverlay)),
      ],
      "audio": [
        "system": audioTrack(
          present: media.hasSystemAudio,
          muted: audio?.systemAudioMuted ?? false,
          volume: audio?.systemAudioVolume ?? 1,
          regions: snapshot.systemAudioRegions ?? []
        ),
        "mic": audioTrack(
          present: media.hasMicAudio,
          muted: audio?.micAudioMuted ?? false,
          volume: audio?.micAudioVolume ?? 1,
          regions: snapshot.micAudioRegions ?? []
        ),
        "external": .array((snapshot.externalAudioTracks ?? []).map(externalTrack)),
      ],
      "background": background(snapshot.backgroundStyle),
      "canvas": [
        "aspect": .string((snapshot.canvasAspect ?? .original).rawValue),
        "padding": .number(Double(snapshot.padding)),
        "cornerRadius": .number(Double(snapshot.videoCornerRadius)),
        "shadow": .number(Double(snapshot.videoShadow ?? 0)),
      ],
      "history": ["index": JSONValue(historyIndex), "count": JSONValue(historyCount)],
    ]
  }

  static func transcript(
    segments: [CaptionSegment],
    enabled: Bool,
    source: CaptionAudioSource,
    language: CaptionLanguage,
    withWords: Bool,
    from: Double?,
    to: Double?
  ) -> JSONValue {
    let lower = from ?? -.infinity
    let upper = to ?? .infinity
    let kept =
      segments
      .filter { $0.endSeconds >= lower && $0.startSeconds <= upper }
      .sorted { $0.startSeconds < $1.startSeconds }
    var object: [String: JSONValue] = [
      "enabled": .bool(enabled),
      "source": .string(source.rawValue),
      "language": .string(language.rawValue),
      "count": JSONValue(kept.count),
      "segments": .array(kept.map { caption($0, withWords: withWords) }),
    ]
    if segments.isEmpty {
      object["hint"] = .string(transcriptHint)
    }
    return .object(object)
  }

  @MainActor
  static func history(entries: [HistoryEntry], currentIndex: Int) -> JSONValue {
    let formatter = ISO8601DateFormatter()
    var items: [JSONValue] = []
    for (index, entry) in entries.enumerated() {
      let changes = index == 0 ? ["Initial state"] : History.describeChanges(from: entries[index - 1].snapshot, to: entry.snapshot)
      items.append([
        "index": JSONValue(index),
        "timestamp": .string(formatter.string(from: entry.timestamp)),
        "label": .string(entry.label ?? changes.first ?? "Editor settings updated"),
        "changes": .array(changes.map { .string($0) }),
        "isCurrent": .bool(index == currentIndex),
      ])
    }
    return [
      "index": JSONValue(currentIndex),
      "count": JSONValue(entries.count),
      "canUndo": .bool(currentIndex > 0),
      "canRedo": .bool(currentIndex < entries.count - 1),
      "entries": .array(items),
    ]
  }

  private static func slice(_ region: VideoRegionData) -> JSONValue {
    var object: [String: JSONValue] = [
      "id": .string(region.id.uuidString),
      "start": seconds(region.startSeconds),
      "end": seconds(region.endSeconds),
    ]
    if let entry = region.entryTransition { object["entryTransition"] = .string(entry.rawValue) }
    if let exit = region.exitTransition { object["exitTransition"] = .string(exit.rawValue) }
    return .object(object)
  }

  private static func keyframe(_ keyframe: ZoomKeyframe) -> JSONValue {
    [
      "t": seconds(keyframe.t),
      "level": .number(keyframe.zoomLevel),
      "x": .number(keyframe.centerX),
      "y": .number(keyframe.centerY),
      "auto": .bool(keyframe.isAuto),
    ]
  }

  private static func spotlightRegion(_ region: SpotlightRegionData) -> JSONValue {
    var object: [String: JSONValue] = [
      "id": .string(region.id.uuidString),
      "start": seconds(region.startSeconds),
      "end": seconds(region.endSeconds),
    ]
    if let radius = region.customRadius { object["radius"] = .number(Double(radius)) }
    if let dim = region.customDimOpacity { object["dimOpacity"] = .number(Double(dim)) }
    if let softness = region.customEdgeSoftness { object["edgeSoftness"] = .number(Double(softness)) }
    if let fade = region.fadeDuration { object["fadeDuration"] = seconds(fade) }
    return .object(object)
  }

  private static func cameraRegion(_ region: CameraRegionData) -> JSONValue {
    var object: [String: JSONValue] = [
      "id": .string(region.id.uuidString),
      "start": seconds(region.startSeconds),
      "end": seconds(region.endSeconds),
      "type": .string(region.type.rawValue),
    ]
    if let entry = region.entryTransition { object["entryTransition"] = .string(entry.rawValue) }
    if let exit = region.exitTransition { object["exitTransition"] = .string(exit.rawValue) }
    return .object(object)
  }

  private static func caption(_ segment: CaptionSegment, withWords: Bool) -> JSONValue {
    var object: [String: JSONValue] = [
      "id": .string(segment.id.uuidString),
      "start": seconds(segment.startSeconds),
      "end": seconds(segment.endSeconds),
      "text": .string(segment.text),
    ]
    if withWords, let words = segment.words {
      object["words"] = .array(
        words.map { ["word": .string($0.word), "start": seconds($0.startSeconds), "end": seconds($0.endSeconds)] }
      )
    }
    return .object(object)
  }

  private static func audioTrack(present: Bool, muted: Bool, volume: Float, regions: [AudioRegionData]) -> JSONValue {
    [
      "present": .bool(present),
      "muted": .bool(muted),
      "volume": level(volume),
      "regions": .array(regions.map { range($0.startSeconds, $0.endSeconds) }),
    ]
  }

  private static func externalTrack(_ track: ExternalAudioTrackData) -> JSONValue {
    [
      "id": .string(track.id.uuidString),
      "name": .string(track.displayName),
      "start": seconds(track.timelineStartSeconds),
      "end": seconds(track.timelineEndSeconds),
      "fileIn": seconds(track.fileInSeconds),
      "fileOut": seconds(track.fileOutSeconds),
      "volume": level(track.volume),
      "muted": .bool(track.muted),
      "fadeIn": seconds(track.fadeInSeconds),
      "fadeOut": seconds(track.fadeOutSeconds),
    ]
  }

  private static func textOverlay(_ overlay: TextOverlayData) -> JSONValue {
    [
      "id": .string(overlay.id.uuidString),
      "start": seconds(overlay.startSeconds),
      "end": seconds(overlay.endSeconds),
      "text": .string(overlay.text),
      "position": .string(overlay.position.rawValue),
      "offsetX": .number(Double(overlay.offsetX)),
      "offsetY": .number(Double(overlay.offsetY)),
    ]
  }

  private static func imageOverlay(_ overlay: ImageOverlayData) -> JSONValue {
    [
      "id": .string(overlay.id.uuidString),
      "start": seconds(overlay.startSeconds),
      "end": seconds(overlay.endSeconds),
      "name": .string(overlay.displayName),
      "position": .string(overlay.position.rawValue),
      "width": .number(Double(overlay.width)),
      "opacity": .number(Double(overlay.opacity)),
    ]
  }

  private static func background(_ style: BackgroundStyle) -> JSONValue {
    switch style {
    case .none: ["type": "none"]
    case .solidColor(let color): ["type": "solid", "color": .string(color.hexString)]
    case .gradient(let id): ["type": "gradient", "gradientId": JSONValue(id)]
    case .image(let filename): ["type": "image", "filename": .string(filename)]
    }
  }
}
