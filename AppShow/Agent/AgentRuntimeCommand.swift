#if !APP_STORE
import Foundation
import Security

enum AgentRuntimeCommand {
  static func run(_ executable: URL, arguments: [String], directory: URL, timeout: Duration = .seconds(30)) async throws -> String {
    let runner = AgentProcessRunner(maximumLineLength: 65536)
    var environment = AgentEnvironment.scrubbed(path: "/usr/bin:/bin:/usr/sbin:/sbin", home: directory.path, forwarding: [], source: [:])
    environment["CODEX_HOME"] = directory.appendingPathComponent("codex-state").path
    environment["CLAUDE_CONFIG_DIR"] = directory.appendingPathComponent("claude-state").path
    environment["DISABLE_AUTOUPDATER"] = "1"
    environment["DISABLE_UPDATES"] = "1"
    let launch = AgentProcessLaunch(executable: executable, arguments: arguments, workingDirectory: directory, environment: environment)
    return try await withThrowingTaskGroup(of: String.self) { group in
      group.addTask {
        var output = ""
        for try await line in await runner.run(launch) {
          guard output.utf8.count + line.utf8.count <= 1024 * 1024 else {
            throw AgentRuntimeUpdateError("Runtime verification produced too much output.")
          }
          output += line + "\n"
        }
        return output
      }
      group.addTask {
        try await Task.sleep(for: timeout)
        throw AgentRuntimeUpdateError("Runtime verification timed out.")
      }
      do {
        let output = try await group.next() ?? ""
        group.cancelAll()
        await runner.cancel()
        return output
      } catch {
        group.cancelAll()
        await runner.cancel()
        throw error
      }
    }
  }

  static func validate(_ executable: URL, version: String?) async throws {
    var code: SecStaticCode?
    guard SecStaticCodeCreateWithPath(executable as CFURL, [], &code) == errSecSuccess, let code,
      SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate), nil) == errSecSuccess
    else { throw AgentRuntimeUpdateError("The downloaded runtime's code signature is invalid.") }
    if let version {
      let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("appshow-runtime-check-\(UUID().uuidString)")
      try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
      defer { try? FileManager.default.removeItem(at: temporary) }
      let output = try await run(executable, arguments: ["--version"], directory: temporary, timeout: .seconds(10))
      guard AgentVersionParser.semanticVersion(from: output) == version else {
        throw AgentRuntimeUpdateError("The downloaded runtime failed its version check.")
      }
    }
  }
}
#endif
