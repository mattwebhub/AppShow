import CoreGraphics
import CryptoKit
import Foundation
import ImageIO

enum ImageOverlayImporter {
  enum ImportError: Error, Equatable {
    case unsupportedType(String)
    case unreadableImage
  }

  struct ImportedImage: Equatable {
    var filename: String
    var pixelSize: CGSize
  }

  private static let supportedExtensions = Set(["png", "jpeg", "jpg", "heic", "tiff", "tif", "gif"])

  static func importImage(from source: URL, into bundle: URL) throws -> ImportedImage {
    let ext = source.pathExtension.lowercased()
    guard supportedExtensions.contains(ext) else { throw ImportError.unsupportedType(ext) }
    guard let image = loadImage(at: source) else { throw ImportError.unreadableImage }
    let data = try Data(contentsOf: source)
    let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined().prefix(8)
    let filename = "image-\(hash).\(ext)"
    let destination = bundle.appendingPathComponent(filename)
    if !FileManager.default.fileExists(atPath: destination.path) {
      try FileManager.default.copyItem(at: source, to: destination)
    }
    return ImportedImage(filename: filename, pixelSize: CGSize(width: image.width, height: image.height))
  }

  static func loadImage(at url: URL) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
  }

  static func loadImages(for overlays: [ImageOverlayData], in directory: URL?) -> [String: CGImage] {
    guard let directory else { return [:] }
    var images: [String: CGImage] = [:]
    for filename in Set(overlays.map(\.filename)) {
      images[filename] = loadImage(at: directory.appendingPathComponent(filename))
    }
    return images
  }
}
