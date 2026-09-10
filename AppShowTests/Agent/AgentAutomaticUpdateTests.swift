import CryptoKit
import Foundation
import Testing

@testable import AppShow

struct AgentAutomaticUpdateTests {
  @Test func releaseMetadataPinsTheCompleteCodexPackageAndRejectsUntrustedAssets() throws {
    let url = "https://github.com/openai/codex/releases/download/rust-v1.2.3/codex-package-aarch64-apple-darwin.tar.gz"
    func metadata(url: String, prerelease: Bool = false) throws -> Data {
      try JSONSerialization.data(withJSONObject: [
        "tag_name": "rust-v1.2.3", "prerelease": prerelease, "draft": false,
        "assets": [
          [
            "name": "codex-package-aarch64-apple-darwin.tar.gz", "browser_download_url": url,
            "digest": "sha256:" + String(repeating: "a", count: 64),
          ]
        ],
      ])
    }
    let release = try AgentRuntimeRelease.codex(data: metadata(url: url), architecture: "arm64")
    #expect(release.version == "1.2.3")
    #expect(release.downloadURL.absoluteString == url)
    #expect(throws: Error.self) {
      try AgentRuntimeRelease.codex(data: metadata(url: "https://invalid.example/runtime"), architecture: "arm64")
    }
    #expect(throws: Error.self) { try AgentRuntimeRelease.codex(data: metadata(url: url, prerelease: true), architecture: "arm64") }
  }

  @Test func archiveValidationRejectsTraversalLinksAndIncompletePackages() throws {
    let listing = AgentRuntimeArchive.entries.sorted().joined(separator: "\n")
    try AgentRuntimeArchive.validate(listing: listing, types: "drwxr-xr-x directory\n-rwxr-xr-x executable")
    #expect(throws: Error.self) { try AgentRuntimeArchive.validate(listing: listing + "\n../escape", types: "-rwxr-xr-x executable") }
    #expect(throws: Error.self) { try AgentRuntimeArchive.validate(listing: listing, types: "lrwxr-xr-x link -> /outside") }
    #expect(throws: Error.self) { try AgentRuntimeArchive.validate(listing: "bin/codex", types: "-rwxr-xr-x executable") }
  }

  @Test func selectionUsesNewestWorkingAllowedVersionAndPreservesCandidateOrderOnTies() async {
    let urls = ["managed", "broken", "user", "blocked"].map { URL(fileURLWithPath: "/fixture/\($0)") }
    let versions = ["managed": "1.2.1", "user": "1.3.0", "blocked": "2.0.0"]
    let policy = AgentRuntimeCompatibility(minimum: [:], blocked: [.codex: ["2.0.0"]])
    let result = await AgentRuntimeSelection.newest(urls: urls, provider: .codex, compatibility: policy) { url in
      versions[url.lastPathComponent].map(AgentVersionStatus.available) ?? .unavailable("broken")
    }
    #expect(result?.executable == urls[2])
    #expect(result?.version == "1.3.0")
    let tied = await AgentRuntimeSelection.newest(urls: urls, provider: .codex) { _ in .available("1.0.0") }
    #expect(tied?.executable == urls[0])
  }

  @Test func verifiedInstallSwitchesOnlyManagedPointerAndKeepsPreviousExecutable() async throws {
    let root = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(root) }
    let payload = root.appendingPathComponent("download")
    let userBinary = root.appendingPathComponent("user-claude")
    try Data("user installation".utf8).write(to: userBinary)
    try Data("first release".utf8).write(to: payload)
    let installer = AgentRuntimeInstaller(
      root: root.appendingPathComponent("managed"),
      download: { _ in try Self.copyDownload(payload) },
      validate: { _, _ in }
    )
    let first = try await installer.install(release(payload: payload, version: "2.0.0"))
    try Data("second release".utf8).write(to: payload)
    let second = try await installer.install(release(payload: payload, version: "2.0.1"))
    let current = root.appendingPathComponent("managed/claude/current/bin/claude")
    #expect(current.resolvingSymlinksInPath() == second)
    #expect(try String(contentsOf: first, encoding: .utf8) == "first release")
    #expect(try String(contentsOf: second, encoding: .utf8) == "second release")
    #expect(try String(contentsOf: userBinary, encoding: .utf8) == "user installation")
  }

  @Test func badChecksumAndFailedHealthCheckPreserveThePreviousRuntime() async throws {
    let root = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(root) }
    let payload = root.appendingPathComponent("download")
    try Data("verified".utf8).write(to: payload)
    let managed = root.appendingPathComponent("managed")
    let installer = AgentRuntimeInstaller(root: managed, download: { _ in try Self.copyDownload(payload) }, validate: { _, _ in })
    let first = try await installer.install(release(payload: payload, version: "2.0.0"))
    let bad = AgentRuntimeRelease(
      provider: .claudeCode,
      version: "2.0.1",
      downloadURL: URL(string: "https://downloads.claude.ai/claude-code-releases/2.0.1/darwin-arm64/claude")!,
      sha256: String(repeating: "0", count: 64),
      architecture: "arm64"
    )
    await #expect(throws: Error.self) { try await installer.install(bad) }
    let rejecting = AgentRuntimeInstaller(
      root: managed,
      download: { _ in try Self.copyDownload(payload) },
      validate: { _, _ in throw AgentRuntimeUpdateError("broken executable") }
    )
    await #expect(throws: Error.self) { try await rejecting.install(release(payload: payload, version: "2.0.1")) }
    #expect(managed.appendingPathComponent("claude/current/bin/claude").resolvingSymlinksInPath() == first)
    #expect(try String(contentsOf: first, encoding: .utf8) == "verified")
  }

  @Test func codexActivationIncludesItsMatchingHostAndPackageResources() async throws {
    let root = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(root) }
    let package = root.appendingPathComponent("package")
    try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
    for entry in AgentRuntimeArchive.entries.sorted() where entry.hasSuffix("/") {
      try FileManager.default.createDirectory(at: package.appendingPathComponent(entry), withIntermediateDirectories: true)
    }
    for entry in AgentRuntimeArchive.entries where !entry.hasSuffix("/") {
      try Data(entry.utf8).write(to: package.appendingPathComponent(entry))
    }
    let manifest: [String: Any] = [
      "layoutVersion": 1, "version": "1.0.1", "target": "aarch64-apple-darwin",
      "variant": "codex", "entrypoint": "bin/codex", "resourcesDir": "codex-resources", "pathDir": "codex-path",
    ]
    try JSONSerialization.data(withJSONObject: manifest).write(to: package.appendingPathComponent("codex-package.json"))
    let archive = root.appendingPathComponent("package.tar.gz")
    let tar = Process()
    tar.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
    tar.arguments = ["-czf", archive.path, "-C", package.path, "bin", "codex-package.json", "codex-path", "codex-resources"]
    tar.environment = ["PATH": "/usr/bin:/bin", "COPYFILE_DISABLE": "1"]
    tar.standardInput = FileHandle.nullDevice
    tar.standardOutput = FileHandle.nullDevice
    tar.standardError = FileHandle.nullDevice
    try tar.run()
    tar.waitUntilExit()
    #expect(tar.terminationStatus == 0)
    let checksum = SHA256.hash(data: try Data(contentsOf: archive)).map { String(format: "%02x", $0) }.joined()
    let release = AgentRuntimeRelease(
      provider: .codex,
      version: "1.0.1",
      downloadURL: URL(string: "https://github.com/openai/codex/releases/download/rust-v1.0.1/codex-package-aarch64-apple-darwin.tar.gz")!,
      sha256: checksum,
      architecture: "arm64"
    )
    let installer = AgentRuntimeInstaller(
      root: root.appendingPathComponent("managed"),
      download: { _ in try Self.copyDownload(archive) },
      validate: { _, _ in }
    )
    let executable = try await installer.install(release)
    let installed = executable.deletingLastPathComponent().deletingLastPathComponent()
    #expect(try String(contentsOf: executable, encoding: .utf8) == "bin/codex")
    #expect(
      try String(contentsOf: installed.appendingPathComponent("bin/codex-code-mode-host"), encoding: .utf8) == "bin/codex-code-mode-host"
    )
    #expect(FileManager.default.isExecutableFile(atPath: installed.appendingPathComponent("codex-path/rg").path))
    #expect(FileManager.default.isExecutableFile(atPath: installed.appendingPathComponent("codex-resources/zsh/bin/zsh").path))
  }

  @Test func cancellationAndConcurrentInstallDoNotReplaceTheWorkingRuntime() async throws {
    let root = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(root) }
    let payload = root.appendingPathComponent("payload")
    try Data("working".utf8).write(to: payload)
    let managed = root.appendingPathComponent("managed")
    let original = AgentRuntimeInstaller(root: managed, download: { _ in try Self.copyDownload(payload) }, validate: { _, _ in })
    let old = try await original.install(release(payload: payload, version: "2.0.0"))
    let gate = AgentUpdateTestGate()
    let installer = AgentRuntimeInstaller(
      root: managed,
      download: { _ in
        await gate.pause()
        return try Self.copyDownload(payload)
      },
      validate: { _, _ in }
    )
    let next = try release(payload: payload, version: "2.0.1")
    let operation = Task { try await installer.install(next) }
    await gate.waitForStart()
    await #expect(throws: Error.self) { try await installer.install(next) }
    operation.cancel()
    await gate.release()
    await #expect(throws: CancellationError.self) { try await operation.value }
    #expect(managed.appendingPathComponent("claude/current/bin/claude").resolvingSymlinksInPath() == old)
    #expect(try String(contentsOf: old, encoding: .utf8) == "working")
  }

  private static func copyDownload(_ source: URL) throws -> URL {
    let destination = source.deletingLastPathComponent().appendingPathComponent(UUID().uuidString)
    try FileManager.default.copyItem(at: source, to: destination)
    return destination
  }

  @Test func managedSelectionRefreshesBetweenTurnsWithoutLoadingShellProfiles() async throws {
    let root = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(root) }
    let managed = root.appendingPathComponent("managed")
    let provider = managed.appendingPathComponent("claude")
    let shell = root.appendingPathComponent("shell")
    try "#!/bin/sh\ntouch \"$HOME/shell-was-run\"\n".write(to: shell, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: shell.path)
    let toolchain = AgentToolchain(path: "", loginShell: shell, home: root, managedRoot: managed)
    var selected: [URL] = []
    for version in ["2.1.263", "2.1.264"] {
      let directory = provider.appendingPathComponent("releases/\(version)")
      let bin = directory.appendingPathComponent("bin")
      try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
      let executable = bin.appendingPathComponent("claude")
      try "#!/bin/sh\necho '\(version) (Claude Code)'\n".write(to: executable, atomically: true, encoding: .utf8)
      try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
      let current = provider.appendingPathComponent("current")
      if FileManager.default.fileExists(atPath: current.path) { try FileManager.default.removeItem(at: current) }
      try FileManager.default.createSymbolicLink(at: current, withDestinationURL: directory)
      let candidate = await toolchain.bestProvider(.claudeCode)
      #expect(candidate?.version == version)
      #expect(candidate?.executable == executable)
      if let executable = candidate?.executable { selected.append(executable) }
    }
    #expect(selected.count == 2)
    #expect(selected.first != selected.last)
    #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("shell-was-run").path))
    #expect(selected.allSatisfy { FileManager.default.isExecutableFile(atPath: $0.path) })
  }

  private func release(payload: URL, version: String) throws -> AgentRuntimeRelease {
    let hash = SHA256.hash(data: try Data(contentsOf: payload)).map { String(format: "%02x", $0) }.joined()
    return AgentRuntimeRelease(
      provider: .claudeCode,
      version: version,
      downloadURL: URL(string: "https://downloads.claude.ai/claude-code-releases/\(version)/darwin-arm64/claude")!,
      sha256: hash,
      architecture: "arm64"
    )
  }
}

@MainActor
private final class AgentUpdateTestServiceReference {
  weak var service: AgentAutoUpdateService?
}

private actor AgentUpdateTestGate {
  private var started = false
  private var startWaiter: CheckedContinuation<Void, Never>?
  private var releaseWaiter: CheckedContinuation<Void, Never>?

  func pause() async {
    started = true
    startWaiter?.resume()
    startWaiter = nil
    await withCheckedContinuation { releaseWaiter = $0 }
  }

  func waitForStart() async {
    if !started { await withCheckedContinuation { startWaiter = $0 } }
  }

  func release() {
    releaseWaiter?.resume()
    releaseWaiter = nil
  }
}

@MainActor
struct AgentAutoUpdateScheduleTests {
  @Test func checksDailyAndPassesTheExactVerifiedReleaseToInstallation() async throws {
    let root = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(root) }
    var installs = 0
    var lookups = 0
    let release = fixtureRelease()
    let service = AgentAutoUpdateService(
      preferencesURL: root.appendingPathComponent("preferences.json"),
      compatibility: .init(minimum: [:]),
      installed: { provider in
        provider == .codex ? .init(executable: root.appendingPathComponent("user/codex"), version: "1.0.0") : nil
      },
      latest: { _ in
        lookups += 1; return release
      },
      install: { selected in
        #expect(selected == release)
        installs += 1
        return root.appendingPathComponent("managed/codex")
      }
    )
    let now = Date(timeIntervalSince1970: 100_000)
    await service.runIfDue(now: now)
    await service.runIfDue(now: now.addingTimeInterval(3600))
    #expect(installs == 1)
    #expect(lookups == 1)
    #expect(service.lastCheckedAt == now)
    #expect(service.outcomes[.codex] == .updated("1.0.1"))
    await service.runIfDue(now: now.addingTimeInterval(24 * 3600))
    #expect(installs == 2)
  }

  @Test func failuresStayDueAndMissingProvidersDoNotTriggerAutomaticDownloads() async throws {
    let root = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(root) }
    var attempts = 0
    let service = AgentAutoUpdateService(
      preferencesURL: root.appendingPathComponent("preferences.json"),
      compatibility: .init(minimum: [:]),
      installed: { provider in
        provider == .codex ? .init(executable: root.appendingPathComponent("codex"), version: "1.0.0") : nil
      },
      latest: { _ in
        attempts += 1; throw AgentRuntimeUpdateError("offline")
      },
      install: { _ in
        Issue.record("Unexpected install"); return root
      }
    )
    await service.runIfDue()
    await service.runIfDue()
    #expect(attempts == 2)
    #expect(service.lastCheckedAt == nil)
    #expect(service.outcomes[.claudeCode] == .notInstalled)
  }

  @Test func disabledAndBlockedUpdatesNeverInstallAndPreferencePersists() async throws {
    let root = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(root) }
    let file = root.appendingPathComponent("preferences.json")
    var lookups = 0
    let service = AgentAutoUpdateService(
      preferencesURL: file,
      compatibility: .init(minimum: [:], blocked: [.codex: ["1.0.1"]]),
      installed: { _ in
        .init(executable: root.appendingPathComponent("codex"), version: "1.0.0")
      },
      latest: { _ in
        lookups += 1; return fixtureRelease()
      },
      install: { _ in
        Issue.record("Unexpected install"); return root
      }
    )
    service.isEnabled = false
    await service.runIfDue()
    #expect(lookups == 0)
    #expect(try JSONDecoder().decode(AgentUpdatePreferences.self, from: Data(contentsOf: file)).enabled == false)
    await service.runNow(providers: [.codex])
    #expect(service.outcomes[.codex] == .blocked("1.0.1"))
  }

  @Test func disablingDuringLookupPreventsActivation() async throws {
    let root = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(root) }
    let reference = AgentUpdateTestServiceReference()
    let service = AgentAutoUpdateService(
      preferencesURL: root.appendingPathComponent("preferences.json"),
      compatibility: .init(minimum: [:]),
      installed: { _ in
        .init(executable: root.appendingPathComponent("codex"), version: "1.0.0")
      },
      latest: { _ in
        reference.service?.isEnabled = false; return fixtureRelease()
      },
      install: { _ in
        Issue.record("Unexpected install"); return root
      }
    )
    reference.service = service
    await service.runNow(providers: [.codex])
    #expect(service.outcomes[.codex] == .cancelled)
    #expect(service.lastCheckedAt == nil)
  }

  @Test func newerWorkingUserInstallationDoesNotDowngradeToBlockedUpstream() async throws {
    let root = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(root) }
    let service = AgentAutoUpdateService(
      preferencesURL: root.appendingPathComponent("preferences.json"),
      compatibility: .init(minimum: [:], blocked: [.codex: ["1.0.1"]]),
      installed: { _ in .init(executable: root.appendingPathComponent("user-codex"), version: "1.0.2") },
      latest: { _ in fixtureRelease() },
      install: { _ in
        Issue.record("Must not downgrade"); return root
      }
    )
    await service.runNow(providers: [.codex])
    #expect(service.outcomes[.codex] == .current("1.0.2"))
  }

  @Test func explicitInstallWorksWithAutomaticUpdatesOffWithoutAdvancingOtherProvidersCheck() async throws {
    let root = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(root) }
    var installs = 0
    let service = AgentAutoUpdateService(
      preferencesURL: root.appendingPathComponent("preferences.json"),
      compatibility: .init(minimum: [:]),
      installed: { _ in nil },
      latest: { _ in fixtureRelease() },
      install: { _ in
        installs += 1; return root
      }
    )
    service.isEnabled = false
    await service.runNow(providers: [.codex], installMissing: true)
    #expect(installs == 1)
    #expect(!service.isEnabled)
    #expect(service.lastCheckedAt == nil)
    #expect(service.outcomes[.codex] == .updated("1.0.1"))
  }

  private func fixtureRelease() -> AgentRuntimeRelease {
    .init(
      provider: .codex,
      version: "1.0.1",
      downloadURL: URL(string: "https://github.com/openai/codex/releases/download/rust-v1.0.1/codex-package-aarch64-apple-darwin.tar.gz")!,
      sha256: String(repeating: "a", count: 64),
      architecture: "arm64"
    )
  }
}
