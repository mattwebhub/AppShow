import CoreMedia
import Foundation

extension EditorState {
  var showOverlayTrack: Bool { !textOverlays.isEmpty }

  func activeTextOverlays(at time: Double) -> [TextOverlayData] {
    textOverlays.filter { time >= $0.startSeconds && time <= $0.endSeconds }
  }

  @discardableResult
  func addTextOverlay(atTime time: Double) -> TextOverlayData? {
    let dur = CMTimeGetSeconds(duration)
    guard dur >= TextOverlayData.minimumLength else { return nil }
    let length = min(TextOverlayData.defaultLength, dur)
    let start = max(0, min(time, dur - length))
    let overlay = TextOverlayData(startSeconds: start, endSeconds: start + length)
    textOverlays.append(overlay)
    sortTextOverlays()
    return overlay
  }

  func updateTextOverlay(id: UUID, _ change: (inout TextOverlayData) -> Void) {
    guard let idx = textOverlays.firstIndex(where: { $0.id == id }) else { return }
    var overlay = textOverlays[idx]
    change(&overlay)
    overlay.id = id
    overlay.startSeconds = textOverlays[idx].startSeconds
    overlay.endSeconds = textOverlays[idx].endSeconds
    textOverlays[idx] = overlay
  }

  func updateTextOverlayStart(id: UUID, newStart: Double) {
    guard let idx = textOverlays.firstIndex(where: { $0.id == id }) else { return }
    let maxStart = textOverlays[idx].endSeconds - TextOverlayData.minimumLength
    textOverlays[idx].startSeconds = max(0, min(maxStart, newStart))
    sortTextOverlays()
  }

  func updateTextOverlayEnd(id: UUID, newEnd: Double) {
    guard let idx = textOverlays.firstIndex(where: { $0.id == id }) else { return }
    let dur = CMTimeGetSeconds(duration)
    let minEnd = textOverlays[idx].startSeconds + TextOverlayData.minimumLength
    textOverlays[idx].endSeconds = max(minEnd, min(dur, newEnd))
  }

  func moveTextOverlay(id: UUID, newStart: Double) {
    guard let idx = textOverlays.firstIndex(where: { $0.id == id }) else { return }
    let dur = CMTimeGetSeconds(duration)
    let length = textOverlays[idx].endSeconds - textOverlays[idx].startSeconds
    let clampedStart = max(0, min(dur - length, newStart))
    textOverlays[idx].startSeconds = clampedStart
    textOverlays[idx].endSeconds = clampedStart + length
    sortTextOverlays()
  }

  func removeTextOverlay(id: UUID) {
    textOverlays.removeAll { $0.id == id }
  }

  private func sortTextOverlays() {
    let sorted = textOverlays.enumerated().sorted {
      $0.element.startSeconds == $1.element.startSeconds
        ? $0.offset < $1.offset
        : $0.element.startSeconds < $1.element.startSeconds
    }
    textOverlays = sorted.map(\.element)
  }
}
