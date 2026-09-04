import CryptoKit
import Foundation

struct AgentWorkspaceSession: Codable, Sendable, Equatable {
  var socketPath: String
  var token: String
  var bundlePath: String
  var workspacePath: String
  var protocolVersion: String
  var createdAt: Date
}

struct AgentWorkspace: Sendable, Equatable {
  static let folderName = ".agent"
  static let sessionFileName = "session.json"
  static let socketFileName = "bridge.sock"
  static let framesFolderName = "frames"
  static let maxSocketPathLength = 100

  let bundleURL: URL
  let directory: URL
  let socketURL: URL
  let token: String

  var framesDirectory: URL {
    directory.appendingPathComponent(Self.framesFolderName, isDirectory: true)
  }

  var sessionFileURL: URL {
    directory.appendingPathComponent(Self.sessionFileName)
  }

  static func directory(forBundle bundleURL: URL) -> URL {
    bundleURL
      .deletingLastPathComponent()
      .appendingPathComponent(folderName, isDirectory: true)
      .appendingPathComponent(bundleURL.deletingPathExtension().lastPathComponent, isDirectory: true)
  }

  static func socketURL(
    forWorkspace directory: URL,
    fallbackRoot: URL = ReframedPaths.temp.appendingPathComponent("agent", isDirectory: true)
  ) -> URL {
    let preferred = directory.appendingPathComponent(socketFileName)
    if preferred.path.utf8.count <= maxSocketPathLength {
      return preferred
    }
    let digest = SHA256.hash(data: Data(directory.path.utf8))
    let name = digest.prefix(6).map { String(format: "%02x", $0) }.joined()
    return fallbackRoot.appendingPathComponent("\(name).sock")
  }

  static func generateToken() -> String {
    var generator = SystemRandomNumberGenerator()
    return (0..<32).map { _ in String(format: "%02x", UInt8.random(in: 0...255, using: &generator)) }.joined()
  }

  static func create(forBundle bundleURL: URL, token: String = generateToken()) throws -> AgentWorkspace {
    let fm = FileManager.default
    let directory = directory(forBundle: bundleURL)
    let workspace = AgentWorkspace(bundleURL: bundleURL, directory: directory, socketURL: socketURL(forWorkspace: directory), token: token)
    try fm.createDirectory(at: workspace.framesDirectory, withIntermediateDirectories: true)
    try fm.createDirectory(at: workspace.socketURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    let session = AgentWorkspaceSession(
      socketPath: workspace.socketURL.path,
      token: token,
      bundlePath: bundleURL.path,
      workspacePath: directory.path,
      protocolVersion: AgentToolCatalog.protocolVersion,
      createdAt: Date()
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(session).write(to: workspace.sessionFileURL, options: .atomic)
    try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: workspace.sessionFileURL.path)
    return workspace
  }

  static func readSession(in directory: URL) throws -> AgentWorkspaceSession {
    let data = try Data(contentsOf: directory.appendingPathComponent(sessionFileName))
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(AgentWorkspaceSession.self, from: data)
  }

  func close() {
    try? FileManager.default.removeItem(at: sessionFileURL)
    try? FileManager.default.removeItem(at: directory.appendingPathComponent(AgentSessionConfig.claudeConfigFileName))
    try? FileManager.default.removeItem(at: socketURL)
  }
}
