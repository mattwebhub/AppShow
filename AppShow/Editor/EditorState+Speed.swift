import Foundation

extension EditorState {
  var hasTimeEdits: Bool { hasVideoRegionCuts || !speedRegions.isEmpty }

  var speedTimeline: SpeedTimeline {
    SpeedTimeline(duration: duration.seconds, regions: speedRegions, slices: trimmedSpeedSlices)
  }

  private var trimmedSpeedSlices: [VideoRegionData] {
    cutTimeline.slices.compactMap { slice -> VideoRegionData? in
      let start = max(slice.startSeconds, trimStart.seconds)
      let end = min(slice.endSeconds, trimEnd.seconds)
      return end > start ? VideoRegionData(startSeconds: start, endSeconds: end) : nil
    }
  }

  var subtitleSegmentsForExport: [CaptionSegment] {
    guard captionAudioSource == .microphone else { return speedTimeline.remapCaptions(captionSegments) }
    let normal = SpeedTimeline(duration: duration.seconds, regions: [], slices: trimmedSpeedSlices)
    return normal.remapCaptions(captionSegments).compactMap { caption in
      var clipped = caption
      clipped.endSeconds = min(clipped.endSeconds, speedTimeline.totalDuration)
      return clipped.endSeconds > clipped.startSeconds ? clipped : nil
    }
  }

  @discardableResult
  func addSpeedRegion(start: Double, end: Double, rate: Double) throws -> SpeedRegionData {
    let region = SpeedRegionData(startSeconds: start, endSeconds: end, rate: rate)
    try commitSpeedRegions(speedRegions + [region], label: "Speed: \(region.label)")
    return region
  }

  func updateSpeedRegion(_ region: SpeedRegionData) throws {
    guard let index = speedRegions.firstIndex(where: { $0.id == region.id }) else {
      throw AgentToolError.invalidArguments("Speed region does not exist.")
    }
    var regions = speedRegions
    regions[index] = region
    try commitSpeedRegions(regions, label: "Speed adjusted")
  }

  func removeSpeedRegion(id: UUID) {
    try? commitSpeedRegions(speedRegions.filter { $0.id != id }, label: "Speed removed")
  }

  private func commitSpeedRegions(_ regions: [SpeedRegionData], label: String) throws {
    guard !isExporting, regions.allSatisfy({ $0.isValid(duration: duration.seconds) }) else {
      throw AgentToolError.invalidArguments("Choose a supported speed and a time range inside the recording.")
    }
    let sorted = regions.sorted { $0.startSeconds < $1.startSeconds }
    guard zip(sorted, sorted.dropFirst()).allSatisfy({ $0.endSeconds <= $1.startSeconds }) else {
      throw AgentToolError.invalidArguments("Speed regions cannot overlap.")
    }
    guard sorted != speedRegions else { return }
    pause()
    pendingUndoTask?.cancel()
    if !agentMutationBatchActive { history.pushSnapshot(createSnapshot()) }
    speedRegions = sorted
    syncVideoRegionsToPlayer()
    if !agentMutationBatchActive { history.pushSnapshot(createSnapshot(), label: label) }
    scheduleSave()
  }
}
