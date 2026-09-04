import Foundation
import Logging

actor AgentToolchain {
  private let logger = Logger(label: "com.mattwebhub.appshow.agent-toolchain")
  private let pathDirectories: [URL]
  private let extraDirectories: [URL]
  private let loginShell: URL?
  private let loginShellTimeout: Duration
  private let home: URL
  private var cache: [String: URL] = [:]
  private var discoveredDirectories: [URL] = []

  init(
    path: String = ProcessInfo.processInfo.environment["PATH"] ?? "",
    extraDirectories: [URL] = [],
    loginShell: URL? = URL(fileURLWithPath: "/bin/zsh"),
    loginShellTimeout: Duration = .seconds(8),
    home: URL = FileManager.default.homeDirectoryForCurrentUser
  ) {
    pathDirectories = path.split(separator: ":").map { URL(fileURLWithPath: String($0), isDirectory: true) }
    self.extraDirectories = extraDirectories
    self.loginShell = loginShell
    self.loginShellTimeout = loginShellTimeout
    self.home = home
  }

  static func standard() -> AgentToolchain {
    AgentToolchain(extraDirectories: defaultSearchDirectories())
  }

  static func defaultSearchDirectories(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [URL] {
    let directories = [
      home.appendingPathComponent(".local/bin"),
      home.appendingPathComponent(".bun/bin"),
      home.appendingPathComponent(".volta/bin"),
      home.appendingPathComponent(".nvm/current/bin"),
      home.appendingPathComponent(".nodenv/shims"),
      home.appendingPathComponent(".asdf/shims"),
      home.appendingPathComponent(".local/share/mise/shims"),
      home.appendingPathComponent(".npm-global/bin"),
      home.appendingPathComponent(".npm-packages/bin"),
      home.appendingPathComponent(".local/share/pnpm"),
      home.appendingPathComponent("Library/pnpm"),
      home.appendingPathComponent(".pnpm/bin"),
      home.appendingPathComponent(".yarn/bin"),
      home.appendingPathComponent(".config/yarn/global/node_modules/.bin"),
      home.appendingPathComponent(".cargo/bin"),
      URL(fileURLWithPath: "/opt/homebrew/bin"),
      URL(fileURLWithPath: "/usr/local/bin"),
      URL(fileURLWithPath: "/usr/bin"),
      URL(fileURLWithPath: "/bin"),
      URL(fileURLWithPath: "/usr/sbin"),
      URL(fileURLWithPath: "/sbin"),
    ]
    return deduplicated(directories)
  }

  func resolve(_ names: [String]) async -> URL? {
    for name in names {
      if let cached = cache[name] {
        return cached
      }
      if let found = searchDirectories.lazy.map({ $0.appendingPathComponent(name) }).first(where: isExecutableFile) {
        cache[name] = found
        return found
      }
    }
    for name in names {
      if let found = await resolveUsingLoginShell(name) {
        cache[name] = found
        discoveredDirectories = Self.deduplicated(discoveredDirectories + [found.deletingLastPathComponent()])
        return found
      }
    }
    return nil
  }

  func invalidate() {
    cache.removeAll()
    discoveredDirectories.removeAll()
  }

  func searchPath() -> String {
    searchDirectories.map(\.path).joined(separator: ":")
  }

  private var searchDirectories: [URL] {
    Self.deduplicated(pathDirectories + extraDirectories + discoveredDirectories)
  }

  private func resolveUsingLoginShell(_ name: String) async -> URL? {
    guard let loginShell, isExecutableFile(loginShell), Self.isShellSafeName(name) else { return nil }
    let runner = AgentProcessRunner(maximumLineLength: 65536)
    let launch = AgentProcessLaunch(
      executable: loginShell,
      arguments: ["-lc", "command -v \(name)"],
      workingDirectory: home,
      environment: AgentEnvironment.scrubbed(path: searchPath(), home: home.path, forwarding: [])
    )
    let timeout = loginShellTimeout
    let lines: [String] = await withTaskGroup(of: [String]?.self) { group in
      group.addTask {
        var collected: [String] = []
        do {
          for try await line in await runner.run(launch) {
            collected.append(line)
          }
        } catch {
          return collected
        }
        return collected
      }
      group.addTask {
        try? await Task.sleep(for: timeout)
        return nil
      }
      let first = await group.next() ?? nil
      group.cancelAll()
      if first == nil {
        await runner.cancel()
      }
      return first ?? []
    }
    let candidates = lines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.hasPrefix("/") }
    for candidate in candidates.reversed() {
      let url = URL(fileURLWithPath: candidate).standardizedFileURL
      if isExecutableFile(url) {
        logger.info("Resolved \(name) through the login shell", metadata: ["path": "\(url.path)"])
        return url
      }
    }
    return nil
  }

  private nonisolated func isExecutableFile(_ url: URL) -> Bool {
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else { return false }
    return FileManager.default.isExecutableFile(atPath: url.path)
  }

  private static func isShellSafeName(_ name: String) -> Bool {
    !name.isEmpty && name.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) || "._-".unicodeScalars.contains($0) }
  }

  private static func deduplicated(_ directories: [URL]) -> [URL] {
    var seen: Set<String> = []
    return directories.filter { seen.insert($0.standardizedFileURL.path).inserted }
  }
}
