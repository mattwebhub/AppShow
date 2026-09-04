import AppKit
import CoreGraphics
import CoreMedia
import CoreText
import Foundation

enum TextOverlayLayout {
  static let maxWidthRatio: CGFloat = 0.8
  static let marginRatio: CGFloat = 0.05
  static let paddingHRatio: CGFloat = 0.5
  static let paddingVRatio: CGFloat = 0.25
  static let minFontPixelSize: CGFloat = 8

  struct TypesetText {
    let lines: [CTLine]
    let lineWidths: [CGFloat]
    let lineHeight: CGFloat
    let descent: CGFloat
    let size: CGSize
  }

  static func fontPixelSize(fontSize: CGFloat, canvasHeight: CGFloat) -> CGFloat {
    max(minFontPixelSize, fontSize * canvasHeight)
  }

  static func maxTextWidth(canvasWidth: CGFloat, fontPixelSize: CGFloat) -> CGFloat {
    max(1, canvasWidth * maxWidthRatio - 2 * fontPixelSize * paddingHRatio)
  }

  static func font(pixelSize: CGFloat, weight: CaptionFontWeight) -> CTFont {
    let nsFont = NSFont.systemFont(ofSize: pixelSize, weight: weight.nsWeight)
    return CTFontCreateWithName(nsFont.fontName as CFString, pixelSize, nil)
  }

  static func typeset(
    _ text: String,
    fontPixelSize: CGFloat,
    fontWeight: CaptionFontWeight,
    maxTextWidth: CGFloat,
    textColor: CGColor? = nil
  ) -> TypesetText {
    let ctFont = font(pixelSize: fontPixelSize, weight: fontWeight)
    var alignment = CTTextAlignment.center
    let paragraphStyle = withUnsafeMutablePointer(to: &alignment) { alignPtr in
      let setting = CTParagraphStyleSetting(
        spec: .alignment,
        valueSize: MemoryLayout<CTTextAlignment>.size,
        value: alignPtr
      )
      return withUnsafePointer(to: setting) { ptr in
        CTParagraphStyleCreate(ptr, 1)
      }
    }
    var attributes: [NSAttributedString.Key: Any] = [
      .font: ctFont,
      NSAttributedString.Key(kCTParagraphStyleAttributeName as String): paragraphStyle,
    ]
    if let textColor {
      attributes[.foregroundColor] = textColor
    }
    let attrString = NSAttributedString(string: text, attributes: attributes)
    let typesetter = CTTypesetterCreateWithAttributedString(attrString)
    let ascent = CTFontGetAscent(ctFont)
    let descent = CTFontGetDescent(ctFont)
    let lineHeight = ascent + descent + CTFontGetLeading(ctFont)

    var lines: [CTLine] = []
    var lineWidths: [CGFloat] = []
    var startIndex: CFIndex = 0
    let totalLength = CFAttributedStringGetLength(attrString)
    while startIndex < totalLength {
      let count = max(1, CTTypesetterSuggestLineBreak(typesetter, startIndex, Double(maxTextWidth)))
      let line = CTTypesetterCreateLine(typesetter, CFRangeMake(startIndex, count))
      lines.append(line)
      lineWidths.append(CTLineGetTypographicBounds(line, nil, nil, nil))
      startIndex += count
    }

    let size = CGSize(
      width: ceil(lineWidths.max() ?? 0),
      height: ceil(lineHeight * CGFloat(max(lines.count, 1)))
    )
    return TypesetText(lines: lines, lineWidths: lineWidths, lineHeight: lineHeight, descent: descent, size: size)
  }

  static func measureText(
    _ text: String,
    fontPixelSize: CGFloat,
    fontWeight: CaptionFontWeight,
    maxTextWidth: CGFloat
  ) -> CGSize {
    typeset(text, fontPixelSize: fontPixelSize, fontWeight: fontWeight, maxTextWidth: maxTextWidth).size
  }

  static func pillRect(
    textSize: CGSize,
    fontPixelSize: CGFloat,
    canvasSize: CGSize,
    position: TextOverlayPosition,
    offsetX: CGFloat,
    offsetY: CGFloat
  ) -> CGRect {
    let width = textSize.width + 2 * fontPixelSize * paddingHRatio
    let height = textSize.height + 2 * fontPixelSize * paddingVRatio
    let margin = canvasSize.height * marginRatio
    let freeWidth = max(0, canvasSize.width - 2 * margin - width)
    let freeHeight = max(0, canvasSize.height - 2 * margin - height)
    let x = margin + position.anchorX * freeWidth + offsetX * canvasSize.width
    let yFromTop = margin + position.anchorY * freeHeight + offsetY * canvasSize.height
    let y = canvasSize.height - yFromTop - height
    return CGRect(
      x: max(0, min(canvasSize.width - width, x)),
      y: max(0, min(canvasSize.height - height, y)),
      width: width,
      height: height
    )
  }

  static func resolve(_ overlay: TextOverlayData, canvasSize: CGSize) -> TextOverlayInstruction {
    let fontPixelSize = fontPixelSize(fontSize: overlay.fontSize, canvasHeight: canvasSize.height)
    let textSize = measureText(
      overlay.text,
      fontPixelSize: fontPixelSize,
      fontWeight: overlay.fontWeight,
      maxTextWidth: maxTextWidth(canvasWidth: canvasSize.width, fontPixelSize: fontPixelSize)
    )
    let rect = pillRect(
      textSize: textSize,
      fontPixelSize: fontPixelSize,
      canvasSize: canvasSize,
      position: overlay.position,
      offsetX: overlay.offsetX,
      offsetY: overlay.offsetY
    )
    let background: CodableColor? =
      overlay.showBackground
      ? CodableColor(
        r: overlay.backgroundColor.r,
        g: overlay.backgroundColor.g,
        b: overlay.backgroundColor.b,
        a: overlay.backgroundColor.a * overlay.backgroundOpacity
      ) : nil
    return TextOverlayInstruction(
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
      text: overlay.text,
      fontPixelSize: fontPixelSize,
      fontWeight: overlay.fontWeight,
      textColor: overlay.textColor,
      backgroundColor: background,
      cornerRadius: rect.height * overlay.cornerRadius,
      rect: rect,
      paddingH: fontPixelSize * paddingHRatio,
      paddingV: fontPixelSize * paddingVRatio
    )
  }
}
