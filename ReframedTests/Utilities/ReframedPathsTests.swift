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
}
