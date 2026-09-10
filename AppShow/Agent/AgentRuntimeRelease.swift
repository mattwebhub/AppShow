#if !APP_STORE
import Foundation

struct AgentRuntimeUpdateError: LocalizedError, Sendable {
  let message: String
  init(_ message: String) { self.message = message }
  var errorDescription: String? { message }
}

struct AgentRuntimeRelease: Equatable, Sendable {
  var provider: AgentProviderKind
  var version: String
  var downloadURL: URL
  var sha256: String
  var architecture: String

  static var currentArchitecture: String {
    #if arch(arm64)
    "arm64"
    #else
    "x86_64"
    #endif
  }

  var target: String { architecture == "arm64" ? "aarch64" : "x86_64" }

  func validate() throws {
    guard AgentRuntimeVersion.components(version) != nil,
      ["arm64", "x86_64"].contains(architecture),
      sha256.count == 64, sha256.allSatisfy({ $0.isHexDigit && $0.isASCII }),
      downloadURL.scheme == "https", downloadURL.user == nil, downloadURL.password == nil,
      downloadURL.port == nil, downloadURL.query == nil, downloadURL.fragment == nil
    else { throw AgentRuntimeUpdateError("The provider release metadata is invalid.") }
    let expected: String
    switch provider {
    case .codex:
      expected = "https://github.com/openai/codex/releases/download/rust-v\(version)/codex-package-\(target)-apple-darwin.tar.gz"
    case .claudeCode:
      let platform = architecture == "arm64" ? "arm64" : "x64"
      expected = "https://downloads.claude.ai/claude-code-releases/\(version)/darwin-\(platform)/claude"
    }
    guard downloadURL.absoluteString == expected else {
      throw AgentRuntimeUpdateError("The runtime download is not the selected official release.")
    }
  }

  static func codex(data: Data, architecture: String) throws -> Self {
    struct Response: Decodable {
      struct Asset: Decodable { var name: String; var browser_download_url: URL; var digest: String? }
      var tag_name: String
      var prerelease: Bool
      var draft: Bool
      var assets: [Asset]
    }
    let response = try JSONDecoder().decode(Response.self, from: data)
    let target = architecture == "arm64" ? "aarch64" : "x86_64"
    guard response.tag_name.hasPrefix("rust-v"), !response.prerelease, !response.draft,
      let asset = response.assets.first(where: { $0.name == "codex-package-\(target)-apple-darwin.tar.gz" }),
      let digest = asset.digest, digest.hasPrefix("sha256:")
    else { throw AgentRuntimeUpdateError("A verified stable Codex package is unavailable.") }
    let release = Self(
      provider: .codex,
      version: String(response.tag_name.dropFirst(6)),
      downloadURL: asset.browser_download_url,
      sha256: String(digest.dropFirst(7)).lowercased(),
      architecture: architecture
    )
    try release.validate()
    return release
  }

  static func claude(version: String, manifest: Data, architecture: String) throws -> Self {
    struct Manifest: Decodable {
      struct Platform: Decodable { var checksum: String }
      var platforms: [String: Platform]
    }
    guard AgentRuntimeVersion.components(version) != nil else {
      throw AgentRuntimeUpdateError("Claude returned an invalid stable version.")
    }
    let platform = "darwin-" + (architecture == "arm64" ? "arm64" : "x64")
    guard let checksum = try JSONDecoder().decode(Manifest.self, from: manifest).platforms[platform]?.checksum else {
      throw AgentRuntimeUpdateError("Claude's official release checksum is unavailable.")
    }
    let release = Self(
      provider: .claudeCode,
      version: version,
      downloadURL: URL(string: "https://downloads.claude.ai/claude-code-releases/\(version)/\(platform)/claude")!,
      sha256: checksum.lowercased(),
      architecture: architecture
    )
    try release.validate()
    return release
  }
}

enum AgentRuntimeVersion {
  static func components(_ version: String) -> [Int]? {
    let parts = version.split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count == 3,
      parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy({ $0.isASCII && $0.isNumber }) && ($0 == "0" || !$0.hasPrefix("0")) })
    else { return nil }
    let numbers = parts.compactMap { Int($0) }
    return numbers.count == 3 ? numbers : nil
  }

  static func isOlder(_ version: String, than other: String) -> Bool {
    guard let first = components(version), let second = components(other) else { return false }
    return first.lexicographicallyPrecedes(second)
  }
}

struct AgentRuntimeCompatibility: Sendable {
  var minimum: [AgentProviderKind: String] = [.codex: "0.153.3", .claudeCode: "2.1.263"]
  var blocked: [AgentProviderKind: Set<String>] = [:]

  func allows(_ version: String, for provider: AgentProviderKind) -> Bool {
    guard AgentRuntimeVersion.components(version) != nil, blocked[provider]?.contains(version) != true else { return false }
    return minimum[provider].map { !AgentRuntimeVersion.isOlder(version, than: $0) } ?? true
  }
}

struct AgentRuntimeCandidate: Equatable, Sendable {
  var executable: URL
  var version: String
}

enum AgentRuntimeSelection {
  static func newest(
    urls: [URL],
    provider: AgentProviderKind,
    compatibility: AgentRuntimeCompatibility? = nil,
    probe: @Sendable (URL) async -> AgentVersionStatus
  ) async -> AgentRuntimeCandidate? {
    var selected: AgentRuntimeCandidate?
    for url in urls {
      guard !Task.isCancelled else { return nil }
      guard case .available(let version) = await probe(url), AgentRuntimeVersion.components(version) != nil,
        compatibility?.allows(version, for: provider) != false
      else { continue }
      if selected == nil || AgentRuntimeVersion.isOlder(selected!.version, than: version) {
        selected = .init(executable: url, version: version)
      }
    }
    return selected
  }
}
#endif
