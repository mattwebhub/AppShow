import Foundation
import Testing

@testable import Reframed

struct ReframedPathsTests {
  private let realHome = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".reframed", isDirectory: true)

  @Test func homeIsRedirectedAwayFromRealConfigDirectory() {
    let home = ReframedPaths.home
    #expect(home.standardizedFileURL != realHome.standardizedFileURL, "home=\(home.path)")
    #expect(!home.path.contains("$("), "unexpanded build setting in \(home.path)")
    #expect(FileManager.default.fileExists(atPath: home.path), "host launch should have created \(home.path)")
  }

  @Test func tempIsRedirectedAwayFromSharedTempDirectory() {
    let temp = ReframedPaths.temp
    #expect(temp.path != "/tmp/Reframed", "temp=\(temp.path)")
    #expect(!temp.path.contains("$("), "unexpanded build setting in \(temp.path)")
  }

  @Test func overridesComeFromEnvironment() {
    let env = ProcessInfo.processInfo.environment
    #expect(env["REFRAMED_HOME"].map { URL(fileURLWithPath: $0, isDirectory: true).path } == ReframedPaths.home.path)
    #expect(env["REFRAMED_TMP"].map { URL(fileURLWithPath: $0, isDirectory: true).path } == ReframedPaths.temp.path)
  }

  @Test func appShowIdentityHasStablePublicValues() {
    #expect(AppShowIdentity.name == "AppShow")
    #expect(AppShowIdentity.bundleIdentifier == "com.mattwebhub.appshow")
    #expect(AppShowIdentity.testBundleIdentifier == "com.mattwebhub.appshow.tests")
    #expect(AppShowIdentity.projectTypeIdentifier == "com.mattwebhub.appshow.project")
    #expect(AppShowIdentity.legacyProjectTypeIdentifier == "eu.jankuri.reframed.project")
    #expect(AppShowIdentity.projectExtension == "appshow")
    #expect(AppShowIdentity.legacyProjectExtension == "frm")
    #expect(AppShowIdentity.supportedProjectExtensions == ["appshow", "frm"])
  }

  @Test func appShowHomeOverrideTakesPrecedenceOverLegacyOverride() {
    let home = AppShowPaths.resolveHome(
      environment: ["APPSHOW_HOME": "/tmp/appshow-new", "REFRAMED_HOME": "/tmp/appshow-legacy"],
      homeDirectory: URL(fileURLWithPath: "/tmp/home", isDirectory: true)
    )
    #expect(home.path == "/tmp/appshow-new")
  }

  @Test func legacyHomeOverrideRemainsACompatibilityFallback() {
    let home = AppShowPaths.resolveHome(
      environment: ["REFRAMED_HOME": "/tmp/appshow-legacy"],
      homeDirectory: URL(fileURLWithPath: "/tmp/home", isDirectory: true)
    )
    #expect(home.path == "/tmp/appshow-legacy")
  }

  @Test func legacyHomeMovesWhenAppShowHomeDoesNotExist() throws {
    let root = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(root) }
    let legacy = root.appendingPathComponent(".reframed", isDirectory: true)
    try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
    try Data("legacy".utf8).write(to: legacy.appendingPathComponent("reframed.json"))

    let resolved = AppShowPaths.resolveHome(environment: [:], homeDirectory: root)

    #expect(resolved == root.appendingPathComponent(".appshow", isDirectory: true))
    #expect(FileManager.default.fileExists(atPath: resolved.appendingPathComponent("config.json").path))
    #expect(!FileManager.default.fileExists(atPath: resolved.appendingPathComponent("reframed.json").path))
    #expect(!FileManager.default.fileExists(atPath: legacy.path))
  }

  @Test func existingAppShowHomeIsNeverReplacedByLegacyData() throws {
    let root = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(root) }
    let legacy = root.appendingPathComponent(".reframed", isDirectory: true)
    let current = root.appendingPathComponent(".appshow", isDirectory: true)
    try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: current, withIntermediateDirectories: true)
    try Data("legacy".utf8).write(to: legacy.appendingPathComponent("state.json"))
    try Data("current".utf8).write(to: current.appendingPathComponent("state.json"))

    let resolved = AppShowPaths.resolveHome(environment: [:], homeDirectory: root)

    #expect(resolved == current)
    #expect(try String(contentsOf: current.appendingPathComponent("state.json"), encoding: .utf8) == "current")
    #expect(FileManager.default.fileExists(atPath: legacy.path))
  }
}
