import Foundation

struct AgentRuntimePolicy: Sendable {
  var sandboxed: Bool
  var bundleURL: URL
  var stateRoot: URL
  var temporaryRoot: URL

  init(
    sandboxed: Bool = AppDistribution.isStore,
    bundleURL: URL = Bundle.main.bundleURL,
    stateRoot: URL = AppShowPaths.home.appendingPathComponent("agents", isDirectory: true),
    temporaryRoot: URL = AppShowPaths.temp.appendingPathComponent("agents", isDirectory: true)
  ) {
    self.sandboxed = sandboxed
    self.bundleURL = bundleURL
    self.stateRoot = stateRoot
    self.temporaryRoot = temporaryRoot
  }

  var runtimeDirectory: URL {
    #if arch(arm64)
    let architecture = "arm64"
    #else
    let architecture = "x86_64"
    #endif
    return bundleURL.appendingPathComponent("Contents/Helpers/Runtimes/\(architecture)", isDirectory: true)
  }

  var searchPath: String {
    runtimeDirectory.path + ":/usr/bin:/bin:/usr/sbin:/sbin"
  }

  func permits(_ executable: URL) -> Bool {
    guard sandboxed else { return true }
    guard ["codex", "claude"].contains(executable.lastPathComponent) else { return false }
    let resolved = executable.resolvingSymlinksInPath().standardizedFileURL
    return resolved.deletingLastPathComponent() == runtimeDirectory.resolvingSymlinksInPath().standardizedFileURL
  }

  func prepare() throws {
    guard sandboxed else { return }
    let directories = ["codex", "claude", "workspaces"].map { stateRoot.appendingPathComponent($0, isDirectory: true) }
    for directory in directories + [temporaryRoot] {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
    }
  }

  func environment(
    path: String,
    home: String,
    forwarding: [String],
    source: [String: String] = ProcessInfo.processInfo.environment
  ) -> [String: String] {
    var environment = AgentEnvironment.scrubbed(
      path: sandboxed ? searchPath : path,
      home: home,
      forwarding: sandboxed ? [] : forwarding,
      source: source
    )
    environment["DISABLE_AUTOUPDATER"] = "1"
    environment["DISABLE_UPDATES"] = "1"
    if sandboxed {
      environment["CODEX_HOME"] = stateRoot.appendingPathComponent("codex").path
      environment["CLAUDE_CONFIG_DIR"] = stateRoot.appendingPathComponent("claude").path
      environment["TMPDIR"] = temporaryRoot.path
      environment["CLAUDE_CODE_TMPDIR"] = temporaryRoot.path
      environment["CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC"] = "1"
    }
    return environment
  }
}
