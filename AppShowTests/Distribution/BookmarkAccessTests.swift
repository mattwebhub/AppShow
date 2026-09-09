import Foundation
import Synchronization
import Testing

@testable import AppShow

@MainActor
struct BookmarkAccessTests {
  @Test func persistedBookmarkResolvesMovedURLAndRefreshesWhileAccessIsHeld() throws {
    let root = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(root) }
    let file = root.appendingPathComponent("bookmarks.json")
    let original = root.appendingPathComponent("original")
    let moved = root.appendingPathComponent("moved")
    let events = Mutex<[String]>([])
    let operations = BookmarkOperations(
      create: { url in
        events.withLock { $0.append("bookmark:\(url.lastPathComponent)") }; return Data(url.path.utf8)
      },
      resolve: { _ in (moved, true) },
      start: { url in
        events.withLock { $0.append("start:\(url.lastPathComponent)") }; return true
      },
      stop: { url in events.withLock { $0.append("stop:\(url.lastPathComponent)") } }
    )
    var store: BookmarkAccessStore? = try BookmarkAccessStore(fileURL: file, operations: operations)
    try store?.remember(original, key: "projects")
    store = nil
    #expect(events.withLock { $0 } == ["start:original", "bookmark:original", "stop:original"])
    store = try BookmarkAccessStore(fileURL: file, operations: operations)
    #expect(try store?.resolve(key: "projects", fallback: original) == moved)
    #expect(try store?.resolve(key: "projects", fallback: original) == moved)
    let data = try JSONDecoder().decode([String: Data].self, from: Data(contentsOf: file))
    #expect(data["projects"] == Data(moved.path.utf8))
    #expect(events.withLock { $0.suffix(2) } == ["start:moved", "bookmark:moved"])
    store = nil
    #expect(events.withLock { $0.last } == "stop:moved")
  }

  @Test func revokedAccessFailsWithoutUsingTheOldPathOrReplacingBookmark() throws {
    let root = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(root) }
    let file = root.appendingPathComponent("bookmarks.json")
    let original = try JSONEncoder().encode(["projects": Data("saved grant".utf8)])
    try original.write(to: file)
    let events = Mutex<[String]>([])
    let store = try BookmarkAccessStore(
      fileURL: file,
      operations: BookmarkOperations(
        create: { _ in Data() },
        resolve: { _ in (root, true) },
        start: { _ in false },
        stop: { _ in events.withLock { $0.append("stop") } }
      )
    )
    #expect(throws: (any Error).self) { try store.resolve(key: "projects", fallback: root) }
    #expect(try Data(contentsOf: file) == original)
    #expect(events.withLock { $0.isEmpty })
  }

  @Test func failedPersistenceReleasesTheNewGrantAndPreservesThePreviousSelection() throws {
    let root = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(root) }
    let file = root.appendingPathComponent("bookmarks.json")
    let events = Mutex<[String]>([])
    let store = try BookmarkAccessStore(
      fileURL: file,
      operations: BookmarkOperations(
        create: { url in Data(url.path.utf8) },
        resolve: { data in (URL(fileURLWithPath: String(decoding: data, as: UTF8.self)), false) },
        start: { _ in true },
        stop: { url in events.withLock { $0.append(url.lastPathComponent) } }
      )
    )
    let old = root.appendingPathComponent("old")
    try store.remember(old, key: "projects")
    try FileManager.default.removeItem(at: file)
    try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)
    #expect(throws: (any Error).self) { try store.remember(root.appendingPathComponent("new"), key: "projects") }
    #expect(try store.resolve(key: "projects", fallback: root) == old)
    #expect(events.withLock { $0 } == ["new"])
  }
}
