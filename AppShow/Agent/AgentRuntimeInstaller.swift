#if !APP_STORE
import CryptoKit
import Darwin
import Foundation

actor AgentRuntimeInstaller {
  typealias Download = @Sendable (URL) async throws -> URL
  typealias Validate = @Sendable (URL, String?) async throws -> Void

  private let root: URL
  private let download: Download
  private let validate: Validate
  private var isBusy = false

  init(root: URL, download: @escaping Download, validate: @escaping Validate) {
    self.root = root
    self.download = download
    self.validate = validate
  }

  func install(_ release: AgentRuntimeRelease) async throws -> URL {
    guard !isBusy else { throw AgentRuntimeUpdateError("Another runtime update is in progress.") }
    try release.validate()
    try Task.checkCancellation()
    isBusy = true
    defer { isBusy = false }
    let manager = FileManager.default
    try manager.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    let lock = root.appendingPathComponent(".install.lock").path.withCString { Darwin.open($0, O_CREAT | O_RDWR, 0o600) }
    guard lock >= 0 else { throw AgentRuntimeUpdateError("Could not lock the runtime directory.") }
    defer { Darwin.close(lock) }
    guard flock(lock, LOCK_EX | LOCK_NB) == 0 else { throw AgentRuntimeUpdateError("Another AppShow instance is updating the runtimes.") }
    defer { flock(lock, LOCK_UN) }

    let directory = root.appendingPathComponent(release.provider.rawValue)
    let releases = directory.appendingPathComponent("releases")
    try manager.createDirectory(at: releases, withIntermediateDirectories: true)
    let staging = releases.appendingPathComponent(".staging-\(UUID().uuidString)")
    try manager.createDirectory(at: staging, withIntermediateDirectories: false)
    defer { try? manager.removeItem(at: staging) }

    let downloaded = try await download(release.downloadURL)
    defer { try? manager.removeItem(at: downloaded) }
    guard try checksum(downloaded) == release.sha256.lowercased() else {
      throw AgentRuntimeUpdateError("The runtime checksum did not match the official release. The previous version is still installed.")
    }
    try Task.checkCancellation()
    if release.provider == .codex {
      let tar = URL(fileURLWithPath: "/usr/bin/tar")
      let listing = try await AgentRuntimeCommand.run(tar, arguments: ["-tzf", downloaded.path], directory: staging)
      let types = try await AgentRuntimeCommand.run(tar, arguments: ["-tvzf", downloaded.path], directory: staging)
      try AgentRuntimeArchive.validate(listing: listing, types: types)
      _ = try await AgentRuntimeCommand.run(tar, arguments: ["-xzf", downloaded.path, "-C", staging.path], directory: staging)
      try AgentRuntimeArchive.validatePackage(at: staging, release: release)
      for path in ["bin/codex", "bin/codex-code-mode-host", "codex-path/rg", "codex-resources/zsh/bin/zsh"] {
        try manager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: staging.appendingPathComponent(path).path)
      }
      try await validate(staging.appendingPathComponent("bin/codex-code-mode-host"), nil)
    } else {
      let bin = staging.appendingPathComponent("bin")
      try manager.createDirectory(at: bin, withIntermediateDirectories: true)
      try manager.copyItem(at: downloaded, to: bin.appendingPathComponent("claude"))
      try manager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: bin.appendingPathComponent("claude").path)
    }
    let relative = "bin/" + release.provider.rawValue
    try await validate(staging.appendingPathComponent(relative), release.version)
    try Task.checkCancellation()
    let destination = releases.appendingPathComponent("\(release.version)-\(UUID().uuidString)")
    try manager.moveItem(at: staging, to: destination)
    var activated = false
    defer { if !activated { try? manager.removeItem(at: destination) } }
    let link = directory.appendingPathComponent(".current-\(UUID().uuidString)")
    defer { try? manager.removeItem(at: link) }
    try manager.createSymbolicLink(at: link, withDestinationURL: destination)
    try Task.checkCancellation()
    let current = directory.appendingPathComponent("current")
    let result = link.path.withCString { source in current.path.withCString { target in Darwin.rename(source, target) } }
    guard result == 0 else {
      throw AgentRuntimeUpdateError("Could not activate the verified runtime. The previous version is still installed.")
    }
    activated = true
    return destination.appendingPathComponent(relative).standardizedFileURL
  }

  private func checksum(_ url: URL) throws -> String {
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    var hash = SHA256()
    while let chunk = try handle.read(upToCount: 1024 * 1024), !chunk.isEmpty {
      try Task.checkCancellation()
      hash.update(data: chunk)
    }
    return hash.finalize().map { String(format: "%02x", $0) }.joined()
  }
}

enum AgentManagedRuntimeLocation {
  static var root: URL { AppShowPaths.home.appendingPathComponent("agents/runtimes", isDirectory: true) }

  static func current(_ provider: AgentProviderKind, root: URL) -> URL? {
    let url = root.appendingPathComponent("\(provider.rawValue)/current/bin/\(provider.rawValue)").resolvingSymlinksInPath()
      .standardizedFileURL
    let releases = root.appendingPathComponent("\(provider.rawValue)/releases").resolvingSymlinksInPath().standardizedFileURL
    guard url.path.hasPrefix(releases.path + "/"), FileManager.default.isExecutableFile(atPath: url.path) else { return nil }
    return url
  }

}
#endif
