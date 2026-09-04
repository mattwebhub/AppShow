import CoreGraphics
import CoreMedia
import Testing

@testable import AppShow

struct TextOverlayLayoutTests {
  private let canvas = CGSize(width: 1920, height: 1080)
  private let textSize = CGSize(width: 400, height: 100)
  private let fontPixelSize: CGFloat = 64

  private var margin: CGFloat { canvas.height * TextOverlayLayout.marginRatio }

  private func pill(
    _ position: TextOverlayPosition,
    offsetX: CGFloat = 0,
    offsetY: CGFloat = 0
  ) -> CGRect {
    TextOverlayLayout.pillRect(
      textSize: textSize,
      fontPixelSize: fontPixelSize,
      canvasSize: canvas,
      position: position,
      offsetX: offsetX,
      offsetY: offsetY
    )
  }

  private func near(_ a: CGFloat, _ b: CGFloat, tolerance: CGFloat = 0.01) -> Bool {
    abs(a - b) <= tolerance
  }

  @Test func centerPresetCentresThePill() {
    let rect = pill(.center)
    #expect(near(rect.width, 400 + 2 * 64 * TextOverlayLayout.paddingHRatio))
    #expect(near(rect.height, 100 + 2 * 64 * TextOverlayLayout.paddingVRatio))
    #expect(near(rect.midX, 960))
    #expect(near(rect.midY, 540))
  }

  @Test(arguments: [
    TextOverlayPosition.topLeft, .top, .topRight, .bottomLeft, .bottom, .bottomRight,
  ])
  func cornerPresetsSitAtTheMargin(position: TextOverlayPosition) {
    let rect = pill(position)
    switch position.anchorX {
    case 0: #expect(near(rect.minX, margin))
    case 1: #expect(near(rect.maxX, canvas.width - margin))
    default: #expect(near(rect.midX, 960))
    }
    if position.anchorY == 0 {
      #expect(near(rect.maxY, canvas.height - margin))
    } else {
      #expect(near(rect.minY, margin))
    }
  }

  @Test func offsetMovesThePillByCanvasFractions() {
    let rect = pill(.center, offsetX: 0.1, offsetY: 0.1)
    #expect(near(rect.midX, 960 + 192))
    #expect(near(rect.midY, 540 - 108))
  }

  @Test func offsetIsClampedInsideTheCanvas() {
    let rect = pill(.topRight, offsetX: 0.5, offsetY: -0.5)
    #expect(near(rect.maxX, canvas.width))
    #expect(near(rect.maxY, canvas.height))
    let low = pill(.bottomLeft, offsetX: -0.5, offsetY: 0.5)
    #expect(near(low.minX, 0))
    #expect(near(low.minY, 0))
  }

  @Test func fontPixelSizeScalesWithCanvasHeight() {
    #expect(near(TextOverlayLayout.fontPixelSize(fontSize: 0.06, canvasHeight: 1080), 64.8))
    #expect(near(TextOverlayLayout.fontPixelSize(fontSize: 0.06, canvasHeight: 36), TextOverlayLayout.minFontPixelSize))
  }

  @Test func longTextWrapsWithinMaxWidthAndGrowsInHeight() {
    let maxTextWidth = TextOverlayLayout.maxTextWidth(canvasWidth: canvas.width, fontPixelSize: fontPixelSize)
    #expect(near(maxTextWidth, canvas.width * TextOverlayLayout.maxWidthRatio - 2 * 64 * TextOverlayLayout.paddingHRatio))

    let short = TextOverlayLayout.measureText("Hi", fontPixelSize: fontPixelSize, fontWeight: .bold, maxTextWidth: maxTextWidth)
    let long = TextOverlayLayout.measureText(
      String(repeating: "Open the settings window and choose the display tab ", count: 4),
      fontPixelSize: fontPixelSize,
      fontWeight: .bold,
      maxTextWidth: maxTextWidth
    )
    let explicit = TextOverlayLayout.measureText("One\nTwo", fontPixelSize: fontPixelSize, fontWeight: .bold, maxTextWidth: maxTextWidth)

    #expect(short.width > 0 && short.height > 0)
    #expect(long.width <= maxTextWidth)
    #expect(long.height >= short.height * 2)
    #expect(near(explicit.height, short.height * 2, tolerance: 1))
  }

  @Test func resolvedInstructionCarriesPixelLayout() {
    var overlay = TextOverlayData(startSeconds: 1, endSeconds: 4, text: "Hi", fontSize: 0.1)
    overlay.entryTransition = .slide
    overlay.entryTransitionDuration = 0.5
    overlay.exitTransition = .none

    let resolved = TextOverlayLayout.resolve(overlay, canvasSize: canvas)

    #expect(near(resolved.fontPixelSize, 108))
    #expect(near(resolved.paddingH, 54))
    #expect(near(resolved.paddingV, 27))
    #expect(near(resolved.rect.midX, 960))
    #expect(near(resolved.rect.midY, 540))
    #expect(resolved.rect.width <= canvas.width * TextOverlayLayout.maxWidthRatio)
    #expect(near(resolved.cornerRadius, resolved.rect.height * 0.25))
    #expect(resolved.text == "Hi")
    #expect(resolved.fontWeight == .bold)
    #expect(resolved.textColor == CodableColor(r: 1, g: 1, b: 1))
    #expect(resolved.backgroundColor == CodableColor(r: 0, g: 0, b: 0, a: 0.6))
    #expect(resolved.timeRange.start.seconds == 1)
    #expect(resolved.timeRange.end.seconds == 4)
    #expect(resolved.transition.entryTransition == .slide)
    #expect(resolved.transition.entryDuration == 0.5)
    #expect(resolved.transition.exitTransition == .none)

    overlay.showBackground = false
    #expect(TextOverlayLayout.resolve(overlay, canvasSize: canvas).backgroundColor == nil)
  }
}
