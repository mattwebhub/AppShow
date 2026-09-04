import Foundation
import Testing

@testable import Reframed

struct LaunchEnvironmentTests {
  @Test func hostedTestRunIsDetectedAsTestHost() {
    #expect(LaunchEnvironment.isTestHost)
  }

  @Test func schemeSetsExplicitTestHostFlag() {
    #expect(ProcessInfo.processInfo.environment["REFRAMED_TEST_HOST"] == "1")
  }
}
