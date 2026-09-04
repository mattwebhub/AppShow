import Foundation

struct AgentRPCTimeouts: Sendable, Equatable {
  var regular: Duration = .seconds(30)
  var slow: Duration = .seconds(600)

  static let `default` = AgentRPCTimeouts()
}

struct AgentRPCOutcome: Sendable, Equatable {
  var reply: JSONRPCResponse?
  var closeAfterReply: Bool

  static let silent = AgentRPCOutcome(reply: nil, closeAfterReply: false)
}

actor AgentRPCSession {
  static let unauthorizedCode = -32001
  static let notInitializedCode = -32002

  private let token: String
  private let dispatcher: AgentToolDispatcher
  private let timeouts: AgentRPCTimeouts
  private let serverVersion: String
  private var initialized = false

  init(
    token: String,
    dispatcher: AgentToolDispatcher,
    timeouts: AgentRPCTimeouts = .default,
    serverVersion: String = AgentRPCSession.bundleVersion
  ) {
    self.token = token
    self.dispatcher = dispatcher
    self.timeouts = timeouts
    self.serverVersion = serverVersion
  }

  static var bundleVersion: String {
    (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0"
  }

  func handle(line: Data) async -> AgentRPCOutcome {
    let message: JSONRPCMessage
    do {
      message = try JSONRPCCodec.decode(line)
    } catch let error as JSONRPCError {
      return AgentRPCOutcome(reply: JSONRPCResponse(id: nil, error: error), closeAfterReply: false)
    } catch {
      return AgentRPCOutcome(reply: JSONRPCResponse(id: nil, error: .internalError(error.localizedDescription)), closeAfterReply: false)
    }
    guard case .request(let request) = message else {
      return .silent
    }
    if request.method == "initialize" {
      return initialize(request)
    }
    if request.method.hasPrefix("notifications/") {
      return .silent
    }
    guard initialized else {
      let error = JSONRPCError(
        code: Self.notInitializedCode,
        message: "Session not initialized: send initialize with the session token first",
        data: ["code": "NOT_INITIALIZED"]
      )
      return reply(to: request, error: error)
    }
    switch request.method {
    case "ping":
      return reply(to: request, result: [:])
    case "tools/list":
      return reply(to: request, result: await dispatcher.toolsListResult)
    case "tools/call":
      return await call(request)
    default:
      return reply(to: request, error: .methodNotFound(request.method))
    }
  }

  private func initialize(_ request: JSONRPCRequest) -> AgentRPCOutcome {
    guard request.params?["token"]?.stringValue == token else {
      let error = JSONRPCError(code: Self.unauthorizedCode, message: "Unauthorized: wrong session token", data: ["code": "UNAUTHORIZED"])
      return AgentRPCOutcome(reply: JSONRPCResponse(id: request.id, error: error), closeAfterReply: true)
    }
    initialized = true
    let result: JSONValue = [
      "protocolVersion": .string(AgentToolCatalog.protocolVersion),
      "capabilities": ["tools": ["listChanged": false]],
      "serverInfo": ["name": .string(AgentToolCatalog.serverName), "version": .string(serverVersion)],
      "instructions":
        "Tools inspect the recording that is open in the Reframed editor. Times are seconds in source time. Nothing here changes the project.",
    ]
    return reply(to: request, result: result)
  }

  private func call(_ request: JSONRPCRequest) async -> AgentRPCOutcome {
    guard let name = request.params?["name"]?.stringValue else {
      return reply(to: request, error: .invalidParams("tools/call needs a string name"))
    }
    let arguments = request.params?["arguments"]
    let definition = await dispatcher.definition(named: name)
    let timeout = definition?.slow == true ? timeouts.slow : timeouts.regular
    let dispatcher = dispatcher
    do {
      let value = try await Self.withTimeout(timeout, name: name) {
        try await dispatcher.call(name, arguments: arguments)
      }
      return reply(to: request, result: AgentToolResult.success(value).mcpValue)
    } catch AgentToolError.failed(let message) {
      return reply(to: request, result: AgentToolResult.failure(message).mcpValue)
    } catch let error as AgentToolError {
      return reply(to: request, error: error.jsonRPCError)
    } catch {
      return reply(to: request, error: .internalError(error.localizedDescription))
    }
  }

  private static func withTimeout<T: Sendable>(
    _ duration: Duration,
    name: String,
    _ operation: @escaping @Sendable () async throws -> T
  ) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
      group.addTask { try await operation() }
      group.addTask {
        try await Task.sleep(for: duration)
        throw AgentToolError.timedOut(name)
      }
      guard let first = try await group.next() else {
        throw AgentToolError.timedOut(name)
      }
      group.cancelAll()
      return first
    }
  }

  private func reply(to request: JSONRPCRequest, result: JSONValue) -> AgentRPCOutcome {
    guard !request.isNotification else { return .silent }
    return AgentRPCOutcome(reply: JSONRPCResponse(id: request.id, result: result), closeAfterReply: false)
  }

  private func reply(to request: JSONRPCRequest, error: JSONRPCError) -> AgentRPCOutcome {
    guard !request.isNotification else { return .silent }
    return AgentRPCOutcome(reply: JSONRPCResponse(id: request.id, error: error), closeAfterReply: false)
  }
}
