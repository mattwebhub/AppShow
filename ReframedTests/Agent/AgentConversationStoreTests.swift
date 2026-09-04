import Foundation
import Testing

@testable import Reframed

@Suite(.serialized)
struct AgentConversationStoreTests {
  private func makeProject(in dir: URL) async throws -> ReframedProject {
    let sources = dir.appendingPathComponent("sources", isDirectory: true)
    try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)
    let result = try await ProjectFixtures.recordingResult(
      in: sources,
      webcam: false,
      systemAudio: false,
      microphone: false,
      cursor: false
    )
    let projects = dir.appendingPathComponent("projects", isDirectory: true)
    return try ReframedProject.create(
      from: result,
      fps: result.fps,
      captureMode: .entireScreen,
      in: projects,
      cleanupTemp: false
    )
  }

  private func sampleConversation(activity: Date = AgentTimestamp.now()) -> AgentConversationData {
    AgentConversationData(
      provider: .codex,
      resumeIDs: [.claudeCode: "claude-session", .codex: "codex-session"],
      createdAt: Date(timeIntervalSince1970: 1_000),
      lastActivityAt: activity,
      messages: [
        AgentMessageData(role: .user, content: [.text("hello")]),
        AgentMessageData(role: .assistant, content: [.text("hi")]),
      ]
    )
  }

  @Test func missingStoreLoadsNoConversation() throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let store = AgentConversationStore(directory: dir.appendingPathComponent("missing/agent", isDirectory: true))
    #expect(try store.load() == nil)
  }

  @Test func conversationRoundTripsThroughOneSortedJsonFile() throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let store = AgentConversationStore(directory: dir.appendingPathComponent("agent", isDirectory: true))
    let conversation = sampleConversation()

    try store.save(conversation)

    #expect(store.fileURL == dir.appendingPathComponent("agent/conversation.json"))
    let text = try String(contentsOf: store.fileURL, encoding: .utf8)
    #expect(text.contains("\"createdAt\" : \"1970"))
    #expect(text.range(of: "\"createdAt\"")!.lowerBound < text.range(of: "\"messages\"")!.lowerBound)
    let loadedValue = try store.load()
    let loaded = try #require(loadedValue)
    #expect(loaded == conversation)
    #expect(loaded.resumeID(for: .claudeCode) == "claude-session")
    #expect(loaded.resumeID(for: .codex) == "codex-session")
  }

  @Test func clearRemovesConversationAndIsIdempotent() throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let store = AgentConversationStore(directory: dir.appendingPathComponent("agent", isDirectory: true))
    try store.save(sampleConversation())

    try store.clear()
    try store.clear()

    #expect(!FileManager.default.fileExists(atPath: store.fileURL.path))
    #expect(try store.load() == nil)
  }

  @Test func legacyThreadMigratesToTheSingleConversationFile() throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let agentDirectory = dir.appendingPathComponent("agent", isDirectory: true)
    let threads = agentDirectory.appendingPathComponent("threads", isDirectory: true)
    try FileManager.default.createDirectory(at: threads, withIntermediateDirectories: true)
    let older = sampleConversation(activity: Date(timeIntervalSince1970: 2_000))
    var newer = sampleConversation(activity: Date(timeIntervalSince1970: 3_000))
    newer.messages = [AgentMessageData(role: .user, content: [.text("newest")])]
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    try encoder.encode(older).write(to: threads.appendingPathComponent("older.json"))
    try encoder.encode(newer).write(to: threads.appendingPathComponent("newer.json"))
    let store = AgentConversationStore(directory: agentDirectory)

    let migratedValue = try store.load()
    let migrated = try #require(migratedValue)

    #expect(migrated.messages.first?.text == "newest")
    #expect(FileManager.default.fileExists(atPath: store.fileURL.path))
    #expect(!FileManager.default.fileExists(atPath: threads.path))
  }

  @Test func legacySessionIdMovesIntoTheProviderResumeMap() throws {
    let json = """
      {"provider":"codex","sessionID":"legacy-session","messages":[]}
      """
    let conversation = try JSONDecoder().decode(AgentConversationData.self, from: Data(json.utf8))
    #expect(conversation.provider == .codex)
    #expect(conversation.resumeID(for: .codex) == "legacy-session")
  }

  @Test func messageContentWithUnknownTypeDecodesAsText() throws {
    let json = """
      {"role":"assistant","content":[{"type":"hologram","text":"beam"},{"type":"text","text":"ok"}],"status":"completed"}
      """
    let message = try JSONDecoder().decode(AgentMessageData.self, from: Data(json.utf8))
    #expect(message.content == [.text("beam"), .text("ok")])
  }

  @Test func storeInsideProjectBundleMovesWithProjectRename() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    var project = try await makeProject(in: dir)
    let store = AgentConversationStore(project: project)
    try store.save(sampleConversation())
    let oldFile = store.fileURL

    try project.rename(to: "Renamed Project")

    #expect(!FileManager.default.fileExists(atPath: oldFile.path))
    let movedStore = AgentConversationStore(project: project)
    #expect(try movedStore.load()?.messages.first?.text == "hello")
    #expect(movedStore.fileURL.path.hasSuffix("Renamed Project.frm/agent/conversation.json"))
  }
}
