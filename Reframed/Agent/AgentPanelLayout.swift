import Foundation

enum AgentPanelLayout {
  static let collapsedWidth: CGFloat = 40
  static let defaultWidth: CGFloat = 320
  static let minimumWidth: CGFloat = 260
  static let maximumWidth: CGFloat = 480

  static func clamp(_ width: CGFloat) -> CGFloat {
    min(maximumWidth, max(minimumWidth, width))
  }

  static func visibleWidth(collapsed: Bool, expandedWidth: CGFloat) -> CGFloat {
    collapsed ? collapsedWidth : clamp(expandedWidth)
  }
}
