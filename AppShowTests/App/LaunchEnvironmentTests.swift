import Foundation
import Testing

@testable import AppShow

struct LaunchEnvironmentTests {
  @Test func hostedTestRunIsDetectedAsTestHost() {
    #expect(LaunchEnvironment.isTestHost)
  }

  @Test func schemeSetsExplicitTestHostFlag() {
    #expect(ProcessInfo.processInfo.environment["APPSHOW_TEST_HOST"] == "1")
  }
}
