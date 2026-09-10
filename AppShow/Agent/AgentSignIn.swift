import AppKit
import Foundation
import Observation

enum AgentSignInURL {
  static func parse(_ text: String, provider: AgentProviderKind) -> URL? {
    let hosts: Set<String> =
      provider == .codex
      ? ["auth.openai.com"]
      : ["claude.ai", "platform.claude.com", "console.anthropic.com", "auth.anthropic.com"]
    let expression = try! NSRegularExpression(pattern: "https://[^\\s<>\\\"\\u001B]+")
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    for match in expression.matches(in: text, range: range) {
      guard let range = Range(match.range, in: text), let url = URL(string: String(text[range])),
        let host = url.host, hosts.contains(host), url.user == nil, url.password == nil,
        url.path.hasSuffix("/oauth/authorize") || url.path.hasSuffix("/authorize")
      else { continue }
      return url
    }
    return nil
  }
}

@MainActor
@Observable
final class AgentSignIn {
  private(set) var isRunning = false
  private(set) var message: String?
  private(set) var authorizationURL: URL?
  private var process: Process?
  private var output = ""

  func start(provider: AgentProviderKind, executable: URL, environment: [String: String], console: Bool = false) async -> Bool {
    guard !isRunning, AgentRuntimePolicy().permits(executable) else { return false }
    do { try AgentRuntimePolicy().prepare() } catch {
      message = "Could not prepare sign-in storage."
      return false
    }
    isRunning = true
    message = "Complete sign-in in your browser."
    authorizationURL = nil
    output = ""
    let process = Process()
    process.executableURL = executable
    process.arguments = provider == .codex ? ["login"] : ["auth", "login"] + (console ? ["--console"] : [])
    process.environment = environment
    process.currentDirectoryURL = AgentRuntimePolicy().stateRoot
    process.standardInput = FileHandle.nullDevice
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    self.process = process
    pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
      let data = handle.availableData
      if !data.isEmpty {
        Task { @MainActor in self?.receive(data, provider: provider) }
      }
    }
    let success: Bool = await withCheckedContinuation { continuation in
      process.terminationHandler = { ended in
        continuation.resume(returning: ended.terminationStatus == 0)
      }
      do { try process.run() } catch { continuation.resume(returning: false) }
    }
    pipe.fileHandleForReading.readabilityHandler = nil
    try? pipe.fileHandleForReading.close()
    self.process = nil
    isRunning = false
    output = ""
    authorizationURL = nil
    message = success ? "Signed in." : "Sign-in did not complete. You can try again."
    return success
  }

  func cancel() {
    guard let process, process.isRunning else { return }
    process.terminate()
    Task {
      try? await Task.sleep(for: .seconds(2))
      if process.isRunning { Darwin.kill(process.processIdentifier, SIGKILL) }
    }
  }

  private func receive(_ data: Data, provider: AgentProviderKind) {
    output = String((output + String(decoding: data, as: UTF8.self)).suffix(16_384))
    guard authorizationURL == nil, let url = AgentSignInURL.parse(output, provider: provider) else { return }
    authorizationURL = url
    NSWorkspace.shared.open(url)
  }
}
