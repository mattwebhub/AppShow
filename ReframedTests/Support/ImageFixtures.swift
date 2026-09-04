import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImageFixtures {
  struct FixtureError: Error {}

  static func solidImage(width: Int, height: Int, r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 1) throws -> CGImage {
    guard
      let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
    else { throw FixtureError() }
    context.setFillColor(CGColor(red: r, green: g, blue: b, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    guard let image = context.makeImage() else { throw FixtureError() }
    return image
  }

  @discardableResult
  static func solidPNG(
    width: Int = 16,
    height: Int = 8,
    r: CGFloat = 0,
    g: CGFloat = 0,
    b: CGFloat = 1,
    in directory: URL,
    name: String = "logo.png"
  ) throws -> URL {
    let url = directory.appendingPathComponent(name)
    let image = try solidImage(width: width, height: height, r: r, g: g, b: b)
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { throw FixtureError() }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw FixtureError() }
    return url
  }
}
