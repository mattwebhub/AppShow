import CoreGraphics
import Foundation

enum TextOverlayPosition: String, Codable, Sendable, CaseIterable, Identifiable {
  case topLeft, top, topRight, center, bottomLeft, bottom, bottomRight

  var id: String { rawValue }

  var label: String {
    switch self {
    case .topLeft: "Top Left"
    case .top: "Top"
    case .topRight: "Top Right"
    case .center: "Center"
    case .bottomLeft: "Bottom Left"
    case .bottom: "Bottom"
    case .bottomRight: "Bottom Right"
    }
  }

  var anchorX: CGFloat {
    switch self {
    case .topLeft, .bottomLeft: 0
    case .top, .center, .bottom: 0.5
    case .topRight, .bottomRight: 1
    }
  }

  var anchorY: CGFloat {
    switch self {
    case .topLeft, .top, .topRight: 0
    case .center: 0.5
    case .bottomLeft, .bottom, .bottomRight: 1
    }
  }
}

struct TextOverlayData: Codable, Sendable, Identifiable, Equatable {
  static let defaultLength: Double = 3
  static let minimumLength: Double = 0.05

  var id: UUID = UUID()
  var startSeconds: Double
  var endSeconds: Double
  var text: String = "Title"
  var fontSize: CGFloat = 0.06
  var fontWeight: CaptionFontWeight = .bold
  var textColor: CodableColor = CodableColor(r: 1, g: 1, b: 1)
  var showBackground: Bool = true
  var backgroundColor: CodableColor = CodableColor(r: 0, g: 0, b: 0)
  var backgroundOpacity: CGFloat = 0.6
  var cornerRadius: CGFloat = 0.25
  var position: TextOverlayPosition = .center
  var offsetX: CGFloat = 0
  var offsetY: CGFloat = 0
  var entryTransition: RegionTransitionType = .fade
  var entryTransitionDuration: Double = 0.3
  var exitTransition: RegionTransitionType = .fade
  var exitTransitionDuration: Double = 0.3
}

extension TextOverlayData {
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decodeOrDefault(.id, UUID())
    startSeconds = try c.decode(Double.self, forKey: .startSeconds)
    endSeconds = try c.decode(Double.self, forKey: .endSeconds)
    text = try c.decodeOrDefault(.text, "Title")
    fontSize = try c.decodeOrDefault(.fontSize, 0.06)
    fontWeight = (try? c.decodeIfPresent(CaptionFontWeight.self, forKey: .fontWeight)) ?? .bold
    textColor = try c.decodeOrDefault(.textColor, CodableColor(r: 1, g: 1, b: 1))
    showBackground = try c.decodeOrDefault(.showBackground, true)
    backgroundColor = try c.decodeOrDefault(.backgroundColor, CodableColor(r: 0, g: 0, b: 0))
    backgroundOpacity = try c.decodeOrDefault(.backgroundOpacity, 0.6)
    cornerRadius = try c.decodeOrDefault(.cornerRadius, 0.25)
    position = (try? c.decodeIfPresent(TextOverlayPosition.self, forKey: .position)) ?? .center
    offsetX = try c.decodeOrDefault(.offsetX, 0)
    offsetY = try c.decodeOrDefault(.offsetY, 0)
    entryTransition = (try? c.decodeIfPresent(RegionTransitionType.self, forKey: .entryTransition)) ?? .fade
    entryTransitionDuration = try c.decodeOrDefault(.entryTransitionDuration, 0.3)
    exitTransition = (try? c.decodeIfPresent(RegionTransitionType.self, forKey: .exitTransition)) ?? .fade
    exitTransitionDuration = try c.decodeOrDefault(.exitTransitionDuration, 0.3)
  }
}
