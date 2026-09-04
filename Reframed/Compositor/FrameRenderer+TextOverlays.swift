import AVFoundation
import CoreGraphics
import CoreText

extension FrameRenderer {
  static func drawTextOverlays(
    in context: CGContext,
    canvasRect: CGRect,
    instruction: CompositionInstruction,
    compositionTime: CMTime
  ) {
    guard !instruction.textOverlays.isEmpty else { return }
    for overlay in instruction.textOverlays where overlay.timeRange.containsTime(compositionTime) {
      let progress = computeRegionTransition(compositionTime: compositionTime, region: overlay.transition)
      let type = resolveActiveTransitionType(compositionTime: compositionTime, region: overlay.transition)
      guard progress > 0 else { continue }
      context.saveGState()
      applyTextOverlayTransition(in: context, type: type, progress: progress, rect: overlay.rect)
      drawTextOverlay(overlay, in: context)
      context.restoreGState()
    }
  }

  static func applyTextOverlayTransition(
    in context: CGContext,
    type: RegionTransitionType,
    progress: CGFloat,
    rect: CGRect
  ) {
    switch type {
    case .none:
      break
    case .fade:
      context.setAlpha(progress)
    case .scale:
      context.translateBy(x: rect.midX, y: rect.midY)
      context.scaleBy(x: progress, y: progress)
      context.translateBy(x: -rect.midX, y: -rect.midY)
    case .slide:
      context.translateBy(x: 0, y: -(1.0 - progress) * rect.maxY)
    }
  }

  static func drawTextOverlay(_ overlay: TextOverlayInstruction, in context: CGContext) {
    let rect = overlay.rect
    if let background = overlay.backgroundColor {
      let radius = min(overlay.cornerRadius, rect.width / 2, rect.height / 2)
      let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
      context.saveGState()
      context.setFillColor(background.cgColor)
      context.addPath(path)
      context.fillPath()
      context.restoreGState()
    }

    let textWidth = rect.width - 2 * overlay.paddingH
    let textHeight = rect.height - 2 * overlay.paddingV
    let typeset = TextOverlayLayout.typeset(
      overlay.text,
      fontPixelSize: overlay.fontPixelSize,
      fontWeight: overlay.fontWeight,
      maxTextWidth: textWidth,
      textColor: overlay.textColor.cgColor
    )

    context.saveGState()
    context.textMatrix = .identity
    for (i, line) in typeset.lines.enumerated() {
      let xOffset = (textWidth - typeset.lineWidths[i]) / 2
      let penX = rect.minX + overlay.paddingH + xOffset
      let penY = rect.minY + overlay.paddingV + textHeight - CGFloat(i + 1) * typeset.lineHeight + typeset.descent
      context.textPosition = CGPoint(x: penX, y: penY)
      CTLineDraw(line, context)
    }
    context.restoreGState()
  }
}
