import CryptoKit
import Foundation
import Testing

@testable import AppShow

struct ImageOverlayImporterTests {
  private func hash8(of url: URL) throws -> String {
    let digest = SHA256.hash(data: try Data(contentsOf: url))
    return digest.map { String(format: "%02x", $0) }.joined().prefix(8).description
  }

  private func bundleFiles(_ dir: URL) throws -> [String] {
    try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasPrefix("image-") }.sorted()
  }

  @Test func importCopiesTheFileUnderItsHashName() throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let bundle = dir.appendingPathComponent("project.frm", isDirectory: true)
    try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
    let source = try ImageFixtures.solidPNG(width: 16, height: 8, in: dir, name: "Logo.PNG")

    let imported = try ImageOverlayImporter.importImage(from: source, into: bundle)

    #expect(imported.filename == "image-\(try hash8(of: source)).png")
    #expect(imported.pixelSize == CGSize(width: 16, height: 8))
    #expect(FileManager.default.fileExists(atPath: bundle.appendingPathComponent(imported.filename).path))
    #expect(try bundleFiles(bundle) == [imported.filename])
    #expect(FileManager.default.fileExists(atPath: source.path))
  }

  @Test func importingTheSameBytesTwiceReusesTheFile() throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let bundle = dir.appendingPathComponent("project.frm", isDirectory: true)
    try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
    let first = try ImageFixtures.solidPNG(in: dir, name: "one.png")
    let second = dir.appendingPathComponent("two.png")
    try FileManager.default.copyItem(at: first, to: second)
    let other = try ImageFixtures.solidPNG(r: 1, g: 0, b: 0, in: dir, name: "red.png")

    let a = try ImageOverlayImporter.importImage(from: first, into: bundle)
    let b = try ImageOverlayImporter.importImage(from: second, into: bundle)
    let c = try ImageOverlayImporter.importImage(from: other, into: bundle)

    #expect(a.filename == b.filename)
    #expect(a.filename != c.filename)
    #expect(try bundleFiles(bundle) == [a.filename, c.filename].sorted())
  }

  @Test func importRejectsAFileThatIsNotAnImage() throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let bundle = dir.appendingPathComponent("project.frm", isDirectory: true)
    try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
    let fake = dir.appendingPathComponent("fake.png")
    try Data("not an image".utf8).write(to: fake)

    #expect(throws: ImageOverlayImporter.ImportError.unreadableImage) {
      try ImageOverlayImporter.importImage(from: fake, into: bundle)
    }
    #expect(try bundleFiles(bundle).isEmpty)
  }

  @Test func importRejectsAnUnsupportedExtension() throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let bundle = dir.appendingPathComponent("project.frm", isDirectory: true)
    try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
    let source = try ImageFixtures.solidPNG(in: dir, name: "logo.bmp")

    #expect(throws: ImageOverlayImporter.ImportError.unsupportedType("bmp")) {
      try ImageOverlayImporter.importImage(from: source, into: bundle)
    }
    #expect(try bundleFiles(bundle).isEmpty)
  }

  @Test func loadImageDecodesTheFirstFrame() throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let source = try ImageFixtures.solidPNG(width: 12, height: 6, in: dir)

    let image = try #require(ImageOverlayImporter.loadImage(at: source))

    #expect(image.width == 12)
    #expect(image.height == 6)
    #expect(ImageOverlayImporter.loadImage(at: dir.appendingPathComponent("missing.png")) == nil)
  }

  @Test func loadImagesDecodesEachDistinctFileOnce() throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let source = try ImageFixtures.solidPNG(width: 12, height: 6, in: dir, name: "image-00000000.png")
    let overlays = [
      ImageOverlayData(startSeconds: 0, endSeconds: 1, filename: source.lastPathComponent),
      ImageOverlayData(startSeconds: 1, endSeconds: 2, filename: source.lastPathComponent),
      ImageOverlayData(startSeconds: 2, endSeconds: 3, filename: "image-ffffffff.png"),
    ]

    let images = ImageOverlayImporter.loadImages(for: overlays, in: dir)

    #expect(images.count == 1)
    #expect(images[source.lastPathComponent]?.width == 12)
    #expect(ImageOverlayImporter.loadImages(for: overlays, in: nil).isEmpty)
  }
}
