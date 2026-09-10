import CoreGraphics
import CoreMedia

enum ImageOverlayLayout {
  static func rect(for overlay: ImageOverlayData, canvasSize: CGSize) -> CGRect {
    let aspect = max(overlay.aspectRatio, 0.0001)
    var size = CGSize(width: max(0, overlay.width) * canvasSize.width, height: 0)
    size.height = size.width / aspect
    let scale = min(1, canvasSize.width / max(size.width, 1), canvasSize.height / max(size.height, 1))
    size.width *= scale
    size.height *= scale
    return TextOverlayLayout.anchoredRect(
      size: size,
      canvasSize: canvasSize,
      position: overlay.position,
      offsetX: overlay.offsetX,
      offsetY: overlay.offsetY
    )
  }

  static func resolve(
    _ overlay: ImageOverlayData,
    image: CGImage,
    canvasSize: CGSize
  ) -> ImageOverlayInstruction {
    let rect = rect(for: overlay, canvasSize: canvasSize)
    return ImageOverlayInstruction(
      transition: RegionTransitionInfo(
        timeRange: CMTimeRange(
          start: CMTime(seconds: overlay.startSeconds, preferredTimescale: 600),
          end: CMTime(seconds: overlay.endSeconds, preferredTimescale: 600)
        ),
        entryTransition: overlay.entryTransition,
        entryDuration: overlay.entryTransitionDuration,
        exitTransition: overlay.exitTransition,
        exitDuration: overlay.exitTransitionDuration
      ),
      image: image,
      rect: rect,
      cornerRadius: min(rect.width, rect.height) * min(0.5, max(0, overlay.cornerRadius)),
      opacity: min(1, max(0, overlay.opacity)),
      shadow: min(100, max(0, overlay.shadow))
    )
  }
}
