import CoreGraphics
import Foundation

struct BlurRegionData: Codable, Sendable, Identifiable, Equatable {
  static let defaultLength: Double = 3
  static let minimumLength: Double = 0.05
  static let defaultRadius: CGFloat = 18

  var id: UUID = UUID()
  var startSeconds: Double
  var endSeconds: Double
  var x: CGFloat = 0.3
  var y: CGFloat = 0.4
  var width: CGFloat = 0.4
  var height: CGFloat = 0.2
  var radius: CGFloat = defaultRadius

  var rect: CGRect {
    CGRect(x: x, y: y, width: width, height: height)
  }

  func normalized() -> BlurRegionData {
    var result = self
    result.x = min(0.99, max(0, x))
    result.y = min(0.99, max(0, y))
    result.width = min(1 - result.x, max(0.01, width))
    result.height = min(1 - result.y, max(0.01, height))
    result.radius = min(100, max(0, radius))
    return result
  }
}

extension BlurRegionData {
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decodeOrDefault(.id, UUID())
    startSeconds = try c.decode(Double.self, forKey: .startSeconds)
    endSeconds = try c.decode(Double.self, forKey: .endSeconds)
    x = try c.decodeOrDefault(.x, 0.3)
    y = try c.decodeOrDefault(.y, 0.4)
    width = try c.decodeOrDefault(.width, 0.4)
    height = try c.decodeOrDefault(.height, 0.2)
    radius = try c.decodeOrDefault(.radius, Self.defaultRadius)
  }
}
