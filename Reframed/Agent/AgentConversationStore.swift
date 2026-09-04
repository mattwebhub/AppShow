import Foundation

struct AgentConversationStore: Sendable {
  let directory: URL

  var fileURL: URL {
    directory.appendingPathComponent("conversation.json")
  }

  private var legacyThreadsDirectory: URL {
    directory.appendingPathComponent("threads", isDirectory: true)
  }

  init(directory: URL) {
    self.directory = directory
  }

  init(project: ReframedProject) {
    directory = project.agentDirectory
  }

  func load() throws -> AgentConversationData? {
    if FileManager.default.fileExists(atPath: fileURL.path) {
      return try Self.decoder.decode(AgentConversationData.self, from: Data(contentsOf: fileURL))
    }
    guard let migrated = try loadNewestLegacyThread() else { return nil }
    try save(migrated)
    try? FileManager.default.removeItem(at: legacyThreadsDirectory)
    return migrated
  }

  func save(_ conversation: AgentConversationData) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Self.encoder.encode(conversation).write(to: fileURL, options: .atomic)
  }

  func clear() throws {
    if FileManager.default.fileExists(atPath: fileURL.path) {
      try FileManager.default.removeItem(at: fileURL)
    }
    if FileManager.default.fileExists(atPath: legacyThreadsDirectory.path) {
      try FileManager.default.removeItem(at: legacyThreadsDirectory)
    }
  }

  private func loadNewestLegacyThread() throws -> AgentConversationData? {
    guard FileManager.default.fileExists(atPath: legacyThreadsDirectory.path) else { return nil }
    let files = try FileManager.default.contentsOfDirectory(at: legacyThreadsDirectory, includingPropertiesForKeys: nil)
    return
      files
      .filter { $0.pathExtension == "json" }
      .compactMap { try? Self.decoder.decode(AgentConversationData.self, from: Data(contentsOf: $0)) }
      .max { $0.lastActivityAt < $1.lastActivityAt }
  }

  private static var encoder: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return encoder
  }

  private static var decoder: JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }
}
