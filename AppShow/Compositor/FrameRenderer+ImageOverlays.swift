import AVFoundation
import CoreGraphics

extension FrameRenderer {
  static func drawImageOverlays(
    in context: CGContext,
    instruction: CompositionInstruction,
    compositionTime: CMTime
  ) {
    for overlay in instruction.imageOverlays where overlay.timeRange.containsTime(compositionTime) {
      let progress = computeRegionTransition(compositionTime: compositionTime, region: overlay.transition)
      guard progress > 0 else { continue }
      let type = resolveActiveTransitionType(compositionTime: compositionTime, region: overlay.transition)
      context.saveGState()
      applyTextOverlayTransition(in: context, type: type, progress: progress, rect: overlay.rect)
      context.setAlpha((type == .fade ? progress : 1) * overlay.opacity)
      if overlay.shadow > 0 {
        context.setShadow(
          offset: CGSize(width: 0, height: -overlay.shadow * 0.08),
          blur: overlay.shadow * 0.2,
          color: CGColor(gray: 0, alpha: 0.5)
        )
      }
      let path = CGPath(
        roundedRect: overlay.rect,
        cornerWidth: overlay.cornerRadius,
        cornerHeight: overlay.cornerRadius,
        transform: nil
      )
      context.beginTransparencyLayer(auxiliaryInfo: nil)
      context.addPath(path)
      context.clip()
      context.draw(overlay.image, in: overlay.rect)
      context.endTransparencyLayer()
      context.restoreGState()
    }
  }
}
