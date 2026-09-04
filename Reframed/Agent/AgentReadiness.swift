import Darwin
import Foundation

enum AgentReadiness: Equatable, Sendable {
  case missing(searchedPaths: [String])
  case notLoggedIn(executable: String, version: String)
  case ready(executable: String, version: String)
  case unhealthy(executable: String?, reason: String)

  var statusLabel: String {
    switch self {
    case .missing: "Not found"
    case .notLoggedIn: "Sign in required"
    case .ready: "Ready"
    case .unhealthy: "Needs repair"
    }
  }

  var isReady: Bool {
    if case .ready = self { return true }
    return false
  }

  var executableURL: URL? {
    switch self {
    case .notLoggedIn(let executable, _), .ready(let executable, _):
      URL(fileURLWithPath: executable)
    case .missing, .unhealthy:
      nil
    }
  }
}

enum AgentVersionParser {
  static func semanticVersion(from output: String) -> String? {
    guard let match = output.firstMatch(of: /\d+\.\d+\.\d+/) else { return nil }
    return String(match.output)
  }
}

struct AgentReadinessSnapshot: Equatable, Sendable {
  var statuses: [AgentProviderKind: AgentReadiness]

  func selection(remembered: AgentProviderKind) -> AgentProviderKind {
    let ready = AgentProviderKind.allCases.filter { statuses[$0]?.isReady == true }
    return ready.count == 1 ? ready[0] : remembered
  }
}

actor AgentProbe {
  private let timeout: Duration
  private let maximumOutputBytes: Int

  init(timeout: Duration = .seconds(10), maximumOutputBytes: Int = 32 * 1024) {
    self.timeout = timeout
    self.maximumOutputBytes = maximumOutputBytes
  }

  func check(
    provider: AgentProviderKind,
    executable: URL,
    environment: [String: String]
  ) async -> AgentReadiness {
    let versionResult = await run(executable: executable, arguments: ["--version"], environment: environment)
    if versionResult.timedOut {
      return .unhealthy(executable: executable.path, reason: "Version check timed out")
    }
    if let launchError = versionResult.launchError {
      return .unhealthy(executable: executable.path, reason: launchError)
    }
    guard versionResult.status == 0 else {
      return .unhealthy(executable: executable.path, reason: "Version check failed")
    }
    guard let version = AgentVersionParser.semanticVersion(from: versionResult.output) else {
      return .unhealthy(executable: executable.path, reason: "Version output was not recognized")
    }

    let arguments = provider == .claudeCode ? ["auth", "status"] : ["login", "status"]
    let authResult = await run(executable: executable, arguments: arguments, environment: environment)
    if authResult.timedOut {
      return .unhealthy(executable: executable.path, reason: "Authentication check timed out")
    }
    if let launchError = authResult.launchError {
      return .unhealthy(executable: executable.path, reason: launchError)
    }

    switch provider {
    case .claudeCode:
      guard authResult.status == 0 else {
        return .notLoggedIn(executable: executable.path, version: version)
      }
      guard
        let data = authResult.output.data(using: .utf8),
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let loggedIn = object["loggedIn"] as? Bool
      else {
        return .unhealthy(executable: executable.path, reason: "Authentication response was not recognized")
      }
      return loggedIn
        ? .ready(executable: executable.path, version: version)
        : .notLoggedIn(executable: executable.path, version: version)
    case .codex:
      return authResult.status == 0 && !authResult.output.isEmpty
        ? .ready(executable: executable.path, version: version)
        : .notLoggedIn(executable: executable.path, version: version)
    }
  }

  private func run(
    executable: URL,
    arguments: [String],
    environment: [String: String]
  ) async -> AgentProbeResult {
    let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("appshow-agent-probe-\(UUID().uuidString)")
    guard FileManager.default.createFile(atPath: outputURL.path, contents: nil),
      let outputHandle = try? FileHandle(forWritingTo: outputURL)
    else {
      return AgentProbeResult(launchError: "Could not create probe output")
    }
    defer {
      try? outputHandle.close()
      try? FileManager.default.removeItem(at: outputURL)
    }

    let process = Process()
    process.executableURL = executable
    process.arguments = arguments
    process.environment = environment
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = outputHandle
    process.standardError = outputHandle
    do {
      try process.run()
    } catch {
      return AgentProbeResult(launchError: "Could not launch provider")
    }

    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while process.isRunning, clock.now < deadline, !Task.isCancelled {
      try? await Task.sleep(for: .milliseconds(25))
    }
    guard !process.isRunning, !Task.isCancelled else {
      if process.isRunning {
        Darwin.kill(process.processIdentifier, SIGKILL)
        process.waitUntilExit()
      }
      return AgentProbeResult(timedOut: true)
    }

    try? outputHandle.synchronize()
    guard
      let attributes = try? FileManager.default.attributesOfItem(atPath: outputURL.path),
      ((attributes[.size] as? NSNumber)?.intValue ?? 0) <= maximumOutputBytes,
      let data = try? Data(contentsOf: outputURL)
    else {
      return AgentProbeResult(status: process.terminationStatus, launchError: "Provider output exceeded the limit")
    }
    return AgentProbeResult(
      output: String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines),
      status: process.terminationStatus
    )
  }
}

private struct AgentProbeResult: Sendable {
  var output = ""
  var status: Int32 = -1
  var timedOut = false
  var launchError: String?
}
