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

enum AgentProjectWorkspace {
  static func directory(for bundleURL: URL) -> URL {
    AgentWorkspace.directory(forBundle: bundleURL)
  }
}

enum AgentSendPreparation {
  static func workspace(project: URL, configuration: AgentSessionConfig?, sandboxed: Bool = AppDistribution.isStore) throws -> URL {
    guard !sandboxed || configuration != nil else {
      throw AgentError.launchFailed("Editor tools could not start. Close and reopen this project, then try again.")
    }
    let directory = configuration?.workspace.directory ?? AgentProjectWorkspace.directory(for: project)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }
}
