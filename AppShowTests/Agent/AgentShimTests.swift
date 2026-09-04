import Foundation
import Testing

@testable import AppShow

@MainActor
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["REFRAMED_RUN_SHIM_TESTS"] == "1"))
struct AgentShimTests {
  @Test func bundledShimInjectsAuthenticationAndListsEditingTools() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let sources = dir.appendingPathComponent("sources", isDirectory: true)
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
      in: dir,
      cleanupTemp: false
    )
    let state = EditorState(project: project)
    await state.setup()
    defer { state.teardown() }
    let controller = AgentBridgeController()
    try await controller.start(editorState: state)
    defer { Task { await controller.stop() } }
    let configuration = try #require(controller.configuration)
    #expect(FileManager.default.isExecutableFile(atPath: configuration.helperURL.path))

    let process = Process()
    process.executableURL = configuration.helperURL
    process.environment = ProcessInfo.processInfo.environment.merging(configuration.processEnvironment) { _, session in session }
    let input = Pipe()
    let output = Pipe()
    let errors = Pipe()
    process.standardInput = input
    process.standardOutput = output
    process.standardError = errors
    try process.run()

    let outputTask = Task.detached {
      var data = Data()
      while data.filter({ $0 == 0x0A }).count < 2 {
        let chunk = output.fileHandleForReading.availableData
        if chunk.isEmpty { break }
        data.append(chunk)
      }
      return data
    }
    let requests = """
      {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"test","version":"1"}}}
      {"jsonrpc":"2.0","method":"notifications/initialized"}
      {"jsonrpc":"2.0","id":2,"method":"tools/list"}

      """
    try input.fileHandleForWriting.write(contentsOf: Data(requests.utf8))
    let responseData = await outputTask.value
    let responses = try responseData.split(separator: 0x0A).map { line -> JSONRPCResponse in
      guard case .response(let response) = try JSONRPCCodec.decode(Data(line)) else {
        throw JSONRPCError.invalidRequest("Expected response")
      }
      return response
    }

    try input.fileHandleForWriting.close()
    let status = await Task.detached {
      process.waitUntilExit()
      return process.terminationStatus
    }.value
    let errorData = errors.fileHandleForReading.readDataToEndOfFile()

    if status != 0 {
      Issue.record("Shim exited with \(status): \(String(decoding: errorData, as: UTF8.self))")
    }
    guard responses.count == 2 else {
      Issue.record("Expected two shim responses, received \(responses.count)")
      return
    }
    #expect(responses[0].id == .number(1))
    #expect(responses[0].error == nil)
    #expect(responses[0].result?["serverInfo"]?["name"] == .string(AgentToolCatalog.serverName))
    #expect(responses[1].id == .number(2))
    let names = Set(responses[1].result?["tools"]?.arrayValue?.compactMap { $0["name"]?.stringValue } ?? [])
    #expect(names.contains("set_trim"))
    #expect(names.contains("set_kept_slices"))
    await controller.stop()
  }
}
