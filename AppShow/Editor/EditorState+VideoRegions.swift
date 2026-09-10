import CoreMedia
import Foundation

extension EditorState {
  func addVideoRegion(atTime time: Double) {
    if videoRegions.contains(where: { time >= $0.startSeconds && time <= $0.endSeconds }) {
      return
    }

    let dur = CMTimeGetSeconds(duration)
    let desiredHalf = min(5.0, dur / 2)
    var gapStart: Double = 0
    var gapEnd: Double = dur
    var insertIdx = videoRegions.count

    for i in 0..<videoRegions.count {
      if time < videoRegions[i].startSeconds {
        gapEnd = videoRegions[i].startSeconds
        insertIdx = i
        break
      }
      gapStart = videoRegions[i].endSeconds
    }
    if insertIdx == videoRegions.count {
      gapEnd = dur
    }

    guard gapEnd - gapStart >= 0.05 else { return }

    let regionStart = max(gapStart, time - desiredHalf)
    let regionEnd = min(gapEnd, time + desiredHalf)
    let finalStart = max(gapStart, min(regionStart, regionEnd - 0.05))
    let finalEnd = min(gapEnd, max(regionEnd, finalStart + 0.05))

    videoRegions.insert(
      VideoRegionData(startSeconds: finalStart, endSeconds: finalEnd),
      at: insertIdx
    )
    videoRegions.sort { $0.startSeconds < $1.startSeconds }
  }

  var canDeleteSelectedVideoRegion: Bool {
    !isExporting && videoRegions.count > 1 && videoRegions.contains { $0.id == selectedVideoRegionID }
  }

  func selectVideoRegion(_ id: UUID) {
    guard let region = videoRegions.first(where: { $0.id == id }) else { return }
    selectedVideoRegionID = id
    pause()
    seek(to: CMTime(seconds: region.startSeconds, preferredTimescale: 600))
  }

  @discardableResult
  func deleteSelectedVideoRegion() -> Bool {
    guard canDeleteSelectedVideoRegion, let id = selectedVideoRegionID else { return false }
    removeVideoRegion(regionId: id)
    return true
  }

  func splitVideoRegion(atTime time: Double) {
    let split = cutTimeline.split(at: time)
    guard split != cutTimeline else { return }
    commitVideoRegions(split.slices, label: "Cut added")
    selectedVideoRegionID = split.slices.first { $0.startSeconds == time }?.id
  }

  func clearVideoCuts() {
    commitVideoRegions([VideoRegionData(startSeconds: 0, endSeconds: CMTimeGetSeconds(duration))], label: "Cuts cleared")
  }

  func removeVideoRegion(regionId: UUID) {
    guard !isExporting, videoRegions.count > 1,
      let index = videoRegions.firstIndex(where: { $0.id == regionId })
    else { return }
    var kept = videoRegions
    kept.remove(at: index)
    let next = kept[min(index, kept.count - 1)]
    pause()
    commitVideoRegions(kept, label: "Cut removed")
    selectedVideoRegionID = next.id
    seek(to: CMTime(seconds: next.startSeconds, preferredTimescale: 600))
  }

  func updateVideoRegionStart(regionId: UUID, newStart: Double) {
    commitVideoRegions(cutTimeline.adjustingEdge(of: regionId, leading: true, to: newStart).slices, label: "Cut adjusted")
  }

  func updateVideoRegionEnd(regionId: UUID, newEnd: Double) {
    commitVideoRegions(cutTimeline.adjustingEdge(of: regionId, leading: false, to: newEnd).slices, label: "Cut adjusted")
  }

  func moveVideoRegion(regionId: UUID, newStart: Double) {
    commitVideoRegions(cutTimeline.movingSlice(regionId, to: newStart).slices, label: "Cut moved")
  }

  func commitVideoRegions(_ slices: [VideoRegionData], label: String) {
    guard !isExporting, !slices.isEmpty, slices != videoRegions else { return }
    pendingUndoTask?.cancel()
    if !agentMutationBatchActive { history.pushSnapshot(createSnapshot()) }
    videoRegions = slices
    syncVideoRegionsToPlayer()
    scheduleSave()
    if !agentMutationBatchActive { history.pushSnapshot(createSnapshot(), label: label) }
  }

  func updateVideoRegionTransition(
    regionId: UUID,
    entryTransition: RegionTransitionType? = nil,
    entryDuration: Double? = nil,
    exitTransition: RegionTransitionType? = nil,
    exitDuration: Double? = nil
  ) {
    guard let idx = videoRegions.firstIndex(where: { $0.id == regionId }) else { return }
    if let entryTransition { videoRegions[idx].entryTransition = entryTransition }
    if let entryDuration { videoRegions[idx].entryTransitionDuration = entryDuration }
    if let exitTransition { videoRegions[idx].exitTransition = exitTransition }
    if let exitDuration { videoRegions[idx].exitTransitionDuration = exitDuration }
  }
}
