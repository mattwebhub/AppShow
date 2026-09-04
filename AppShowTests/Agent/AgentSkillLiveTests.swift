import Foundation
import Testing

@testable import AppShow

@MainActor
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["REFRAMED_RUN_AGENT_SKILL_E2E"] == "1"))
struct AgentSkillLiveTests {
  private struct ClaudeModelOverrideProvider: AgentProvider {
    let model: String
    private let base = ClaudeCodeProvider()

    var id: AgentProviderKind { base.id }
    var executableNames: [String] { base.executableNames }
    var environmentKeys: [String] { base.environmentKeys }

    func arguments(for turn: AgentTurn) -> [String] {
      base.arguments(for: turn) + ["--model", model]
    }

    func standardInput(for turn: AgentTurn) -> String? {
      base.standardInput(for: turn)
    }

    func parse(line: String) -> [AgentEvent] {
      base.parse(line: line)
    }
  }

  @Test(arguments: AgentProviderKind.allCases)
  func providerInvokesBundledTitleSkillThroughTheLiveBridge(kind: AgentProviderKind) async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let sources = directory.appendingPathComponent("sources", isDirectory: true)
    try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)
    let result = try await ProjectFixtures.recordingResult(
      in: sources,
      webcam: false,
      systemAudio: false,
      microphone: false,
      cursor: false
    )
    let project = try AppShowProject.create(
      from: result,
      fps: result.fps,
      captureMode: .entireScreen,
      in: directory,
      cleanupTemp: false
    )
    let state = EditorState(project: project)
    await state.setup()
    defer { state.teardown() }
    let controller = AgentBridgeController()
    try await controller.start(editorState: state)
    let configuration = try #require(controller.configuration)
    let provider = provider(for: kind)
    let toolchain = AgentToolchain.standard()
    let executable = try #require(await toolchain.resolve(provider.executableNames))
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    var environment = AgentEnvironment.scrubbed(
      path: await toolchain.searchPath(),
      home: home,
      forwarding: provider.environmentKeys
    )
    environment.merge(configuration.processEnvironment) { _, configured in configured }
    let title = "AppShow skill check \(kind.rawValue)"
    let invocation = kind == .codex ? "Invoke $add-title-cards." : "/add-title-cards"
    let session = AgentSession(
      provider: provider,
      executable: executable,
      workingDirectory: configuration.workspace.directory,
      environment: environment,
      configuration: configuration
    )

    let events: [AgentEvent]
    do {
      events = try await collect(
        from: session,
        prompt:
          "\(invocation) Add exactly one opening title with the exact text \"\(title)\" from 0.2 to 1.2 seconds. Inspect the project and validate the result as the skill directs. Make no other mutations.",
        timeout: .seconds(180)
      )
    } catch {
      await controller.stop()
      throw error
    }
    await controller.stop()

    #expect(state.textOverlays.map(\.text) == [title])
    #expect(
      events.contains { event in
        guard case .toolCallStarted(_, let name, _) = event else { return false }
        return name.contains("add_text")
      }
    )
    #expect(
      events.contains { event in
        guard case .turnCompleted(let result) = event else { return false }
        return !result.isError
      }
    )
  }

  private func provider(for kind: AgentProviderKind) -> any AgentProvider {
    guard
      kind == .claudeCode,
      let model = ProcessInfo.processInfo.environment["REFRAMED_AGENT_CLAUDE_MODEL"],
      !model.isEmpty
    else { return kind.makeProvider() }
    return ClaudeModelOverrideProvider(model: model)
  }

  private func collect(
    from session: AgentSession,
    prompt: String,
    timeout: Duration
  ) async throws -> [AgentEvent] {
    try await withThrowingTaskGroup(of: [AgentEvent].self) { group in
      group.addTask {
        var events: [AgentEvent] = []
        for try await event in await session.send(prompt) {
          events.append(event)
        }
        return events
      }
      group.addTask {
        try await Task.sleep(for: timeout)
        await session.cancel()
        throw AgentToolError.failed("Live provider skill invocation timed out")
      }
      let events = try await group.next() ?? []
      group.cancelAll()
      return events
    }
  }
}
