import Foundation
import Logging
import Network

actor AgentBridgeServer {
  let socketURL: URL
  private let token: String
  private let dispatcher: AgentToolDispatcher
  private let timeouts: AgentRPCTimeouts
  private let queue = DispatchQueue(label: "com.mattwebhub.appshow.agent-bridge")
  private let logger = Logger(label: "com.mattwebhub.appshow.agent-bridge")
  private var listener: NWListener?
  private var connections: [Int: AgentBridgeConnection] = [:]
  private var nextConnectionID = 0
  private(set) var isListening = false

  init(socketURL: URL, token: String, dispatcher: AgentToolDispatcher, timeouts: AgentRPCTimeouts = .default) {
    self.socketURL = socketURL
    self.token = token
    self.dispatcher = dispatcher
    self.timeouts = timeouts
  }

  func start() async throws {
    guard listener == nil else { return }
    try? FileManager.default.removeItem(at: socketURL)
    let parameters = NWParameters.tcp
    parameters.requiredLocalEndpoint = NWEndpoint.unix(path: socketURL.path)
    let listener = try NWListener(using: parameters)
    self.listener = listener
    listener.newConnectionHandler = { [weak self] connection in
      Task { await self?.accept(connection) }
    }
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
      let gate = AgentBridgeContinuationGate(continuation)
      listener.stateUpdateHandler = { [weak self] state in
        switch state {
        case .ready:
          gate.resume(.success(()))
        case .failed(let error):
          gate.resume(.failure(error))
          Task { await self?.listenerEnded() }
        case .cancelled:
          gate.resume(.failure(CancellationError()))
          Task { await self?.listenerEnded() }
        default:
          break
        }
      }
      listener.start(queue: queue)
    }
    try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: socketURL.path)
    isListening = true
    logger.info("Agent bridge listening", metadata: ["socket": "\(socketURL.path)"])
  }

  func stop() {
    listener?.stateUpdateHandler = nil
    listener?.cancel()
    listener = nil
    let open = Array(connections.values)
    connections.removeAll()
    Task {
      for connection in open {
        await connection.cancel()
      }
    }
    isListening = false
    try? FileManager.default.removeItem(at: socketURL)
    logger.info("Agent bridge stopped")
  }

  private func listenerEnded() {
    isListening = false
  }

  private func accept(_ connection: NWConnection) {
    let id = nextConnectionID
    nextConnectionID += 1
    let session = AgentRPCSession(token: token, dispatcher: dispatcher, timeouts: timeouts)
    let bridge = AgentBridgeConnection(connection: connection, session: session, queue: queue) { [weak self] in
      Task { await self?.forget(id) }
    }
    connections[id] = bridge
    Task { await bridge.start() }
    logger.info("Agent bridge connection \(id) opened")
  }

  private func forget(_ id: Int) {
    connections[id] = nil
    logger.info("Agent bridge connection \(id) closed")
  }
}

private final class AgentBridgeContinuationGate: @unchecked Sendable {
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

actor AgentBridgeConnection {
  private let connection: NWConnection
  private let session: AgentRPCSession
  private let queue: DispatchQueue
  private let onClose: @Sendable () -> Void
  private var buffer = JSONRPCLineBuffer()
  private var pending: [Data] = []
  private var processing = false
  private var closed = false

  init(connection: NWConnection, session: AgentRPCSession, queue: DispatchQueue, onClose: @escaping @Sendable () -> Void) {
    self.connection = connection
    self.session = session
    self.queue = queue
    self.onClose = onClose
  }

  func start() {
    connection.stateUpdateHandler = { [weak self] state in
      switch state {
      case .failed, .cancelled:
        Task { await self?.finish() }
      default:
        break
      }
    }
    connection.start(queue: queue)
    receive()
  }

  func cancel() {
    connection.cancel()
  }

  private func receive() {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) { [weak self] data, _, isComplete, error in
      Task { await self?.received(data, ended: isComplete || error != nil) }
    }
  }

  private func received(_ data: Data?, ended: Bool) {
    if let data {
      pending.append(contentsOf: buffer.append(data))
      if !processing && !pending.isEmpty {
        processing = true
        Task { await self.drain() }
      }
    }
    if ended {
      connection.cancel()
      finish()
    } else {
      receive()
    }
  }

  private func drain() async {
    while !pending.isEmpty {
      let line = pending.removeFirst()
      let outcome = await session.handle(line: line)
      if let reply = outcome.reply {
        send(reply, thenClose: outcome.closeAfterReply)
      }
      if outcome.closeAfterReply {
        pending.removeAll()
        break
      }
    }
    processing = false
  }

  private func send(_ response: JSONRPCResponse, thenClose: Bool) {
    guard let data = try? JSONRPCCodec.encode(response) else { return }
    let connection = connection
    connection.send(
      content: data,
      completion: .contentProcessed { _ in
        if thenClose {
          connection.cancel()
        }
      }
    )
  }

  private func finish() {
    guard !closed else { return }
    closed = true
    onClose()
  }
}
