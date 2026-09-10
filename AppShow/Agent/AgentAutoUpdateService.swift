#if !APP_STORE
import Foundation
import Observation

struct AgentUpdatePreferences: Codable {
  var enabled = true
  var lastCheckedAt: Date?
}

enum AgentAutoUpdateOutcome: Equatable {
  case checking
  case updating(String)
  case notInstalled
  case current(String)
  case updated(String)
  case blocked(String)
  case cancelled
  case failed(String)

  var label: String {
    switch self {
    case .checking: "Checking for updates…"
    case .updating(let version): "Downloading and verifying \(version)…"
    case .notInstalled: "Not installed"
    case .current(let version): "Up to date · \(version)"
    case .updated(let version): "Updated to \(version)"
    case .blocked(let version): "Version \(version) is outside AppShow's compatibility policy."
    case .cancelled: "Update cancelled. The installed version is available."
    case .failed(let reason): "Update failed: \(reason)"
    }
  }

  var shouldRetry: Bool {
    switch self {
    case .failed, .cancelled: true
    default: false
    }
  }
}

@Observable @MainActor
final class AgentAutoUpdateService {
  typealias Installed = @MainActor (AgentProviderKind) async -> AgentRuntimeCandidate?
  typealias Latest = @MainActor (AgentProviderKind) async throws -> AgentRuntimeRelease
  typealias Install = @MainActor (AgentRuntimeRelease) async throws -> URL

  static let shared = makeLive()

  private static func makeLive() -> AgentAutoUpdateService {
    let installer = AgentRuntimeInstaller(
      root: AgentManagedRuntimeLocation.root,
      download: { @Sendable url in try await AgentRuntimeNetwork.download(url) },
      validate: { @Sendable url, version in try await AgentRuntimeCommand.validate(url, version: version) }
    )
    return AgentAutoUpdateService(
      preferencesURL: AppShowPaths.home.appendingPathComponent("agents/runtime-updates.json"),
      compatibility: AgentRuntimeCompatibility(),
      installed: { provider in await AgentToolchain.standard().bestProvider(provider, compatibility: nil) },
      latest: { try await AgentRuntimeNetwork.latest($0) },
      install: { try await installer.install($0) }
    )
  }

  var isEnabled: Bool {
    didSet {
      persist()
      if isEnabled { start() } else { stop() }
    }
  }
  private(set) var isRunning = false
  private(set) var lastCheckedAt: Date?
  private(set) var outcomes: [AgentProviderKind: AgentAutoUpdateOutcome] = [:]
  private(set) var revision = 0
  private(set) var persistenceError: String?
  private let preferencesURL: URL
  private let compatibility: AgentRuntimeCompatibility
  private let installed: Installed
  private let latest: Latest
  private let install: Install
  private var loopTask: Task<Void, Never>?
  private var updateTask: Task<Void, Never>?

  init(
    preferencesURL: URL,
    compatibility: AgentRuntimeCompatibility = .init(),
    installed: @escaping Installed,
    latest: @escaping Latest,
    install: @escaping Install
  ) {
    self.preferencesURL = preferencesURL
    self.compatibility = compatibility
    self.installed = installed
    self.latest = latest
    self.install = install
    let preferences =
      (try? Data(contentsOf: preferencesURL)).flatMap { try? JSONDecoder().decode(AgentUpdatePreferences.self, from: $0) } ?? .init()
    isEnabled = preferences.enabled
    lastCheckedAt = preferences.lastCheckedAt
  }

  func start() {
    guard !LaunchEnvironment.isTestHost, isEnabled, loopTask == nil else { return }
    loopTask = Task { [weak self] in
      while !Task.isCancelled {
        await self?.runIfDue()
        do { try await Task.sleep(for: .seconds(6 * 60 * 60)) } catch { break }
      }
    }
  }

  func stop() {
    loopTask?.cancel()
    loopTask = nil
    updateTask?.cancel()
  }

  func runIfDue(now: Date = Date()) async {
    guard isEnabled, !Task.isCancelled,
      lastCheckedAt.map({ now.timeIntervalSince($0) >= 24 * 60 * 60 || now < $0 }) ?? true
    else { return }
    await runNow(now: now)
  }

  func runNow(providers: [AgentProviderKind] = AgentProviderKind.allCases, installMissing: Bool = false, now: Date = Date()) async {
    guard !isRunning, !Task.isCancelled else { return }
    isRunning = true
    let task = Task {
      for provider in providers {
        guard !Task.isCancelled else { outcomes[provider] = .cancelled; break }
        outcomes[provider] = .checking
        outcomes[provider] = await update(provider, installMissing: installMissing)
      }
      if !Task.isCancelled, Set(providers) == Set(AgentProviderKind.allCases),
        providers.allSatisfy({ outcomes[$0]?.shouldRetry == false })
      {
        lastCheckedAt = now
        persist()
      }
    }
    updateTask = task
    await task.value
    updateTask = nil
    isRunning = false
  }

  private func update(_ provider: AgentProviderKind, installMissing: Bool) async -> AgentAutoUpdateOutcome {
    let current = await installed(provider)
    guard current != nil || installMissing else { return .notInstalled }
    do {
      try Task.checkCancellation()
      let release = try await latest(provider)
      try Task.checkCancellation()
      try release.validate()
      guard release.provider == provider else { throw AgentRuntimeUpdateError("The release belongs to a different provider.") }
      if let current, !AgentRuntimeVersion.isOlder(current.version, than: release.version) {
        return compatibility.allows(current.version, for: provider) ? .current(current.version) : .blocked(current.version)
      }
      guard compatibility.allows(release.version, for: provider) else { return .blocked(release.version) }
      outcomes[provider] = .updating(release.version)
      _ = try await install(release)
      revision += 1
      return .updated(release.version)
    } catch {
      return Task.isCancelled ? .cancelled : .failed(error.localizedDescription)
    }
  }

  private func persist() {
    do {
      try FileManager.default.createDirectory(at: preferencesURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      let data = try JSONEncoder().encode(AgentUpdatePreferences(enabled: isEnabled, lastCheckedAt: lastCheckedAt))
      try data.write(to: preferencesURL, options: .atomic)
      persistenceError = nil
    } catch {
      persistenceError = "Could not save the automatic update preference."
    }
  }
}
#endif
