import Foundation
import Network
import Testing

@testable import Reframed

actor BridgeTestClient {
  private let connection: NWConnection
  private var buffer = JSONRPCLineBuffer()
  private var lines: [Data] = []
  private var waiters: [CheckedContinuation<Data?, Never>] = []
  private var closed = false

  init(path: String) {
    connection = NWConnection(to: .unix(path: path), using: .tcp)
  }

  func connect() async throws {
    let connection = connection
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
      let box = ContinuationBox(continuation)
      connection.stateUpdateHandler = { state in
        switch state {
        case .ready: box.resume(.success(()))
        case .failed(let error): box.resume(.failure(error))
        case .waiting(let error):
          box.resume(.failure(error))
          connection.cancel()
        case .cancelled: box.resume(.failure(CancellationError()))
        default: break
        }
      }
      connection.start(queue: DispatchQueue(label: "bridge-test-client"))
    }
    receiveLoop()
  }

  func send(_ request: JSONRPCRequest) async throws {
    let data = try JSONRPCCodec.encode(request)
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
      connection.send(
        content: data,
        completion: .contentProcessed { error in
          if let error { continuation.resume(throwing: error) } else { continuation.resume() }
        }
      )
    }
  }

  func sendRaw(_ text: String) async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
      connection.send(
        content: Data(text.utf8),
        completion: .contentProcessed { error in
          if let error { continuation.resume(throwing: error) } else { continuation.resume() }
        }
      )
    }
  }

  func nextLine(timeout: Duration = .seconds(5)) async -> Data? {
    if !lines.isEmpty {
      return lines.removeFirst()
    }
    if closed {
      return nil
    }
    return await withTaskGroup(of: Data?.self) { group in
      group.addTask { await self.waitForLine() }
      group.addTask {
        try? await Task.sleep(for: timeout)
        return nil
      }
      let first = await group.next() ?? nil
      group.cancelAll()
      return first
    }
  }

  func request(_ request: JSONRPCRequest) async throws -> JSONRPCResponse {
    try await send(request)
    while let line = await nextLine() {
      if case .response(let response) = try JSONRPCCodec.decode(line), response.id == request.id {
        return response
      }
    }
    throw CancellationError()
  }

  func cancel() {
    connection.cancel()
  }

  private func waitForLine() async -> Data? {
    await withCheckedContinuation { continuation in
      if !lines.isEmpty {
        continuation.resume(returning: lines.removeFirst())
      } else if closed {
        continuation.resume(returning: nil)
      } else {
        waiters.append(continuation)
      }
    }
  }

  private func receiveLoop() {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
      Task { await self.received(data, isComplete: isComplete, failed: error != nil) }
    }
  }

  private func received(_ data: Data?, isComplete: Bool, failed: Bool) {
    if let data {
      for line in buffer.append(data) {
        if let waiter = waiters.first {
          waiters.removeFirst()
          waiter.resume(returning: line)
        } else {
          lines.append(line)
        }
      }
    }
    if isComplete || failed {
      closed = true
      for waiter in waiters {
        waiter.resume(returning: nil)
      }
      waiters.removeAll()
      return
    }
    receiveLoop()
  }
}

private final class ContinuationBox: @unchecked Sendable {
  private let lock = NSLock()
  private var continuation: CheckedContinuation<Void, any Error>?

  init(_ continuation: CheckedContinuation<Void, any Error>) {
    self.continuation = continuation
  }

  func resume(_ result: Result<Void, any Error>) {
    lock.lock()
    let pending = continuation
    continuation = nil
    lock.unlock()
    pending?.resume(with: result)
  }
}

@MainActor
@Suite(.serialized)
struct AgentBridgeServerTests {
  private static let token = String(repeating: "f", count: 64)

  @MainActor
  private struct FakeHandler: AgentToolHandler {
    let definition: AgentToolDefinition
    let sleepFor: Duration?
    let fails: Bool

    func call(arguments: JSONValue, context: AgentToolContext) async throws -> JSONValue {
      if let sleepFor { try await Task.sleep(for: sleepFor) }
      if fails { throw CaptureError.recordingFailed("no frame") }
      return ["ok": true]
    }
  }

  private struct Harness {
    let dir: URL
    let socketDir: URL
    let state: EditorState
    let project: ReframedProject
    let dispatcher: AgentToolDispatcher
    let server: AgentBridgeServer
    let socketURL: URL

    @MainActor
    func tearDown() async {
      await server.stop()
      state.teardown()
      TestPaths.remove(dir)
      TestPaths.remove(socketDir)
    }
  }

  private func makeHarness(timeouts: AgentRPCTimeouts = .default) async throws -> Harness {
    let dir = try TestPaths.makeTemporaryDirectory()
    let sources = dir.appendingPathComponent("sources", isDirectory: true)
    try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)
    let result = try await ProjectFixtures.recordingResult(in: sources, webcam: false, systemAudio: false, microphone: false, cursor: false)
    let project = try ReframedProject.create(from: result, fps: result.fps, captureMode: .entireScreen, in: dir, cleanupTemp: false)
    let state = EditorState(project: project)
    await state.setup()
    let dispatcher = AgentToolDispatcher(editorState: state, framesDirectory: dir.appendingPathComponent("frames"), workspaceDirectory: dir)
    let socketDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("reframed-tests", isDirectory: true)
      .appendingPathComponent(String(UUID().uuidString.prefix(8)), isDirectory: true)
    try FileManager.default.createDirectory(at: socketDir, withIntermediateDirectories: true)
    let socketURL = socketDir.appendingPathComponent("bridge.sock")
    let server = AgentBridgeServer(socketURL: socketURL, token: Self.token, dispatcher: dispatcher, timeouts: timeouts)
    try await server.start()
    return Harness(
      dir: dir,
      socketDir: socketDir,
      state: state,
      project: project,
      dispatcher: dispatcher,
      server: server,
      socketURL: socketURL
    )
  }

  private func client(_ harness: Harness) async throws -> BridgeTestClient {
    let client = BridgeTestClient(path: harness.socketURL.path)
    try await client.connect()
    return client
  }

  private func initialize(_ client: BridgeTestClient, token: String = token, id: Int = 1) async throws -> JSONRPCResponse {
    try await client.request(
      JSONRPCRequest(
        id: .number(id),
        method: "initialize",
        params: [
          "protocolVersion": .string(AgentToolCatalog.protocolVersion),
          "capabilities": [:],
          "clientInfo": ["name": "test", "version": "0"],
          "token": .string(token),
        ]
      )
    )
  }

  @Test func wrongTokenIsRejectedAndTheConnectionCloses() async throws {
    let harness = try await makeHarness()
    let client = try await client(harness)

    let response = try await initialize(client, token: "bad")

    #expect(response.error?.code == -32001)
    #expect(response.error?.data?["code"] == "UNAUTHORIZED")
    #expect(await client.nextLine(timeout: .seconds(3)) == nil)
    await harness.tearDown()
  }

  @Test func requestsBeforeInitializeAreRefused() async throws {
    let harness = try await makeHarness()
    let client = try await client(harness)

    let response = try await client.request(JSONRPCRequest(id: .number(1), method: "tools/list", params: nil))

    #expect(response.error?.code == -32002)
    #expect(response.error?.data?["code"] == "NOT_INITIALIZED")
    await client.cancel()
    await harness.tearDown()
  }

  @Test func rightTokenListsTheCatalogAndCallsTools() async throws {
    let harness = try await makeHarness()
    let client = try await client(harness)

    let initialized = try await initialize(client)
    #expect(initialized.error == nil)
    #expect(initialized.result?["serverInfo"]?["name"] == "reframed")
    #expect(initialized.result?["serverInfo"]?["version"]?.stringValue?.isEmpty == false)
    #expect(initialized.result?["protocolVersion"] == .string(AgentToolCatalog.protocolVersion))
    #expect(initialized.result?["capabilities"]?["tools"] != nil)
    try await client.send(JSONRPCRequest(id: nil, method: "notifications/initialized", params: nil))

    let ping = try await client.request(JSONRPCRequest(id: .string("p"), method: "ping", params: nil))
    #expect(ping.result == [:])

    let list = try await client.request(JSONRPCRequest(id: .number(2), method: "tools/list", params: nil))
    let names = Set(list.result?["tools"]?.arrayValue?.compactMap { $0["name"]?.stringValue } ?? [])
    #expect(names == Set(AgentToolCatalog.available.map(\.name)))

    let summary = try await client.request(
      JSONRPCRequest(id: .number(3), method: "tools/call", params: ["name": "get_project_summary", "arguments": [:]])
    )
    #expect(summary.error == nil)
    #expect(summary.result?["isError"] == false)
    #expect(summary.result?["structuredContent"]?["name"] == .string(harness.project.name))
    #expect(summary.result?["structuredContent"]?["duration"] == 2)
    #expect(summary.result?["content"]?[0]?["type"] == "text")
    let text = try #require(summary.result?["content"]?[0]?["text"]?.stringValue)
    #expect(try JSONValue.parse(Data(text.utf8))["fps"] == 30)

    let unknown = try await client.request(
      JSONRPCRequest(id: .number(4), method: "tools/call", params: ["name": "nope", "arguments": [:]])
    )
    #expect(unknown.error?.code == -32601)
    #expect(unknown.error?.data?["code"] == "UNKNOWN_TOOL")
    let missingName = try await client.request(JSONRPCRequest(id: .number(5), method: "tools/call", params: ["arguments": [:]]))
    #expect(missingName.error?.code == -32602)
    let badArguments = try await client.request(
      JSONRPCRequest(id: .number(6), method: "tools/call", params: ["name": "get_timeline", "arguments": ["detail": "x"]])
    )
    #expect(badArguments.error?.code == -32602)
    #expect(badArguments.error?.data?["code"] == "TOOL_ARGUMENTS_INVALID")
    let pending = try await client.request(
      JSONRPCRequest(id: .number(7), method: "tools/call", params: ["name": "get_silences", "arguments": [:]])
    )
    #expect(pending.error?.code == -32004)
    let unknownMethod = try await client.request(JSONRPCRequest(id: .number(8), method: "resources/list", params: nil))
    #expect(unknownMethod.error?.code == -32601)
    #expect(harness.state.history.entries.count == 1)
    await client.cancel()
    await harness.tearDown()
  }

  @Test func toolFailuresAndParseErrorsAreReportedWithoutClosing() async throws {
    let harness = try await makeHarness()
    let broken = AgentToolDefinition(
      name: "broken_test",
      description: "test double",
      inputSchema: AgentToolSchema.object([:]),
      mutating: false
    )
    harness.dispatcher.register(FakeHandler(definition: broken, sleepFor: nil, fails: true))
    let client = try await client(harness)
    _ = try await initialize(client)

    let failure = try await client.request(JSONRPCRequest(id: .number(2), method: "tools/call", params: ["name": "broken_test"]))
    #expect(failure.error == nil)
    #expect(failure.result?["isError"] == true)
    #expect(failure.result?["content"]?[0]?["text"]?.stringValue?.contains("no frame") == true)

    try await client.sendRaw("{oops\n")
    let parse = try #require(await client.nextLine())
    guard case .response(let parseResponse) = try JSONRPCCodec.decode(parse) else {
      Issue.record("expected a response")
      return
    }
    #expect(parseResponse.id == nil)
    #expect(parseResponse.error?.code == JSONRPCError.parseErrorCode)

    let ping = try await client.request(JSONRPCRequest(id: .number(3), method: "ping", params: nil))
    #expect(ping.result == [:])
    await client.cancel()
    await harness.tearDown()
  }

  @Test func slowToolTimesOutWithStructuredErrorAndTheServerKeepsAnswering() async throws {
    let harness = try await makeHarness(timeouts: AgentRPCTimeouts(regular: .milliseconds(200), slow: .milliseconds(200)))
    let slow = AgentToolDefinition(name: "slow_test", description: "test double", inputSchema: AgentToolSchema.object([:]), mutating: false)
    harness.dispatcher.register(FakeHandler(definition: slow, sleepFor: .seconds(2), fails: false))
    let client = try await client(harness)
    _ = try await initialize(client)

    let timedOut = try await client.request(JSONRPCRequest(id: .number(2), method: "tools/call", params: ["name": "slow_test"]))
    #expect(timedOut.error?.code == -32005)
    #expect(timedOut.error?.data?["code"] == "TOOL_TIMEOUT")

    let ping = try await client.request(JSONRPCRequest(id: .number(3), method: "ping", params: nil))
    #expect(ping.result == [:])
    await client.cancel()
    await harness.tearDown()
  }

  @Test func stopRemovesTheSocketAndRefusesNewConnections() async throws {
    let harness = try await makeHarness()
    #expect(await harness.server.isListening)
    #expect(FileManager.default.fileExists(atPath: harness.socketURL.path))

    await harness.server.stop()

    #expect(await harness.server.isListening == false)
    #expect(FileManager.default.fileExists(atPath: harness.socketURL.path) == false)
    let client = BridgeTestClient(path: harness.socketURL.path)
    await #expect(throws: (any Error).self) {
      try await client.connect()
    }
    await harness.tearDown()
  }
}
