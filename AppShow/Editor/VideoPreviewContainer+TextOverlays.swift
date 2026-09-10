import AVFoundation
import AppKit
import CoreText

extension VideoPreviewContainer {
  func updateTextOverlays(_ overlays: [TextOverlayData], time: Double) {
    lastTextOverlays = overlays
    lastTextOverlayTime = time
    applyTextOverlays()
  }

  func applyTextOverlays() {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    defer { CATransaction.commit() }

    let canvasRect = AVMakeRect(aspectRatio: currentCanvasSize, insideRect: bounds)
    textOverlayLayer.frame = canvasRect
    let time = lastTextOverlayTime
    let active = lastTextOverlays.filter { time >= $0.startSeconds && time <= $0.endSeconds }
    let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2

    var pills = (textOverlayLayer.sublayers ?? []).compactMap { $0 as? TextOverlayPillLayer }
    while pills.count < active.count {
      let pill = TextOverlayPillLayer()
      textOverlayLayer.addSublayer(pill)
      pills.append(pill)
    }
    while pills.count > active.count {
      pills.removeLast().removeFromSuperlayer()
    }

    for (overlay, pill) in zip(active, pills) {
      let resolved = TextOverlayLayout.resolve(overlay, canvasSize: canvasRect.size)
      let progress = VideoPreviewView.computeTransitionProgress(
        time: time,
        start: overlay.startSeconds,
        end: overlay.endSeconds,
        entryTransition: overlay.entryTransition,
        entryDuration: overlay.entryTransitionDuration,
        exitTransition: overlay.exitTransition,
        exitDuration: overlay.exitTransitionDuration
      )
      let type = VideoPreviewView.resolveTransitionType(
        time: time,
        start: overlay.startSeconds,
        end: overlay.endSeconds,
        entryTransition: overlay.entryTransition,
        entryDuration: overlay.entryTransitionDuration,
        exitTransition: overlay.exitTransition,
        exitDuration: overlay.exitTransitionDuration
      )
      pill.apply(resolved, transitionType: type, progress: progress, contentsScale: scale)
    }
  }
}

final class TextOverlayPillLayer: CALayer {
  private let textLayer = CATextLayer()

  override init() {
    super.init()
    masksToBounds = false
    textLayer.isWrapped = true
    textLayer.truncationMode = .none
    textLayer.alignmentMode = .center
    addSublayer(textLayer)
  }

  override init(layer: Any) {
    super.init(layer: layer)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  func apply(
    _ resolved: TextOverlayInstruction,
    transitionType: RegionTransitionType,
    progress: CGFloat,
    contentsScale: CGFloat
  ) {
    self.contentsScale = contentsScale
    textLayer.contentsScale = contentsScale
    frame = resolved.rect
    backgroundColor = resolved.backgroundColor?.cgColor ?? CGColor(red: 0, green: 0, blue: 0, alpha: 0)
    cornerRadius = min(resolved.cornerRadius, resolved.rect.width / 2, resolved.rect.height / 2)
    textLayer.frame = CGRect(
      x: resolved.paddingH,
      y: resolved.paddingV,
      width: resolved.rect.width - 2 * resolved.paddingH,
      height: resolved.rect.height - 2 * resolved.paddingV
    )
    textLayer.string = Self.attributedText(resolved)

    switch transitionType {
    case .none:
      opacity = 1
      transform = CATransform3DIdentity
    case .fade:
      opacity = Float(progress)
      transform = CATransform3DIdentity
    case .scale:
      opacity = 1
      transform = CATransform3DMakeScale(progress, progress, 1)
    case .slide:
      opacity = 1
      transform = CATransform3DMakeTranslation(0, -(1.0 - progress) * resolved.rect.maxY, 0)
    }
  }

  private static func attributedText(_ resolved: TextOverlayInstruction) -> NSAttributedString {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    return NSAttributedString(
      string: resolved.text,
      attributes: [
        .font: TextOverlayLayout.font(pixelSize: resolved.fontPixelSize, weight: resolved.fontWeight),
        .foregroundColor: resolved.textColor.cgColor,
        .paragraphStyle: paragraph,
      ]
    )
  }
}
