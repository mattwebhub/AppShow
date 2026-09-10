import Darwin
import Foundation

enum ShimFailure: Error {
  case missingEnvironment(String)
  case pathTooLong
  case socket(Int32)
  case connect(Int32)
  case write(Int32)
}

final class ShimState: @unchecked Sendable {
  private let lock = NSLock()
  private var inputEnded = false

  func endInput() {
    lock.lock()
    inputEnded = true
    lock.unlock()
  }

  var hasEndedInput: Bool {
    lock.lock()
    defer { lock.unlock() }
    return inputEnded
  }
}

func environment(_ name: String, legacyName: String? = nil) throws -> String {
  let current = ProcessInfo.processInfo.environment[name]
  let legacy = legacyName.flatMap { ProcessInfo.processInfo.environment[$0] }
  guard let value = current ?? legacy, !value.isEmpty else {
    throw ShimFailure.missingEnvironment(name)
  }
  return value
}

func connectSocket(path: String) throws -> Int32 {
  let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
  guard descriptor >= 0 else { throw ShimFailure.socket(errno) }
  var noSignal: Int32 = 1
  setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout.size(ofValue: noSignal)))
  var address = sockaddr_un()
  address.sun_family = sa_family_t(AF_UNIX)
  let bytes = Array(path.utf8CString)
  let capacity = MemoryLayout.size(ofValue: address.sun_path)
  guard bytes.count <= capacity else {
    close(descriptor)
    throw ShimFailure.pathTooLong
  }
  _ = withUnsafeMutablePointer(to: &address.sun_path) { pointer in
    pointer.withMemoryRebound(to: CChar.self, capacity: capacity) { destination in
      bytes.withUnsafeBytes { source in
        memcpy(destination, source.baseAddress, bytes.count)
      }
    }
  }
  let length = socklen_t(MemoryLayout<sa_family_t>.size + bytes.count)
  let result = withUnsafePointer(to: &address) { pointer in
    pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
      Darwin.connect(descriptor, $0, length)
    }
  }
  guard result == 0 else {
    let code = errno
    close(descriptor)
    throw ShimFailure.connect(code)
  }
  return descriptor
}

func authenticatedLine(_ line: String, token: String) throws -> Data {
  let input = Data(line.utf8)
  guard
    var object = try JSONSerialization.jsonObject(with: input) as? [String: Any],
    object["method"] as? String == "initialize"
  else {
    return input + Data([0x0A])
  }
  var parameters = object["params"] as? [String: Any] ?? [:]
  parameters["token"] = token
  object["params"] = parameters
  return try JSONSerialization.data(withJSONObject: object) + Data([0x0A])
}

func writeAll(_ data: Data, to descriptor: Int32) throws {
  try data.withUnsafeBytes { rawBuffer in
    guard var pointer = rawBuffer.baseAddress else { return }
    var remaining = rawBuffer.count
    while remaining > 0 {
      let count = Darwin.write(descriptor, pointer, remaining)
      guard count > 0 else { throw ShimFailure.write(errno) }
      remaining -= count
      pointer = pointer.advanced(by: count)
    }
  }
}

func report(_ error: any Error) {
  let message = String(describing: error)
  let response: [String: Any] = [
    "jsonrpc": "2.0",
    "id": NSNull(),
    "error": ["code": -32000, "message": "AppShow MCP bridge failed: \(message)"],
  ]
  if let data = try? JSONSerialization.data(withJSONObject: response) {
    FileHandle.standardOutput.write(data + Data([0x0A]))
  }
  FileHandle.standardError.write(Data("AppShow MCP bridge failed: \(message)\n".utf8))
}

func socketReader(_ descriptor: Int32, state: ShimState) -> DispatchWorkItem {
  DispatchWorkItem {
    var buffer = [UInt8](repeating: 0, count: 65_536)
    while true {
      let count = Darwin.read(descriptor, &buffer, buffer.count)
      if count > 0 {
        try? writeAll(Data(buffer[0..<count]), to: STDOUT_FILENO)
      } else {
        if !state.hasEndedInput {
          exit(EXIT_FAILURE)
        }
        break
      }
    }
  }
}

do {
  let path = try environment("APPSHOW_AGENT_SOCKET", legacyName: "REFRAMED_AGENT_SOCKET")
  let token = try environment("APPSHOW_AGENT_TOKEN", legacyName: "REFRAMED_AGENT_TOKEN")
  let descriptor = try connectSocket(path: path)
  let state = ShimState()
  let reader = socketReader(descriptor, state: state)
  DispatchQueue(label: "appshow-mcp.socket-reader").async(execute: reader)
  while let line = readLine(strippingNewline: true) {
    try writeAll(authenticatedLine(line, token: token), to: descriptor)
  }
  state.endInput()
  shutdown(descriptor, SHUT_WR)
  reader.wait()
  close(descriptor)
} catch {
  report(error)
  exit(EXIT_FAILURE)
}
