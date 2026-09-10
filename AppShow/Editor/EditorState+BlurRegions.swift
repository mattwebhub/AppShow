import CoreMedia
import Foundation

extension EditorState {
  @discardableResult
  func addTimedBlur(rect: CGRect, start: Double, end: Double) throws -> BlurRegionData {
    guard !isExporting, start.isFinite, end.isFinite, start >= 0, end <= duration.seconds,
      end - start >= BlurRegionData.minimumLength,
      [rect.minX, rect.minY, rect.width, rect.height].allSatisfy(\.isFinite),
      rect.minX >= 0, rect.minY >= 0, rect.maxX <= 1.000001, rect.maxY <= 1.000001,
      rect.width >= 0.01, rect.height >= 0.01
    else { throw AgentToolError.invalidArguments("Choose an area inside the source frame and a time range inside the recording.") }
    let region = BlurRegionData(startSeconds: start, endSeconds: end, x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)
      .normalized()
    blurRegions.append(region)
    sortBlurRegions()
    scheduleUndoSnapshot()
    return region
  }

  func activeBlurRegions(at time: Double) -> [BlurRegionData] {
    blurRegions.filter { time >= $0.startSeconds && time <= $0.endSeconds }
  }

  @discardableResult
  func addBlurRegion(atTime time: Double, rect: CGRect = CGRect(x: 0.3, y: 0.4, width: 0.4, height: 0.2)) -> BlurRegionData {
    let duration = max(BlurRegionData.minimumLength, CMTimeGetSeconds(self.duration))
    let length = min(BlurRegionData.defaultLength, duration)
    let start = max(0, min(duration - length, time))
    let region = BlurRegionData(
      startSeconds: start,
      endSeconds: min(duration, start + length),
      x: rect.origin.x,
      y: rect.origin.y,
      width: rect.width,
      height: rect.height
    ).normalized()
    blurRegions.append(region)
    sortBlurRegions()
    scheduleUndoSnapshot()
    return region
  }

  func updateBlurRegion(id: UUID, update: (inout BlurRegionData) -> Void) {
    guard let index = blurRegions.firstIndex(where: { $0.id == id }) else { return }
    var region = blurRegions[index]
    update(&region)
    region.id = blurRegions[index].id
    region.startSeconds = blurRegions[index].startSeconds
    region.endSeconds = blurRegions[index].endSeconds
    blurRegions[index] = region.normalized()
    scheduleUndoSnapshot()
  }

  func updateBlurRegionStart(id: UUID, newStart: Double) {
    guard let index = blurRegions.firstIndex(where: { $0.id == id }) else { return }
    let maxStart = blurRegions[index].endSeconds - BlurRegionData.minimumLength
    blurRegions[index].startSeconds = max(0, min(maxStart, newStart))
    sortBlurRegions()
    scheduleUndoSnapshot()
  }

  func updateBlurRegionEnd(id: UUID, newEnd: Double) {
    guard let index = blurRegions.firstIndex(where: { $0.id == id }) else { return }
    let minEnd = blurRegions[index].startSeconds + BlurRegionData.minimumLength
    blurRegions[index].endSeconds = max(minEnd, min(CMTimeGetSeconds(duration), newEnd))
    sortBlurRegions()
    scheduleUndoSnapshot()
  }

  func moveBlurRegion(id: UUID, newStart: Double) {
    guard let index = blurRegions.firstIndex(where: { $0.id == id }) else { return }
    let length = blurRegions[index].endSeconds - blurRegions[index].startSeconds
    let start = max(0, min(CMTimeGetSeconds(duration) - length, newStart))
    blurRegions[index].startSeconds = start
    blurRegions[index].endSeconds = start + length
    sortBlurRegions()
    scheduleUndoSnapshot()
  }

  func removeBlurRegion(id: UUID) {
    blurRegions.removeAll { $0.id == id }
    scheduleUndoSnapshot()
  }

  private func sortBlurRegions() {
    let sorted = blurRegions.enumerated().sorted {
      if $0.element.startSeconds != $1.element.startSeconds {
        return $0.element.startSeconds < $1.element.startSeconds
      }
      return $0.offset < $1.offset
    }
    blurRegions = sorted.map(\.element)
  }
}
