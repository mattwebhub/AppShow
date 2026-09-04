import Foundation

enum ReframedPaths {
  static var home: URL {
    if let override = ProcessInfo.processInfo.environment["REFRAMED_HOME"] {
      return URL(fileURLWithPath: override, isDirectory: true)
    }
    return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".reframed", isDirectory: true)
  }

  static var temp: URL {
    if let override = ProcessInfo.processInfo.environment["REFRAMED_TMP"] {
      return URL(fileURLWithPath: override, isDirectory: true)
    }
    return URL(fileURLWithPath: "/tmp/Reframed", isDirectory: true)
  }
}
