import AVFoundation
import AppKit

extension VideoPreviewContainer {
  func updateImageOverlays(
    _ overlays: [ImageOverlayData],
    directory: URL?,
    time: Double
  ) {
    if imageOverlayDirectory != directory {
      imageOverlayDirectory = directory
      imageOverlayImages.removeAll()
    }
    let missing = overlays.filter { imageOverlayImages[$0.filename] == nil }
    imageOverlayImages.merge(ImageOverlayImporter.loadImages(for: missing, in: directory)) { current, _ in current }
    lastImageOverlays = overlays
    lastImageOverlayTime = time
    applyImageOverlays()
  }

  func applyImageOverlays() {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    defer { CATransaction.commit() }

    let canvasRect = AVMakeRect(aspectRatio: currentCanvasSize, insideRect: bounds)
    imageOverlayLayer.frame = canvasRect
    let active = lastImageOverlays.filter {
      lastImageOverlayTime >= $0.startSeconds
        && lastImageOverlayTime <= $0.endSeconds
        && imageOverlayImages[$0.filename] != nil
    }
    var layers = (imageOverlayLayer.sublayers ?? []).compactMap { $0 as? ImageOverlayPreviewLayer }
    while layers.count < active.count {
      let layer = ImageOverlayPreviewLayer()
      imageOverlayLayer.addSublayer(layer)
      layers.append(layer)
    }
    while layers.count > active.count {
      layers.removeLast().removeFromSuperlayer()
    }

    let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    for (overlay, layer) in zip(active, layers) {
      guard let image = imageOverlayImages[overlay.filename] else { continue }
      let resolved = ImageOverlayLayout.resolve(overlay, image: image, canvasSize: canvasRect.size)
      let progress = VideoPreviewView.computeTransitionProgress(
        time: lastImageOverlayTime,
        start: overlay.startSeconds,
        end: overlay.endSeconds,
        entryTransition: overlay.entryTransition,
        entryDuration: overlay.entryTransitionDuration,
        exitTransition: overlay.exitTransition,
        exitDuration: overlay.exitTransitionDuration
      )
      let type = VideoPreviewView.resolveTransitionType(
        time: lastImageOverlayTime,
        start: overlay.startSeconds,
        end: overlay.endSeconds,
        entryTransition: overlay.entryTransition,
        entryDuration: overlay.entryTransitionDuration,
        exitTransition: overlay.exitTransition,
        exitDuration: overlay.exitTransitionDuration
      )
      layer.apply(resolved, transitionType: type, progress: progress, contentsScale: scale)
    }
  }
}

final class ImageOverlayPreviewLayer: CALayer {
  private let imageLayer = CALayer()

  override init() {
    super.init()
    masksToBounds = false
    imageLayer.contentsGravity = .resize
    imageLayer.masksToBounds = true
    addSublayer(imageLayer)
  }

  override init(layer: Any) {
    super.init(layer: layer)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  func apply(
    _ resolved: ImageOverlayInstruction,
    transitionType: RegionTransitionType,
    progress: CGFloat,
    contentsScale: CGFloat
  ) {
    self.contentsScale = contentsScale
    frame = resolved.rect
    imageLayer.contentsScale = contentsScale
    imageLayer.frame = bounds
    imageLayer.contents = resolved.image
    imageLayer.cornerRadius = resolved.cornerRadius
    shadowColor = NSColor.black.cgColor
    shadowOffset = CGSize(width: 0, height: -resolved.shadow * 0.08)
    shadowRadius = resolved.shadow * 0.2
    shadowOpacity = resolved.shadow > 0 ? 0.5 : 0
    shadowPath = CGPath(
      roundedRect: bounds,
      cornerWidth: resolved.cornerRadius,
      cornerHeight: resolved.cornerRadius,
      transform: nil
    )

    switch transitionType {
    case .none:
      opacity = Float(resolved.opacity)
      transform = CATransform3DIdentity
    case .fade:
      opacity = Float(progress * resolved.opacity)
      transform = CATransform3DIdentity
    case .scale:
      opacity = Float(resolved.opacity)
      transform = CATransform3DMakeScale(progress, progress, 1)
    case .slide:
      opacity = Float(resolved.opacity)
      transform = CATransform3DMakeTranslation(0, -(1 - progress) * resolved.rect.maxY, 0)
    }
  }
}
