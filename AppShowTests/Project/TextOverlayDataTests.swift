import Foundation
import Testing

@testable import AppShow

struct TextOverlayDataTests {
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

  private func decode(_ json: String) throws -> TextOverlayData {
    try decoder().decode(TextOverlayData.self, from: Data(json.utf8))
  }

  @Test func defaultsFillEveryOptionalField() throws {
    let overlay = try decode(#"{"startSeconds": 1, "endSeconds": 4}"#)
    #expect(overlay.startSeconds == 1)
    #expect(overlay.endSeconds == 4)
    #expect(overlay.text == "Title")
    #expect(overlay.fontSize == 0.06)
    #expect(overlay.fontWeight == .bold)
    #expect(overlay.textColor == CodableColor(r: 1, g: 1, b: 1))
    #expect(overlay.showBackground == true)
    #expect(overlay.backgroundColor == CodableColor(r: 0, g: 0, b: 0))
    #expect(overlay.backgroundOpacity == 0.6)
    #expect(overlay.cornerRadius == 0.25)
    #expect(overlay.position == .center)
    #expect(overlay.offsetX == 0)
    #expect(overlay.offsetY == 0)
    #expect(overlay.entryTransition == .fade)
    #expect(overlay.entryTransitionDuration == 0.3)
    #expect(overlay.exitTransition == .fade)
    #expect(overlay.exitTransitionDuration == 0.3)
  }

  @Test func roundTripPreservesEveryField() throws {
    let original = TextOverlayData(
      id: ProjectFixtures.fixedUUID(7),
      startSeconds: 0.5,
      endSeconds: 3.25,
      text: "Step 1\nOpen Settings",
      fontSize: 0.09,
      fontWeight: .medium,
      textColor: CodableColor(r: 0.1, g: 0.2, b: 0.3, a: 0.9),
      showBackground: false,
      backgroundColor: CodableColor(r: 0.4, g: 0.5, b: 0.6, a: 1),
      backgroundOpacity: 0.35,
      cornerRadius: 0.5,
      position: .bottomRight,
      offsetX: -0.1,
      offsetY: 0.2,
      entryTransition: .slide,
      entryTransitionDuration: 0.45,
      exitTransition: .none,
      exitTransitionDuration: 0.15
    )
    let data = try encoder().encode(original)
    let decoded = try decoder().decode(TextOverlayData.self, from: data)
    #expect(decoded == original)
  }

  @Test func unknownPositionAndWeightFallBackToDefaults() throws {
    let overlay = try decode(
      #"{"startSeconds": 0, "endSeconds": 1, "position": "sideways", "fontWeight": "heavy", "entryTransition": "wipe"}"#
    )
    #expect(overlay.position == .center)
    #expect(overlay.fontWeight == .bold)
    #expect(overlay.entryTransition == .fade)
  }

  @Test func editorStateWithoutOverlaysDecodesToNil() throws {
    let legacy = try decoder().decode(
      ProjectMetadata.self,
      from: Data(ProjectFixtures.legacyV1ProjectJSON().utf8)
    )
    #expect(try #require(legacy.editorState).textOverlays == nil)

    let withOverlay = try decoder().decode(
      ProjectMetadata.self,
      from: Data(
        ProjectFixtures.legacyV1ProjectJSON(
          editorStateExtras: #""textOverlays": [{ "startSeconds": 0.25, "endSeconds": 1.5, "text": "Hi" }]"#
        ).utf8
      )
    )
    let overlays = try #require(withOverlay.editorState?.textOverlays)
    #expect(overlays.count == 1)
    #expect(overlays[0].text == "Hi")
    #expect(overlays[0].startSeconds == 0.25)
    #expect(overlays[0].endSeconds == 1.5)
  }

  @Test(arguments: TextOverlayPosition.allCases) func everyPositionHasALabel(position: TextOverlayPosition) {
    #expect(!position.label.isEmpty)
  }
}
