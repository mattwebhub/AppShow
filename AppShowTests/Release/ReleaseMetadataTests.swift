import Foundation
import Testing

@testable import AppShow

@MainActor
struct ReleaseMetadataTests {
  @Test func hostedBuildNumberIsIndependentOfMarketingVersion() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let config = try String(contentsOf: root.appendingPathComponent("Config.xcconfig"), encoding: .utf8)
    let line = try #require(config.split(separator: "\n").first { $0.hasPrefix("CURRENT_PROJECT_VERSION = ") })
    let expected = line.split(separator: "=")[1].trimmingCharacters(in: .whitespaces)
    #expect(UpdateChecker.buildNumber == expected)
    #expect(UpdateChecker.buildNumber != UpdateChecker.currentVersion)
  }
}
