import Foundation
import Logging

enum AgentBridgeStatus: Sendable, Equatable {
  case stopped
  case starting
  case ready
  case failed(String)
}

@MainActor
@Observable
final class AgentBridgeController {
  private(set) var status: AgentBridgeStatus = .stopped
  private(set) var configuration: AgentSessionConfig?
  private var server: AgentBridgeServer?
  private let logger = Logger(label: "eu.jankuri.reframed.agent-bridge-controller")

  static var bundledHelperURL: URL {
    Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/appshow-mcp")
  }

  func start(editorState: EditorState, helperURL: URL = bundledHelperURL) async throws {
    guard server == nil else { return }
    guard let project = editorState.project else {
      throw AgentToolError.failed("An open project is required to start editor tools")
    }
    status = .starting
    let workspace = try AgentWorkspace.create(forBundle: project.bundleURL)
    let dispatcher = AgentToolDispatcher(
      editorState: editorState,
      framesDirectory: workspace.framesDirectory,
      workspaceDirectory: workspace.directory,
      handlers: AgentToolCatalog.readOnlyHandlers() + AgentEditingToolCatalog.handlers,
      allowsMutations: true
    )
    let bridge = AgentBridgeServer(socketURL: workspace.socketURL, token: workspace.token, dispatcher: dispatcher)
    do {
      try await bridge.start()
      let configuration = AgentSessionConfig(workspace: workspace, helperURL: helperURL)
      try configuration.writeClaudeMCPConfig()
      server = bridge
      self.configuration = configuration
      status = .ready
    } catch {
      await bridge.stop()
      workspace.close()
      configuration = nil
      status = .failed(error.localizedDescription)
      logger.error("Agent bridge failed to start: \(error.localizedDescription)")
      throw error
    }
  }

  func stop() async {
    let bridge = server
    let workspace = configuration?.workspace
    server = nil
    configuration = nil
    await bridge?.stop()
    workspace?.close()
    status = .stopped
  }
}
