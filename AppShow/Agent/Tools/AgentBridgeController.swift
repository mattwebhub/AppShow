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
  private var relocationTask: Task<Void, Never>?
  private let logger = Logger(label: "com.mattwebhub.appshow.agent-bridge-controller")

  static var bundledHelperURL: URL {
    Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/appshow-mcp")
  }

  func start(editorState: EditorState, helperURL: URL = bundledHelperURL) async throws {
    guard !AppDistribution.isStore else { throw AgentToolError.failed("The external assistant is unavailable in this build") }
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
      editorState.agentTranscript.onTurnEnd = { [weak self] in
        await self?.server?.cancelRequests()
      }
    } catch {
      await bridge.stop()
      workspace.close()
      configuration = nil
      status = .failed(error.localizedDescription)
      logger.error("Agent bridge failed to start: \(error.localizedDescription)")
      throw error
    }
  }

  func relocate(editorState: EditorState) {
    guard let helperURL = configuration?.helperURL else { return }
    status = .starting
    editorState.agentTranscript.cancel()
    relocationTask?.cancel()
    relocationTask = Task { [weak self, weak editorState] in
      guard let self, let editorState else { return }
      await editorState.agentTranscript.waitForTurn()
      guard !Task.isCancelled else { return }
      await self.stopServer()
      guard !Task.isCancelled else { return }
      try? await self.start(editorState: editorState, helperURL: helperURL)
    }
  }

  func stop() async {
    relocationTask?.cancel()
    relocationTask = nil
    await stopServer()
  }

  private func stopServer() async {

    let bridge = server
    let workspace = configuration?.workspace
    server = nil
    configuration = nil
    await bridge?.stop()
    workspace?.close()
    status = .stopped
  }
}
