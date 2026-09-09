import Foundation

enum AppShowIdentity {
  static let name = "AppShow"
  static let bundleIdentifier = "com.mattwebhub.appshow"
  static let testBundleIdentifier = "com.mattwebhub.appshow.tests"
  static let projectTypeIdentifier = "com.mattwebhub.appshow.project"
  static let legacyProjectTypeIdentifier = "eu.jankuri.reframed.project"
  static let projectExtension = "appshow"
  static let legacyProjectExtension = "frm"
  static let supportedProjectExtensions = [projectExtension, legacyProjectExtension]
}

enum AppDistribution {
  #if APP_STORE
  static let isStore = true
  #else
  static let isStore = false
  #endif
}

enum AppShowPaths {
  static var home: URL {
    return resolveHome(
      environment: ProcessInfo.processInfo.environment,
      homeDirectory: FileManager.default.homeDirectoryForCurrentUser,
      sandboxed: AppDistribution.isStore
    )
  }

  static var temp: URL {
    return resolveTemp(environment: ProcessInfo.processInfo.environment, sandboxed: AppDistribution.isStore)
  }

  static func resolveTemp(
    environment: [String: String],
    sandboxed: Bool = false,
    temporaryDirectory: URL = FileManager.default.temporaryDirectory
  ) -> URL {
    if let override = environment["APPSHOW_TMP"] ?? environment["REFRAMED_TMP"] {
      return URL(fileURLWithPath: override, isDirectory: true)
    }
    if sandboxed { return temporaryDirectory.appendingPathComponent("AppShow", isDirectory: true) }
    return URL(fileURLWithPath: "/tmp/AppShow", isDirectory: true)
  }

  static func resolveHome(
    environment: [String: String],
    homeDirectory: URL,
    fileManager: FileManager = .default,
    sandboxed: Bool = false
  ) -> URL {
    if let override = environment["APPSHOW_HOME"] ?? environment["REFRAMED_HOME"] {
      return URL(fileURLWithPath: override, isDirectory: true)
    }

    if sandboxed { return homeDirectory.appendingPathComponent("Library/Application Support/AppShow", isDirectory: true) }

    let current = homeDirectory.appendingPathComponent(".appshow", isDirectory: true)
    let legacy = homeDirectory.appendingPathComponent(".reframed", isDirectory: true)
    if !fileManager.fileExists(atPath: current.path), fileManager.fileExists(atPath: legacy.path) {
      do {
        try fileManager.moveItem(at: legacy, to: current)
      } catch {
        return legacy
      }
    }
    migrateLegacyFiles(in: current, fileManager: fileManager)
    return current
  }

  private static func migrateLegacyFiles(in directory: URL, fileManager: FileManager) {
    let currentConfig = directory.appendingPathComponent("config.json")
    let legacyConfig = directory.appendingPathComponent("reframed.json")
    if !fileManager.fileExists(atPath: currentConfig.path), fileManager.fileExists(atPath: legacyConfig.path) {
      try? fileManager.moveItem(at: legacyConfig, to: currentConfig)
    }
  }
}
