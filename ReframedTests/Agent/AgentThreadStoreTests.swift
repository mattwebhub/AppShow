import Foundation
import Testing

@testable import Reframed

@Suite(.serialized)
struct AgentThreadStoreTests {
  private func makeProject(in dir: URL) async throws -> ReframedProject {
    let sources = dir.appendingPathComponent("sources", isDirectory: true)
    try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)
    let result = try await ProjectFixtures.recordingResult(in: sources, webcam: false, systemAudio: false, microphone: false, cursor: false)
    let projects = dir.appendingPathComponent("projects", isDirectory: true)
    return try ReframedProject.create(from: result, fps: result.fps, captureMode: .entireScreen, in: projects, cleanupTemp: false)
  }

  private func sampleThread(title: String = "Sample", activity: Date = Date()) -> AgentThreadData {
    var thread = AgentThreadData(title: title, provider: .codex)
    thread.sessionID = "019f-session"
    thread.lastActivityAt = activity
    thread.messages = [
      AgentMessageData(role: .user, content: [.text("hello")]),
      AgentMessageData(
        role: .assistant,
        content: [
          .text("hi"),
          .toolCall(AgentToolCallData(callID: "item_1", name: "Bash", input: "ls", output: "a\nb\n", status: .completed)),
        ],
        status: .completed
      ),
    ]
    return thread
  }

  @Test func createWritesAThreadFileUnderTheDirectory() throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let store = AgentThreadStore(directory: dir.appendingPathComponent("agent/threads", isDirectory: true))
    let thread = try store.create(title: "First", provider: .claudeCode)
    #expect(thread.title == "First")
    #expect(thread.provider == .claudeCode)
    #expect(thread.messages.isEmpty)
    #expect(thread.sessionID == nil)
    let file = dir.appendingPathComponent("agent/threads/\(thread.id.uuidString).json")
    #expect(FileManager.default.fileExists(atPath: file.path))
    #expect(store.fileURL(for: thread.id) == file)
  }

  @Test func threadRoundTripsThroughJsonWithSortedKeysAndIso8601Dates() throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let store = AgentThreadStore(directory: dir)
    let thread = sampleThread()
    try store.save(thread)
    let text = try String(contentsOf: store.fileURL(for: thread.id), encoding: .utf8)
    #expect(text.contains("\"createdAt\" : \"20"))
    #expect(text.range(of: "\"createdAt\"")!.lowerBound < text.range(of: "\"messages\"")!.lowerBound)
    let loaded = try store.load(id: thread.id)
    #expect(loaded?.id == thread.id)
    #expect(loaded?.title == thread.title)
    #expect(loaded?.provider == .codex)
    #expect(loaded?.sessionID == "019f-session")
    #expect(loaded?.messages == thread.messages)
    #expect(loaded.map { abs($0.createdAt.timeIntervalSince(thread.createdAt)) < 1 } == true)
  }

  @Test func listReturnsThreadsNewestActivityFirst() throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let store = AgentThreadStore(directory: dir)
    let older = sampleThread(title: "older", activity: Date(timeIntervalSince1970: 1_000))
    let newer = sampleThread(title: "newer", activity: Date(timeIntervalSince1970: 2_000))
    try store.save(older)
    try store.save(newer)
    #expect(try store.list().map(\.title) == ["newer", "older"])
  }

  @Test func listSkipsFilesThatDoNotDecode() throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let store = AgentThreadStore(directory: dir)
    try store.save(sampleThread(title: "good"))
    try "not json".write(to: dir.appendingPathComponent("garbage.json"), atomically: true, encoding: .utf8)
    try "note".write(to: dir.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)
    #expect(try store.list().map(\.title) == ["good"])
  }

  @Test func listOnAMissingDirectoryIsEmpty() throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let store = AgentThreadStore(directory: dir.appendingPathComponent("missing/threads", isDirectory: true))
    #expect(try store.list().isEmpty)
  }

  @Test func renameUpdatesTitleAndPersistsIt() throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let store = AgentThreadStore(directory: dir)
    let thread = try store.create(title: "Old", provider: .codex)
    let renamed = try store.rename(id: thread.id, to: "New")
    #expect(renamed?.title == "New")
    #expect(try store.load(id: thread.id)?.title == "New")
    #expect(try store.rename(id: UUID(), to: "Nothing") == nil)
  }

  @Test func deleteRemovesTheFile() throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let store = AgentThreadStore(directory: dir)
    let thread = try store.create(title: "Gone", provider: .codex)
    try store.delete(id: thread.id)
    #expect(!FileManager.default.fileExists(atPath: store.fileURL(for: thread.id).path))
    #expect(try store.list().isEmpty)
    try store.delete(id: thread.id)
  }

  @Test func legacyThreadWithoutProviderOrMessagesDecodesWithDefaults() throws {
    let json = """
      {"id":"00000000-0000-0000-0000-000000000001","title":"Legacy","createdAt":"2026-09-04T09:00:00Z","lastActivityAt":"2026-09-04T09:00:00Z"}
      """
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let thread = try decoder.decode(AgentThreadData.self, from: Data(json.utf8))
    #expect(thread.provider == .claudeCode)
    #expect(thread.messages.isEmpty)
    #expect(thread.sessionID == nil)
  }

  @Test func messageContentWithUnknownTypeDecodesAsText() throws {
    let json = """
      {"id":"00000000-0000-0000-0000-000000000002","role":"assistant","content":[{"type":"hologram","text":"beam"},{"type":"text","text":"ok"}],"status":"completed","createdAt":"2026-09-04T09:00:00Z"}
      """
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let message = try decoder.decode(AgentMessageData.self, from: Data(json.utf8))
    #expect(message.content == [.text("beam"), .text("ok")])
    #expect(message.status == .completed)
  }

  @Test func storeInsideAProjectBundleMovesWithTheProjectOnRename() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    var project = try await makeProject(in: dir)
    #expect(project.agentDirectory == project.bundleURL.appendingPathComponent("agent", isDirectory: true))
    let store = AgentThreadStore(project: project)
    #expect(store.directory == project.agentDirectory.appendingPathComponent("threads", isDirectory: true))
    let thread = try store.create(title: "In bundle", provider: .claudeCode)
    let oldFile = store.fileURL(for: thread.id)
    #expect(FileManager.default.fileExists(atPath: oldFile.path))
    try project.rename(to: "Renamed Project")
    #expect(!FileManager.default.fileExists(atPath: oldFile.path))
    let movedStore = AgentThreadStore(project: project)
    #expect(try movedStore.list().map(\.title) == ["In bundle"])
    #expect(movedStore.fileURL(for: thread.id).path.contains("Renamed Project.frm/agent/threads/"))
  }
}
