import Foundation

enum LaunchEnvironment {
  static let isTestHost: Bool = {
    let env = ProcessInfo.processInfo.environment
    return env["REFRAMED_TEST_HOST"] == "1"
      || env["XCTestConfigurationFilePath"] != nil
      || env["XCTestBundlePath"] != nil
  }()
}
