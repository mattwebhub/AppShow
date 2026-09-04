import Foundation
import Logging

struct AgentProcessLaunch: Sendable {
  var executable: URL
  var arguments: [String]
  var workingDirectory: URL?
  var environment: [String: String]
  var standardInput: String?

  init(executable: URL, arguments: [String], workingDirectory: URL? = nil, environment: [String: String], standardInput: String? = nil) {
    self.executable = executable
    self.arguments = arguments
    self.workingDirectory = workingDirectory
    self.environment = environment
    self.standardInput = standardInput
  }
}

enum AgentEnvironment {
  static func scrubbed(
    path: String,
    home: String,
    forwarding: [String],
    source: [String: String] = ProcessInfo.processInfo.environment
  ) -> [String: String] {
    let user = source["USER"] ?? URL(fileURLWithPath: home).lastPathComponent
    var environment = [
      "PATH": path,
      "HOME": home,
      "LANG": source["LANG"] ?? "en_US.UTF-8",
      "TERM": source["TERM"] ?? "xterm-256color",
      "USER": user,
      "LOGNAME": source["LOGNAME"] ?? user,
    ]
    for key in forwarding where key != "PATH" && key != "HOME" {
      if let value = source[key] {
        environment[key] = value
      }
    }
    return environment
  }
}

actor AgentProcessRunner {
  private let logger = Logger(label: "com.mattwebhub.appshow.agent-process-runner")
  private let maximumLineLength: Int
  private let stderrTailLength = 4096
  private var process: Process?
  private var continuation: AsyncThrowingStream<String, Error>.Continuation?
  private var lineBuffer: [UInt8] = []
  private var stderrBuffer: [UInt8] = []
  private var overflowing = false
  private var standardOutputFinished = false
  private var standardErrorFinished = false
  private var terminated = false
  private var cancelledBeforeLaunch = false
  private var failure: AgentError?
  private var killTask: Task<Void, Never>?
  private var forceFinishTask: Task<Void, Never>?
  private(set) var exitStatus: Int32?
  private(set) var isRunning = false
  private(set) var linesDelivered = 0

  init(maximumLineLength: Int = 1_048_576) {
    self.maximumLineLength = maximumLineLength
  }

  func run(_ launch: AgentProcessLaunch) -> AsyncThrowingStream<String, Error> {
    let (stream, continuation) = AsyncThrowingStream<String, Error>.makeStream()
    guard !isRunning else {
      continuation.finish(throwing: AgentError.alreadyRunning)
      return stream
    }
    guard !cancelledBeforeLaunch else {
      continuation.finish(throwing: AgentError.cancelled)
      return stream
    }
    resetState()
    self.continuation = continuation
    continuation.onTermination = { [weak self] reason in
      guard case .cancelled = reason else { return }
      Task { await self?.cancel() }
    }

    let process = Process()
    process.executableURL = launch.executable
    process.arguments = launch.arguments
    process.currentDirectoryURL = launch.workingDirectory
    process.environment = launch.environment
    let stdout = Pipe()
    let stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr
    let stdin = launch.standardInput.map { _ in Pipe() }
    process.standardInput = stdin ?? FileHandle.nullDevice
    process.terminationHandler = { [weak self] ended in
      let status = ended.terminationStatus
      Task { await self?.processDidTerminate(status: status) }
    }

    do {
      try process.run()
    } catch {
      logger.error("Agent process failed to launch: \(error.localizedDescription)")
      continuation.finish(throwing: AgentError.launchFailed(error.localizedDescription))
      self.continuation = nil
      return stream
    }

    self.process = process
    isRunning = true
    logger.info("Agent process started", metadata: ["pid": "\(process.processIdentifier)", "executable": "\(launch.executable.path)"])
    startReadingStandardOutput(stdout.fileHandleForReading)
    startReadingStandardError(stderr.fileHandleForReading)
    if let stdin, let text = launch.standardInput {
      writeStandardInput(text, to: stdin.fileHandleForWriting)
    }
    return stream
  }

  func cancel() {
    guard let process, isRunning else {
      cancelledBeforeLaunch = true
      return
    }
    if failure == nil {
      failure = .cancelled
    }
    process.terminate()
    killTask?.cancel()
    killTask = Task {
      try? await Task.sleep(for: .seconds(2))
      guard !Task.isCancelled else { return }
      self.killIfStillRunning()
    }
  }

  private func killIfStillRunning() {
    guard let process, process.isRunning else { return }
    Darwin.kill(process.processIdentifier, SIGKILL)
  }

  private func resetState() {
    lineBuffer.removeAll()
    stderrBuffer.removeAll()
    overflowing = false
    standardOutputFinished = false
    standardErrorFinished = false
    terminated = false
    failure = nil
    exitStatus = nil
    linesDelivered = 0
  }

  private static func chunks(from handle: FileHandle) -> AsyncStream<Data> {
    AsyncStream { continuation in
      handle.readabilityHandler = { handle in
        let data = handle.availableData
        if data.isEmpty {
          handle.readabilityHandler = nil
          continuation.finish()
        } else {
          continuation.yield(data)
        }
      }
      continuation.onTermination = { _ in
        handle.readabilityHandler = nil
      }
    }
  }

  private func startReadingStandardOutput(_ handle: FileHandle) {
    Task {
      for await chunk in Self.chunks(from: handle) {
        consume(chunk)
      }
      standardOutputDidFinish()
    }
  }

  private func startReadingStandardError(_ handle: FileHandle) {
    Task {
      for await chunk in Self.chunks(from: handle) {
        appendStandardError(chunk)
      }
      standardErrorDidFinish()
    }
  }

  private func writeStandardInput(_ text: String, to handle: FileHandle) {
    let data = Data(text.utf8)
    Task.detached(priority: .utility) {
      try? handle.write(contentsOf: data)
      try? handle.close()
    }
  }

  private func consume(_ chunk: Data) {
    var remaining = chunk[...]
    while let newline = remaining.firstIndex(of: 0x0A) {
      appendToLine(remaining[remaining.startIndex..<newline])
      flushLine()
      remaining = remaining[remaining.index(after: newline)...]
    }
    appendToLine(remaining)
  }

  private func appendToLine(_ bytes: Data.SubSequence) {
    guard !overflowing, !bytes.isEmpty else { return }
    lineBuffer.append(contentsOf: bytes)
    if lineBuffer.count > maximumLineLength {
      overflowing = true
      lineBuffer.removeAll(keepingCapacity: false)
      logger.error("Agent process produced a line over \(maximumLineLength) bytes")
      failure = failure ?? .lineTooLong
      cancel()
    }
  }

  private func flushLine() {
    defer {
      lineBuffer.removeAll(keepingCapacity: true)
      overflowing = false
    }
    guard !overflowing, failure == nil else { return }
    if lineBuffer.last == 0x0D {
      lineBuffer.removeLast()
    }
    let line = String(decoding: lineBuffer, as: UTF8.self)
    guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { return }
    continuation?.yield(line)
    linesDelivered += 1
  }

  private func appendStandardError(_ chunk: Data) {
    stderrBuffer.append(contentsOf: chunk)
    if stderrBuffer.count > stderrTailLength * 2 {
      stderrBuffer.removeFirst(stderrBuffer.count - stderrTailLength)
    }
  }

  private var stderrTail: String {
    let tail = stderrBuffer.suffix(stderrTailLength)
    return String(decoding: tail, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func standardOutputDidFinish() {
    standardOutputFinished = true
    finishIfComplete()
  }

  private func standardErrorDidFinish() {
    standardErrorFinished = true
    finishIfComplete()
  }

  private func processDidTerminate(status: Int32) {
    exitStatus = status
    isRunning = false
    terminated = true
    killTask?.cancel()
    killTask = nil
    logger.info("Agent process exited", metadata: ["status": "\(status)"])
    finishIfComplete()
    if continuation != nil {
      forceFinishTask = Task {
        try? await Task.sleep(for: .seconds(2))
        guard !Task.isCancelled else { return }
        self.finishIfComplete(force: true)
      }
    }
  }

  private func finishIfComplete(force: Bool = false) {
    guard terminated, (standardOutputFinished && standardErrorFinished) || force, let continuation else { return }
    if !lineBuffer.isEmpty {
      flushLine()
    }
    self.continuation = nil
    forceFinishTask?.cancel()
    forceFinishTask = nil
    process = nil
    if let failure {
      continuation.finish(throwing: failure)
    } else if let exitStatus, exitStatus != 0 {
      continuation.finish(throwing: AgentError.processFailed(status: exitStatus, stderrTail: stderrTail))
    } else {
      continuation.finish()
    }
  }
}
