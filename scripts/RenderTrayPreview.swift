import AppKit

@main
struct RenderTrayPreview {
  @MainActor static func main() throws {
    _ = NSApplication.shared
    let states: [(String, MenuBarIcon.State)] = [
      ("Ready", .idle), ("Select", .selecting), ("Countdown", .countdown), ("Record", .recording), ("Pause", .paused),
      ("Process", .processing), ("Pulse", .processingPulse), ("Edit", .editing),
    ]
    let width = 1000
    let height = 480
    let bitmap = NSBitmapImageRep(
      bitmapDataPlanes: nil,
      pixelsWide: width,
      pixelsHigh: height,
      bitsPerSample: 8,
      samplesPerPixel: 4,
      hasAlpha: true,
      isPlanar: false,
      colorSpaceName: .deviceRGB,
      bytesPerRow: 0,
      bitsPerPixel: 0
    )!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    for row in 0..<4 {
      let dark = row >= 2
      let scale: CGFloat = row % 2 == 0 ? 1 : 2
      let baseY = CGFloat(3 - row) * 120
      (dark ? NSColor(calibratedWhite: 0.12, alpha: 1) : NSColor(calibratedWhite: 0.95, alpha: 1)).setFill()
      NSRect(x: 0, y: baseY, width: CGFloat(width), height: 120).fill()
      let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 12), .foregroundColor: dark ? NSColor.white : NSColor.black,
      ]
      ("\(dark ? "Dark" : "Light") · \(Int(scale))× native pixels" as NSString).draw(
        at: NSPoint(x: 20, y: baseY + 91),
        withAttributes: attributes
      )
      for (column, state) in states.enumerated() {
        let x = CGFloat(column) * 120 + 32
        let pixels = Int(18 * scale)
        let tile = NSBitmapImageRep(
          bitmapDataPlanes: nil,
          pixelsWide: pixels,
          pixelsHigh: pixels,
          bitsPerSample: 8,
          samplesPerPixel: 4,
          hasAlpha: true,
          isPlanar: false,
          colorSpaceName: .deviceRGB,
          bytesPerRow: 0,
          bitsPerPixel: 0
        )!
        let tileContext = NSGraphicsContext(bitmapImageRep: tile)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = tileContext
        tileContext.cgContext.clear(CGRect(x: 0, y: 0, width: pixels, height: pixels))
        tileContext.cgContext.scaleBy(x: scale, y: scale)
        MenuBarIcon.makeImage(for: state.1).draw(in: NSRect(x: 0, y: 0, width: 18, height: 18))
        tileContext.cgContext.setBlendMode(.sourceIn)
        tileContext.cgContext.setFillColor((dark ? NSColor.white : NSColor.black).cgColor)
        tileContext.cgContext.fill(CGRect(x: 0, y: 0, width: 18, height: 18))
        NSGraphicsContext.restoreGraphicsState()
        NSImage(cgImage: tile.cgImage!, size: NSSize(width: 18, height: 18)).draw(
          in: NSRect(x: x, y: baseY + 35, width: 18 * scale, height: 18 * scale),
          from: .zero,
          operation: .sourceOver,
          fraction: 1
        )
        (state.0 as NSString).draw(at: NSPoint(x: x, y: baseY + 10), withAttributes: attributes)
      }
    }
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
  }
}
