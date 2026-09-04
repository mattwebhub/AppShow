import Foundation

struct AgentThreadStore: Sendable {
  let directory: URL

  init(directory: URL) {
    self.directory = directory
  }

  init(project: ReframedProject) {
    directory = project.agentDirectory.appendingPathComponent("threads", isDirectory: true)
  }

  func fileURL(for id: UUID) -> URL {
    directory.appendingPathComponent("\(id.uuidString).json")
  }

  func list() throws -> [AgentThreadData] {
    guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
    let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
    let threads = files.filter { $0.pathExtension == "json" }.compactMap { url -> AgentThreadData? in
      guard let data = try? Data(contentsOf: url) else { return nil }
      return try? Self.decoder.decode(AgentThreadData.self, from: data)
    }
    return threads.sorted { $0.lastActivityAt > $1.lastActivityAt }
  }

  func load(id: UUID) throws -> AgentThreadData? {
    let url = fileURL(for: id)
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    return try Self.decoder.decode(AgentThreadData.self, from: Data(contentsOf: url))
  }

  func save(_ thread: AgentThreadData) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let data = try Self.encoder.encode(thread)
    try data.write(to: fileURL(for: thread.id), options: .atomic)
  }

  func create(title: String, provider: AgentProviderKind) throws -> AgentThreadData {
    let thread = AgentThreadData(title: title, provider: provider)
    try save(thread)
    return thread
  }

  func rename(id: UUID, to title: String) throws -> AgentThreadData? {
    guard var thread = try load(id: id) else { return nil }
    thread.title = title
    try save(thread)
    return thread
  }

  func delete(id: UUID) throws {
    let url = fileURL(for: id)
    guard FileManager.default.fileExists(atPath: url.path) else { return }
    try FileManager.default.removeItem(at: url)
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
