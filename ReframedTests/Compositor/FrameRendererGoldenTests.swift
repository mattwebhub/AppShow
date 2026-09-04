import CoreMedia
import CoreVideo
import Testing

@testable import Reframed

struct FrameRendererGoldenTests {
  private static let width = 64
  private static let height = 36

  private struct Pixel: Equatable {
    let b: UInt8
    let g: UInt8
    let r: UInt8
    let a: UInt8
  }

  private static let red = Pixel(b: 0, g: 0, r: 255, a: 255)
  private static let green = Pixel(b: 0, g: 255, r: 0, a: 255)

  private func makeBuffer(fill: Pixel? = nil) throws -> CVPixelBuffer {
    var buffer: CVPixelBuffer?
    let attributes: [CFString: Any] = [
      kCVPixelBufferCGImageCompatibilityKey: true,
      kCVPixelBufferCGBitmapContextCompatibilityKey: true,
    ]
    let status = CVPixelBufferCreate(
      kCFAllocatorDefault,
      Self.width,
      Self.height,
      kCVPixelFormatType_32BGRA,
      attributes as CFDictionary,
      &buffer
    )
    #expect(status == kCVReturnSuccess)
    let result = try #require(buffer)
    if let fill {
      CVPixelBufferLockBaseAddress(result, [])
      let base = try #require(CVPixelBufferGetBaseAddress(result))
      let bytesPerRow = CVPixelBufferGetBytesPerRow(result)
      for y in 0..<Self.height {
        let row = base.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt8.self)
        for x in 0..<Self.width {
          row[x * 4] = fill.b
          row[x * 4 + 1] = fill.g
          row[x * 4 + 2] = fill.r
          row[x * 4 + 3] = fill.a
        }
      }
      CVPixelBufferUnlockBaseAddress(result, [])
    }
    return result
  }

  private func pixel(_ buffer: CVPixelBuffer, x: Int, y: Int) throws -> Pixel {
    CVPixelBufferLockBaseAddress(buffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
    let base = try #require(CVPixelBufferGetBaseAddress(buffer))
    let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
    let row = base.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt8.self)
    return Pixel(b: row[x * 4], g: row[x * 4 + 1], r: row[x * 4 + 2], a: row[x * 4 + 3])
  }

  private func expectClose(
    _ actual: Pixel,
    _ expected: Pixel,
    tolerance: Int = 3,
    sourceLocation: SourceLocation = #_sourceLocation
  ) {
    let within =
      abs(Int(actual.r) - Int(expected.r)) <= tolerance
      && abs(Int(actual.g) - Int(expected.g)) <= tolerance
      && abs(Int(actual.b) - Int(expected.b)) <= tolerance
      && abs(Int(actual.a) - Int(expected.a)) <= tolerance
    #expect(within, "actual \(actual) expected \(expected)", sourceLocation: sourceLocation)
  }

  private func instruction(
    videoCornerRadius: CGFloat = 0,
    videoRegions: [RegionTransitionInfo] = [],
    textOverlays: [TextOverlayInstruction] = [],
    imageOverlays: [ImageOverlayInstruction] = [],
    blurRegions: [BlurRegionInstruction] = [],
    zoomTimeline: ZoomTimeline? = nil,
    padding: CGFloat = 8
  ) -> CompositionInstruction {
    CompositionInstruction(
      timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 2, preferredTimescale: 600)),
      screenTrackID: 1,
      webcamTrackID: nil,
      cameraRect: nil,
      cameraCornerRadius: 0,
      outputSize: CGSize(width: Self.width, height: Self.height),
      backgroundColors: [(r: 1, g: 0, b: 0, a: 1)],
      paddingH: padding,
      paddingV: padding,
      videoCornerRadius: videoCornerRadius,
      zoomTimeline: zoomTimeline,
      videoRegions: videoRegions,
      textOverlays: textOverlays,
      imageOverlays: imageOverlays,
      blurRegions: blurRegions
    )
  }

  private func makeVerticalSplitBuffer(splitX: Int = Self.width / 2) throws -> CVPixelBuffer {
    let buffer = try makeBuffer()
    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
    let base = try #require(CVPixelBufferGetBaseAddress(buffer))
    let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
    for y in 0..<Self.height {
      let row = base.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt8.self)
      for x in 0..<Self.width {
        let value: UInt8 = x < splitX ? 0 : 255
        row[x * 4] = value
        row[x * 4 + 1] = value
        row[x * 4 + 2] = value
        row[x * 4 + 3] = 255
      }
    }
    return buffer
  }

  private func bluePillOverlay(start: Double = 0, end: Double = 2) -> TextOverlayInstruction {
    let blue = CodableColor(r: 0, g: 0, b: 1)
    var overlay = TextOverlayData(startSeconds: start, endSeconds: end, text: "Hi", fontSize: 0.3)
    overlay.textColor = blue
    overlay.backgroundColor = blue
    overlay.backgroundOpacity = 1
    overlay.cornerRadius = 0
    overlay.entryTransition = .fade
    overlay.entryTransitionDuration = 1
    overlay.exitTransition = .none
    return TextOverlayLayout.resolve(overlay, canvasSize: CGSize(width: Self.width, height: Self.height))
  }

  private func expectPill(_ pixel: Pixel, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(pixel.b >= 200 && pixel.r <= 80 && pixel.g <= 80, "actual \(pixel)", sourceLocation: sourceLocation)
  }

  private func blueImageOverlay(start: Double = 0, end: Double = 2) throws -> ImageOverlayInstruction {
    var overlay = ImageOverlayData(
      startSeconds: start,
      endSeconds: end,
      filename: "blue.png",
      aspectRatio: 1,
      width: 0.5
    )
    overlay.entryTransition = .fade
    overlay.entryTransitionDuration = 1
    overlay.exitTransition = .none
    return ImageOverlayLayout.resolve(
      overlay,
      image: try ImageFixtures.solidImage(width: 8, height: 8),
      canvasSize: CGSize(width: Self.width, height: Self.height)
    )
  }

  private func render(_ instruction: CompositionInstruction, at seconds: Double = 0.5) throws -> CVPixelBuffer {
    let screen = try makeBuffer(fill: Self.green)
    let output = try makeBuffer()
    FrameRenderer.renderFrame(
      screenBuffer: screen,
      webcamBuffer: nil,
      outputBuffer: output,
      compositionTime: CMTime(seconds: seconds, preferredTimescale: 600),
      instruction: instruction
    )
    return output
  }

  private func videoRectCorner() throws -> (x: Int, y: Int) {
    let screen = try makeBuffer()
    let output = try makeBuffer()
    let state = FrameRenderer.computeFrameState(
      screenBuffer: screen,
      webcamBuffer: nil,
      outputBuffer: output,
      compositionTime: .zero,
      instruction: instruction()
    )
    let x = Int(state.videoRect.minX.rounded(.up))
    let y = Self.height - 1 - Int(state.videoRect.minY.rounded(.up))
    return (x, y)
  }

  private func expectBackground(_ pixel: Pixel, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(pixel.r >= 250 && pixel.g <= 45 && pixel.b <= 3, "actual \(pixel)", sourceLocation: sourceLocation)
  }

  private func expectScreen(_ pixel: Pixel, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(pixel.g >= 250 && pixel.r <= 3 && pixel.b <= 3, "actual \(pixel)", sourceLocation: sourceLocation)
  }

  @Test func solidRedBackgroundIsColorMatchedFromGenericRGB() throws {
    let output = try render(instruction())

    expectClose(try pixel(output, x: 1, y: 1), Pixel(b: 0, g: 38, r: 255, a: 255))
  }

  @Test func paddingShowsBackgroundAtEdgeAndScreenAtCentre() throws {
    let output = try render(instruction())

    expectBackground(try pixel(output, x: 1, y: 1))
    expectScreen(try pixel(output, x: Self.width / 2, y: Self.height / 2))
    expectClose(try pixel(output, x: Self.width / 2, y: Self.height / 2), Self.green)
  }

  @Test func blurRegionChangesOnlyTheSelectedSourceRect() throws {
    let blur = BlurRegionInstruction(
      timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 1, preferredTimescale: 600)),
      rect: CGRect(x: 0.25, y: 0, width: 0.5, height: 1),
      radius: 8
    )
    let output = try makeBuffer()
    FrameRenderer.renderFrame(
      screenBuffer: try makeVerticalSplitBuffer(),
      webcamBuffer: nil,
      outputBuffer: output,
      compositionTime: CMTime(seconds: 0.5, preferredTimescale: 600),
      instruction: instruction(blurRegions: [blur], padding: 0)
    )

    let center = try pixel(output, x: Self.width / 2, y: Self.height / 2)
    #expect(center.r > 40 && center.r < 215)
    #expect(try pixel(output, x: 4, y: Self.height / 2).r < 10)
    #expect(try pixel(output, x: Self.width - 4, y: Self.height / 2).r > 245)
  }

  @Test func blurRegionStaysInSourceCoordinatesWhileZoomed() throws {
    let blur = BlurRegionInstruction(
      timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 1, preferredTimescale: 600)),
      rect: CGRect(x: 0.25, y: 0, width: 0.1, height: 1),
      radius: 6
    )
    let zoom = ZoomTimeline(
      keyframes: [ZoomKeyframe(t: 0, zoomLevel: 2, centerX: 0.5, centerY: 0.5, isAuto: false)]
    )
    let output = try makeBuffer()
    FrameRenderer.renderFrame(
      screenBuffer: try makeVerticalSplitBuffer(splitX: 19),
      webcamBuffer: nil,
      outputBuffer: output,
      compositionTime: CMTime(seconds: 0.5, preferredTimescale: 600),
      instruction: instruction(blurRegions: [blur], zoomTimeline: zoom, padding: 0)
    )

    let blurredEdge = try pixel(output, x: 6, y: Self.height / 2)
    #expect(blurredEdge.r > 40 && blurredEdge.r < 215)
    #expect(try pixel(output, x: Self.width / 2, y: Self.height / 2).r > 245)
  }

  @Test func videoRectCornerIsScreenWithoutCornerRadius() throws {
    let output = try render(instruction(videoCornerRadius: 0))
    let corner = try videoRectCorner()

    expectScreen(try pixel(output, x: corner.x, y: corner.y))
  }

  @Test func videoRectCornerIsBackgroundWithCornerRadius() throws {
    let output = try render(instruction(videoCornerRadius: 12))
    let corner = try videoRectCorner()

    expectBackground(try pixel(output, x: corner.x, y: corner.y))
    expectScreen(try pixel(output, x: Self.width / 2, y: Self.height / 2))
  }

  @Test func fadeTransitionAtHalfProgressBlendsScreenOverBackground() throws {
    let region = RegionTransitionInfo(
      timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 2, preferredTimescale: 600)),
      entryTransition: .fade,
      entryDuration: 1,
      exitTransition: .none,
      exitDuration: 0
    )
    let background = try pixel(try render(instruction()), x: 1, y: 1)
    let expected = Pixel(
      b: UInt8((Int(background.b) + Int(Self.green.b)) / 2),
      g: UInt8((Int(background.g) + Int(Self.green.g)) / 2),
      r: UInt8((Int(background.r) + Int(Self.green.r)) / 2),
      a: 255
    )

    let output = try render(instruction(videoRegions: [region]), at: 0.5)

    expectClose(try pixel(output, x: Self.width / 2, y: Self.height / 2), expected)
    expectClose(try pixel(output, x: 1, y: 1), background)
  }

  @Test func textOverlayPillCoversTheCentre() throws {
    let output = try render(instruction(textOverlays: [bluePillOverlay()]), at: 1.5)

    expectPill(try pixel(output, x: Self.width / 2, y: Self.height / 2))
    expectBackground(try pixel(output, x: 1, y: 1))
  }

  @Test func textOverlayIsAbsentAtTransitionProgressZero() throws {
    let output = try render(instruction(textOverlays: [bluePillOverlay()]), at: 0)

    expectScreen(try pixel(output, x: Self.width / 2, y: Self.height / 2))
    expectBackground(try pixel(output, x: 1, y: 1))
  }

  @Test func textOverlayFadeAtHalfProgressBlendsWithScreen() throws {
    let overlay = bluePillOverlay()
    let start = try pixel(try render(instruction(textOverlays: [overlay]), at: 0), x: Self.width / 2, y: Self.height / 2)
    let midpoint = try pixel(try render(instruction(textOverlays: [overlay]), at: 0.5), x: Self.width / 2, y: Self.height / 2)
    let end = try pixel(try render(instruction(textOverlays: [overlay]), at: 1), x: Self.width / 2, y: Self.height / 2)

    #expect(midpoint.b > start.b && midpoint.b < end.b)
    #expect(midpoint.g < start.g && midpoint.g > end.g)
  }

  @Test func textOverlayIsAbsentOutsideItsRange() throws {
    let output = try render(instruction(textOverlays: [bluePillOverlay(start: 0.5, end: 1.0)]), at: 1.5)

    expectScreen(try pixel(output, x: Self.width / 2, y: Self.height / 2))
  }

  @Test func imageOverlayCoversTheCentre() throws {
    let output = try render(instruction(imageOverlays: [blueImageOverlay()]), at: 1.5)

    expectPill(try pixel(output, x: Self.width / 2, y: Self.height / 2))
    expectBackground(try pixel(output, x: 1, y: 1))
  }

  @Test func imageOverlayIsAbsentAtTransitionProgressZero() throws {
    let output = try render(instruction(imageOverlays: [blueImageOverlay()]), at: 0)

    expectScreen(try pixel(output, x: Self.width / 2, y: Self.height / 2))
  }

  @Test func imageOverlayFadeAtHalfProgressBlendsWithScreen() throws {
    let overlay = try blueImageOverlay()
    let start = try pixel(try render(instruction(imageOverlays: [overlay]), at: 0), x: Self.width / 2, y: Self.height / 2)
    let midpoint = try pixel(try render(instruction(imageOverlays: [overlay]), at: 0.5), x: Self.width / 2, y: Self.height / 2)
    let end = try pixel(try render(instruction(imageOverlays: [overlay]), at: 1), x: Self.width / 2, y: Self.height / 2)

    #expect(midpoint.b > start.b && midpoint.b < end.b)
    #expect(midpoint.g < start.g && midpoint.g > end.g)
  }

  @Test func imageOverlayIsAbsentOutsideItsRange() throws {
    let output = try render(instruction(imageOverlays: [blueImageOverlay(start: 0.5, end: 1)]), at: 1.5)

    expectScreen(try pixel(output, x: Self.width / 2, y: Self.height / 2))
  }
}
