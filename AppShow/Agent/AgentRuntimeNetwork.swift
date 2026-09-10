#if !APP_STORE
import Foundation

enum AgentRuntimeNetwork {
  private static let session: URLSession = {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 60
    configuration.timeoutIntervalForResource = 15 * 60
    return URLSession(configuration: configuration)
  }()

  static func latest(_ provider: AgentProviderKind) async throws -> AgentRuntimeRelease {
    let architecture = AgentRuntimeRelease.currentArchitecture
    if provider == .codex {
      return try await AgentRuntimeRelease.codex(
        data: metadata("https://api.github.com/repos/openai/codex/releases/latest"),
        architecture: architecture
      )
    }
    let data = try await metadata("https://downloads.claude.ai/claude-code-releases/latest")
    let version = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    guard AgentRuntimeVersion.components(version) != nil else {
      throw AgentRuntimeUpdateError("Claude returned an invalid stable version.")
    }
    return try await AgentRuntimeRelease.claude(
      version: version,
      manifest: metadata("https://downloads.claude.ai/claude-code-releases/\(version)/manifest.json"),
      architecture: architecture
    )
  }

  private static func metadata(_ address: String) async throws -> Data {
    let (data, response) = try await session.data(for: request(URL(string: address)!))
    try validate(response)
    guard data.count <= 4 * 1024 * 1024 else { throw AgentRuntimeUpdateError("Release metadata exceeded the size limit.") }
    return data
  }

  static func download(_ url: URL) async throws -> URL {
    let (file, response) = try await session.download(for: request(url))
    do {
      try validate(response)
      let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
      guard size > 0, size <= 2 * 1024 * 1024 * 1024 else { throw AgentRuntimeUpdateError("The runtime download has an unexpected size.") }
      return file
    } catch {
      try? FileManager.default.removeItem(at: file)
      throw error
    }
  }

  private static func request(_ url: URL) -> URLRequest {
    var request = URLRequest(url: url)
    request.setValue("AppShow-runtime-updater/1.0", forHTTPHeaderField: "User-Agent")
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    return request
  }

  private static func validate(_ response: URLResponse) throws {
    guard let http = response as? HTTPURLResponse, http.statusCode == 200, http.url?.scheme == "https" else {
      throw AgentRuntimeUpdateError("The provider download failed. Try again when the connection is available.")
    }
  }
}
#endif
