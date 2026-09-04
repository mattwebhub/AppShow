import CoreGraphics
import Testing

@testable import Reframed

struct ImageOverlayLayoutTests {
  private let canvas = CGSize(width: 1920, height: 1080)

  private func overlay(aspectRatio: CGFloat = 2, width: CGFloat = 0.25) -> ImageOverlayData {
    ImageOverlayData(startSeconds: 1, endSeconds: 4, filename: "image.png", aspectRatio: aspectRatio, width: width)
  }

  @Test func widthFractionAndAspectGiveThePixelSize() {
    let rect = ImageOverlayLayout.rect(for: overlay(), canvasSize: canvas)
    #expect(rect.size == CGSize(width: 480, height: 240))
  }

  @Test func tallImageIsScaledDownToFitTheCanvas() {
    let rect = ImageOverlayLayout.rect(for: overlay(aspectRatio: 0.25, width: 1), canvasSize: canvas)
    #expect(rect.height == 1080)
    #expect(rect.width == 270)
  }

  @Test func centerPresetCentresTheImage() {
    let rect = ImageOverlayLayout.rect(for: overlay(), canvasSize: canvas)
    #expect(rect.midX == canvas.width / 2)
    #expect(rect.midY == canvas.height / 2)
  }

  @Test func cornerPresetsSitAtTheMargin() {
    var topLeft = overlay()
    topLeft.position = .topLeft
    var bottomRight = overlay()
    bottomRight.position = .bottomRight
    let first = ImageOverlayLayout.rect(for: topLeft, canvasSize: canvas)
    let second = ImageOverlayLayout.rect(for: bottomRight, canvasSize: canvas)
    #expect(first.minX == 54)
    #expect(first.maxY == 1026)
    #expect(second.maxX == 1866)
    #expect(second.minY == 54)
  }

  @Test func offsetMovesAndClampsTheImage() {
    var value = overlay()
    value.offsetX = 1
    value.offsetY = -1
    let rect = ImageOverlayLayout.rect(for: value, canvasSize: canvas)
    #expect(rect.maxX == canvas.width)
    #expect(rect.maxY == canvas.height)
  }

  @Test func resolvedInstructionCarriesPixelLayout() throws {
    var value = overlay()
    value.cornerRadius = 0.25
    value.opacity = 0.75
    let image = try ImageFixtures.solidImage(width: 16, height: 8)
    let resolved = ImageOverlayLayout.resolve(value, image: image, canvasSize: canvas)
    #expect(resolved.rect.size == CGSize(width: 480, height: 240))
    #expect(resolved.cornerRadius == 60)
    #expect(resolved.opacity == 0.75)
    #expect(resolved.image.width == 16)
  }
}
