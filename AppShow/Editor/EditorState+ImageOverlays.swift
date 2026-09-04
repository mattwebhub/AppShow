import CoreMedia
import Foundation

extension EditorState {
  func activeImageOverlays(at time: Double) -> [ImageOverlayData] {
    imageOverlays.filter { time >= $0.startSeconds && time <= $0.endSeconds }
  }

  func imageOverlayURL(_ overlay: ImageOverlayData) -> URL? {
    project?.bundleURL.appendingPathComponent(overlay.filename)
  }

  @discardableResult
  func addImageOverlay(from source: URL, atTime time: Double) -> ImageOverlayData? {
    let dur = CMTimeGetSeconds(duration)
    guard dur >= ImageOverlayData.minimumLength, let bundle = project?.bundleURL else { return nil }
    do {
      let imported = try ImageOverlayImporter.importImage(from: source, into: bundle)
      let length = min(ImageOverlayData.defaultLength, dur)
      let start = max(0, min(time, dur - length))
      let overlay = ImageOverlayData(
        startSeconds: start,
        endSeconds: start + length,
        filename: imported.filename,
        sourceName: source.lastPathComponent,
        aspectRatio: imported.pixelSize.width / max(imported.pixelSize.height, 1)
      )
      imageOverlays.append(overlay)
      sortImageOverlays()
      return overlay
    } catch {
      logger.error("Failed to import image overlay: \(error.localizedDescription)")
      return nil
    }
  }

  func updateImageOverlay(id: UUID, _ change: (inout ImageOverlayData) -> Void) {
    guard let index = imageOverlays.firstIndex(where: { $0.id == id }) else { return }
    var overlay = imageOverlays[index]
    change(&overlay)
    overlay.id = id
    overlay.startSeconds = imageOverlays[index].startSeconds
    overlay.endSeconds = imageOverlays[index].endSeconds
    imageOverlays[index] = overlay
  }

  func updateImageOverlayStart(id: UUID, newStart: Double) {
    guard let index = imageOverlays.firstIndex(where: { $0.id == id }) else { return }
    let maxStart = imageOverlays[index].endSeconds - ImageOverlayData.minimumLength
    imageOverlays[index].startSeconds = max(0, min(maxStart, newStart))
    sortImageOverlays()
  }

  func updateImageOverlayEnd(id: UUID, newEnd: Double) {
    guard let index = imageOverlays.firstIndex(where: { $0.id == id }) else { return }
    let minEnd = imageOverlays[index].startSeconds + ImageOverlayData.minimumLength
    imageOverlays[index].endSeconds = max(minEnd, min(CMTimeGetSeconds(duration), newEnd))
  }

  func moveImageOverlay(id: UUID, newStart: Double) {
    guard let index = imageOverlays.firstIndex(where: { $0.id == id }) else { return }
    let length = imageOverlays[index].endSeconds - imageOverlays[index].startSeconds
    let start = max(0, min(CMTimeGetSeconds(duration) - length, newStart))
    imageOverlays[index].startSeconds = start
    imageOverlays[index].endSeconds = start + length
    sortImageOverlays()
  }

  func removeImageOverlay(id: UUID) {
    imageOverlays.removeAll { $0.id == id }
  }

  func availableImageOverlays(_ overlays: [ImageOverlayData]) -> [ImageOverlayData] {
    guard let bundle = project?.bundleURL else { return [] }
    let available = overlays.filter { FileManager.default.fileExists(atPath: bundle.appendingPathComponent($0.filename).path) }
    if available.count != overlays.count {
      logger.warning("Dropped \(overlays.count - available.count) image overlays with missing files")
    }
    return available
  }

  private func sortImageOverlays() {
    let sorted = imageOverlays.enumerated().sorted {
      $0.element.startSeconds == $1.element.startSeconds
        ? $0.offset < $1.offset
        : $0.element.startSeconds < $1.element.startSeconds
    }
    imageOverlays = sorted.map(\.element)
  }
}
