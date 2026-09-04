import Foundation
import Testing

@testable import Reframed

struct ImageOverlayDataTests {
  private func decoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }

  private func encoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return encoder
  }

  private func decode(_ json: String) throws -> ImageOverlayData {
    try decoder().decode(ImageOverlayData.self, from: Data(json.utf8))
  }

  @Test func defaultsFillEveryOptionalField() throws {
    let overlay = try decode(#"{"startSeconds": 1, "endSeconds": 4, "filename": "image-0a1b2c3d.png"}"#)
    #expect(overlay.startSeconds == 1)
    #expect(overlay.endSeconds == 4)
    #expect(overlay.filename == "image-0a1b2c3d.png")
    #expect(overlay.sourceName == "image-0a1b2c3d.png")
    #expect(overlay.displayName == "image-0a1b2c3d.png")
    #expect(overlay.aspectRatio == 1)
    #expect(overlay.width == ImageOverlayData.defaultWidth)
    #expect(overlay.position == .center)
    #expect(overlay.offsetX == 0)
    #expect(overlay.offsetY == 0)
    #expect(overlay.cornerRadius == 0)
    #expect(overlay.opacity == 1)
    #expect(overlay.shadow == 0)
    #expect(overlay.entryTransition == .fade)
    #expect(overlay.entryTransitionDuration == 0.3)
    #expect(overlay.exitTransition == .fade)
    #expect(overlay.exitTransitionDuration == 0.3)
  }

  @Test func roundTripPreservesEveryField() throws {
    let original = ImageOverlayData(
      id: ProjectFixtures.fixedUUID(9),
      startSeconds: 0.5,
      endSeconds: 3.25,
      filename: "image-deadbeef.jpg",
      sourceName: "Screenshot.jpg",
      aspectRatio: 1.5,
      width: 0.45,
      position: .bottomRight,
      offsetX: -0.1,
      offsetY: 0.2,
      cornerRadius: 0.2,
      opacity: 0.75,
      shadow: 40,
      entryTransition: .slide,
      entryTransitionDuration: 0.45,
      exitTransition: .none,
      exitTransitionDuration: 0.15
    )
    let data = try encoder().encode(original)
    let decoded = try decoder().decode(ImageOverlayData.self, from: data)
    #expect(decoded == original)
    #expect(decoded.displayName == "Screenshot.jpg")
  }

  @Test func unknownPositionAndTransitionFallBackToDefaults() throws {
    let overlay = try decode(
      #"{"startSeconds": 0, "endSeconds": 1, "filename": "image-00000000.png", "position": "sideways", "entryTransition": "wipe"}"#
    )
    #expect(overlay.position == .center)
    #expect(overlay.entryTransition == .fade)
  }

  @Test func filenameIsRequired() {
    #expect(throws: (any Error).self) {
      try decode(#"{"startSeconds": 0, "endSeconds": 1}"#)
    }
  }

  @Test func editorStateWithoutImageOverlaysDecodesToNil() throws {
    let legacy = try decoder().decode(
      ProjectMetadata.self,
      from: Data(ProjectFixtures.legacyV1ProjectJSON().utf8)
    )
    #expect(try #require(legacy.editorState).imageOverlays == nil)

    let withOverlay = try decoder().decode(
      ProjectMetadata.self,
      from: Data(
        ProjectFixtures.legacyV1ProjectJSON(
          editorStateExtras:
            #""imageOverlays": [{ "startSeconds": 0.25, "endSeconds": 1.5, "filename": "image-0a1b2c3d.png", "width": 0.2 }]"#
        ).utf8
      )
    )
    let overlays = try #require(withOverlay.editorState?.imageOverlays)
    #expect(overlays.count == 1)
    #expect(overlays[0].filename == "image-0a1b2c3d.png")
    #expect(overlays[0].width == 0.2)
    #expect(overlays[0].startSeconds == 0.25)
    #expect(overlays[0].endSeconds == 1.5)
  }
}
