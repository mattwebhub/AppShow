import Foundation

struct BookmarkOperations: Sendable {
  var create: @Sendable (URL) throws -> Data
  var resolve: @Sendable (Data) throws -> (url: URL, stale: Bool)
  var start: @Sendable (URL) -> Bool
  var stop: @Sendable (URL) -> Void

  static let live = BookmarkOperations(
    create: { try $0.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) },
    resolve: { data in
      var stale = false
      let url = try URL(
        resolvingBookmarkData: data,
        options: [.withSecurityScope, .withoutUI],
        relativeTo: nil,
        bookmarkDataIsStale: &stale
      )
      return (url, stale)
    },
    start: { $0.startAccessingSecurityScopedResource() },
    stop: { $0.stopAccessingSecurityScopedResource() }
  )
}

final class SecurityScopedAccess: Sendable {
  let url: URL
  let isActive: Bool
  private let stop: @Sendable (URL) -> Void

  init(
    url: URL,
    start: @Sendable (URL) -> Bool = { AppDistribution.isStore && $0.startAccessingSecurityScopedResource() },
    stop: @escaping @Sendable (URL) -> Void = { $0.stopAccessingSecurityScopedResource() }
  ) {
    self.url = url
    self.stop = stop
    isActive = start(url)
  }

  deinit {
    if isActive { stop(url) }
  }
}

@MainActor
final class BookmarkAccessStore {
  static let shared = try? BookmarkAccessStore(fileURL: AppShowPaths.home.appendingPathComponent("bookmarks.json"))

  private let fileURL: URL
  private let operations: BookmarkOperations
  private var bookmarks: [String: Data]
  private var resolved: [String: URL] = [:]
  private var access: [String: SecurityScopedAccess] = [:]

  init(fileURL: URL, operations: BookmarkOperations = .live) throws {
    self.fileURL = fileURL
    self.operations = operations
    if FileManager.default.fileExists(atPath: fileURL.path) {
      bookmarks = try JSONDecoder().decode([String: Data].self, from: Data(contentsOf: fileURL))
    } else {
      bookmarks = [:]
    }
  }

  func remember(_ url: URL, key: String) throws {
    let lease = access[url.path] ?? SecurityScopedAccess(url: url, start: operations.start, stop: operations.stop)
    defer { withExtendedLifetime(lease) {} }
    var updated = bookmarks
    updated[key] = try operations.create(url)
    try persist(updated)
    bookmarks = updated
    resolved[key] = url
    access[url.path] = lease
  }

  func resolve(key: String, fallback: URL) throws -> URL {
    if let url = resolved[key] { return url }
    guard let data = bookmarks[key] else { return fallback }
    let result = try operations.resolve(data)
    let lease = access[result.url.path] ?? SecurityScopedAccess(url: result.url, start: operations.start, stop: operations.stop)
    defer { withExtendedLifetime(lease) {} }
    guard lease.isActive else { throw CocoaError(.fileReadNoPermission) }
    if result.stale {
      var updated = bookmarks
      updated[key] = try operations.create(result.url)
      try persist(updated)
      bookmarks = updated
    }
    resolved[key] = result.url
    access[result.url.path] = lease
    return result.url
  }

  static func required() throws -> BookmarkAccessStore {
    guard let shared else { throw CocoaError(.fileReadCorruptFile) }
    return shared
  }

  private func persist(_ updated: [String: Data]) throws {
    try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONEncoder().encode(updated).write(to: fileURL, options: .atomic)
  }
}
