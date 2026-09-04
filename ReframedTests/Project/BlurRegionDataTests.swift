import Foundation
import Testing

@testable import Reframed

struct BlurRegionDataTests {
  @Test func defaultsAndClampingAreDeterministic() throws {
    let decoded = try JSONDecoder().decode(
      BlurRegionData.self,
      from: Data(#"{"startSeconds":1,"endSeconds":3,"x":0.9,"y":-0.2,"width":0.5,"height":0.4}"#.utf8)
    )

    let normalized = decoded.normalized()

    #expect(normalized.x == 0.9)
    #expect(normalized.y == 0)
    #expect(abs(normalized.width - 0.1) < 0.0001)
    #expect(normalized.height == 0.4)
    #expect(normalized.radius == BlurRegionData.defaultRadius)

    var beyondEdge = decoded
    beyondEdge.x = 2
    beyondEdge.y = 2
    let edge = beyondEdge.normalized()
    #expect(edge.x == 0.99)
    #expect(edge.y == 0.99)
    #expect(abs(edge.width - 0.01) < 0.0001)
    #expect(abs(edge.height - 0.01) < 0.0001)
  }

  @Test func roundTripPreservesEveryField() throws {
    let original = BlurRegionData(
      id: ProjectFixtures.fixedUUID(7),
      startSeconds: 0.5,
      endSeconds: 2.5,
      x: 0.1,
      y: 0.2,
      width: 0.3,
      height: 0.4,
      radius: 24
    )

    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(BlurRegionData.self, from: data)

    #expect(decoded == original)
    #expect(decoded.rect == CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4))
  }

  @Test func legacyProjectHasNoBlurRegions() throws {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let project = try decoder.decode(
      ProjectMetadata.self,
      from: Data(ProjectFixtures.legacyV1ProjectJSON().utf8)
    )

    #expect(try #require(project.editorState).blurRegions == nil)
  }
}
