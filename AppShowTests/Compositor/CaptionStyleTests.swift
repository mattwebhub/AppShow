import AppKit
import CoreMedia
import Testing

@testable import AppShow

struct CaptionStyleTests {
  @Test func legacySettingsDefaultToSystemFontAndKeepColors() throws {
    let data = Data(#"{"textColor":{"r":1,"g":0,"b":0,"a":1}}"#.utf8)
    let settings = try JSONDecoder().decode(CaptionSettingsData.self, from: data)
    #expect(settings.fontFamily == "System")
    #expect(settings.textColor == CodableColor(r: 1, g: 0, b: 0))
  }

  @Test func fontAndColorsRoundTrip() throws {
    let settings = CaptionSettingsData(
      fontFamily: "Georgia",
      textColor: CodableColor(r: 0, g: 1, b: 0),
      backgroundColor: CodableColor(r: 1, g: 0, b: 0),
      backgroundOpacity: 0.4
    )
    let restored = try JSONDecoder().decode(CaptionSettingsData.self, from: JSONEncoder().encode(settings))
    #expect(restored == settings)
  }

  @Test func fontResolverHonorsFamilyWeightAndFallsBack() {
    let regular = CaptionFont.resolve(family: "Georgia", size: 40, weight: .regular)
    let bold = CaptionFont.resolve(family: "Georgia", size: 40, weight: .bold)
    #expect(regular.familyName == "Georgia")
    #expect(bold.familyName == "Georgia")
    #expect(regular.fontName != bold.fontName)
    #expect(bold.pointSize == 40)
    let missing = CaptionFont.resolve(family: "AppShow nonexistent font", size: 40, weight: .bold)
    #expect(missing == NSFont.systemFont(ofSize: 40, weight: .bold))
  }

  @Test func captionBoundsUseSelectedFont() {
    let system = CaptionLayout.measureText("Wide WWW narrow iii", scaledFontSize: 40, fontWeight: .regular, maxTextWidth: 800)
    let serif = CaptionLayout.measureText(
      "Wide WWW narrow iii",
      scaledFontSize: 40,
      fontFamily: "Georgia",
      fontWeight: .regular,
      maxTextWidth: 800
    )
    #expect(system.width != serif.width)
  }
  @Test func renderedCaptionsUseFamilyAndBothColors() throws {
    let serif = try render(family: "Georgia", showBackground: true)
    let system = try render(family: "System", showBackground: true)
    #expect(serif != system)
    let pixels = stride(from: 0, to: serif.count, by: 4)
    #expect(pixels.contains { serif[$0] > 240 && serif[$0 + 2] < 15 })
    #expect(pixels.contains { serif[$0 + 2] > 240 && serif[$0] < 15 })
    let textOnly = try render(family: "Georgia", showBackground: false)
    #expect(!pixels.contains { textOnly[$0 + 2] > 240 && textOnly[$0] < 15 })
    #expect(pixels.contains { textOnly[$0] > 240 && textOnly[$0 + 2] < 15 })
  }

  private func render(family: String, showBackground: Bool) throws -> [UInt8] {
    let width = 640
    let height = 360
    let context = try #require(
      CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
    )
    let canvas = CGRect(x: 0, y: 0, width: width, height: height)
    let instruction = CompositionInstruction(
      timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 2, preferredTimescale: 600)),
      screenTrackID: 1,
      webcamTrackID: nil,
      cameraRect: nil,
      cameraCornerRadius: 0,
      outputSize: canvas.size,
      captionScreenWidth: CGFloat(width),
      captionSegments: [CaptionSegment(startSeconds: 0, endSeconds: 2, text: "Hello captions")],
      captionsEnabled: true,
      captionFontSize: 40,
      captionFontFamily: family,
      captionTextColor: CodableColor(r: 1, g: 0, b: 0),
      captionBackgroundColor: CodableColor(r: 0, g: 0, b: 1),
      captionBackgroundOpacity: 1,
      captionShowBackground: showBackground
    )
    FrameRenderer.drawCaptions(
      in: context,
      videoRect: canvas,
      canvasRect: canvas,
      instruction: instruction,
      compositionTime: .zero
    )
    let data = try #require(context.data).assumingMemoryBound(to: UInt8.self)
    return Array(UnsafeBufferPointer(start: data, count: width * height * 4))
  }

}
