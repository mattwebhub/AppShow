import AppKit
import Testing

@testable import AppShow

@MainActor
struct MenuBarIconTests {
  @Test func bundledBrushstrokeIsATransparentTemplate() throws {
    let image = try #require(NSImage(named: "MenuBarMark"))
    #expect(image.isTemplate)
    let bitmap = try render(image)
    let opaque = (0..<72).flatMap { y in (0..<72).map { x in bitmap.colorAt(x: x, y: y)!.alphaComponent } }
    #expect(opaque.filter { $0 > 0.5 }.count > 700)
    #expect(opaque.filter { $0 < 0.01 }.count > 1800)
    for (x, y) in [(0, 0), (71, 0), (0, 71), (71, 71), (14, 57)] {
      #expect(try #require(bitmap.colorAt(x: x, y: y)).alphaComponent < 0.01)
    }
  }

  @Test func idleUsesTheBundledBrandShape() throws {
    let brand = try #require(NSImage(named: "MenuBarMark"))
    #expect(
      try render(MenuBarIcon.image).representation(using: .png, properties: [:])
        == render(brand).representation(using: .png, properties: [:])
    )
  }

  @Test func activityRemainsVisibleWithinTheMenuBarFootprint() throws {
    let states: [MenuBarIcon.State] = [.idle, .selecting, .countdown, .recording, .paused, .processing, .processingPulse, .editing]
    let images = states.map { MenuBarIcon.makeImage(for: $0) }
    for image in images {
      #expect(image.size == NSSize(width: 18, height: 18))
      #expect(image.isTemplate)
    }
    let pixels = try images.map { try #require(render($0).representation(using: .png, properties: [:])) }
    #expect(pixels[0] == pixels[5])
    #expect(Set([pixels[0], pixels[1], pixels[2], pixels[3], pixels[4], pixels[7]]).count == 6)
    #expect(pixels[5] != pixels[6])
  }

  private func render(_ image: NSImage) throws -> NSBitmapImageRep {
    let bitmap = try #require(
      NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: 72,
        pixelsHigh: 72,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
      )
    )
    let context = try #require(NSGraphicsContext(bitmapImageRep: bitmap))
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: 4, y: 4)
    image.draw(in: NSRect(x: 0, y: 0, width: 18, height: 18))
    return bitmap
  }
}
