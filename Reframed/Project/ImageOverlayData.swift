import CoreGraphics
import Foundation

struct ImageOverlayData: Codable, Sendable, Identifiable, Equatable {
  static let defaultLength: Double = 3
  static let minimumLength: Double = 0.05
  static let defaultWidth: CGFloat = 0.3

  var id: UUID = UUID()
  var startSeconds: Double
  var endSeconds: Double
  var filename: String
  var sourceName: String?
  var aspectRatio: CGFloat = 1
  var width: CGFloat = defaultWidth
  var position: TextOverlayPosition = .center
  var offsetX: CGFloat = 0
  var offsetY: CGFloat = 0
  var cornerRadius: CGFloat = 0
  var opacity: CGFloat = 1
  var shadow: CGFloat = 0
  var entryTransition: RegionTransitionType = .fade
  var entryTransitionDuration: Double = 0.3
  var exitTransition: RegionTransitionType = .fade
  var exitTransitionDuration: Double = 0.3

  var displayName: String { sourceName ?? filename }
}

extension ImageOverlayData {
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decodeOrDefault(.id, UUID())
    startSeconds = try c.decode(Double.self, forKey: .startSeconds)
    endSeconds = try c.decode(Double.self, forKey: .endSeconds)
    filename = try c.decode(String.self, forKey: .filename)
    sourceName = try c.decodeOrDefault(.sourceName, filename)
    aspectRatio = try c.decodeOrDefault(.aspectRatio, 1)
    width = try c.decodeOrDefault(.width, Self.defaultWidth)
    position = (try? c.decodeIfPresent(TextOverlayPosition.self, forKey: .position)) ?? .center
    offsetX = try c.decodeOrDefault(.offsetX, 0)
    offsetY = try c.decodeOrDefault(.offsetY, 0)
    cornerRadius = try c.decodeOrDefault(.cornerRadius, 0)
    opacity = try c.decodeOrDefault(.opacity, 1)
    shadow = try c.decodeOrDefault(.shadow, 0)
    entryTransition = (try? c.decodeIfPresent(RegionTransitionType.self, forKey: .entryTransition)) ?? .fade
    entryTransitionDuration = try c.decodeOrDefault(.entryTransitionDuration, 0.3)
    exitTransition = (try? c.decodeIfPresent(RegionTransitionType.self, forKey: .exitTransition)) ?? .fade
    exitTransitionDuration = try c.decodeOrDefault(.exitTransitionDuration, 0.3)
  }
}
