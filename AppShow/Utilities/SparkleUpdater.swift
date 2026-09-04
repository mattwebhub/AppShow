import Sparkle

@MainActor
final class SparkleUpdater {
  static let shared = SparkleUpdater()

  private let controller: SPUStandardUpdaterController?

  var isAvailable: Bool { controller != nil }

  private init() {
    guard
      let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
      !publicKey.isEmpty
    else {
      controller = nil
      return
    }
    let controller = SPUStandardUpdaterController(
      startingUpdater: true,
      updaterDelegate: nil,
      userDriverDelegate: nil
    )
    controller.updater.automaticallyChecksForUpdates = false
    controller.updater.updateCheckInterval = 3600
    self.controller = controller
  }

  func checkForUpdates() {
    controller?.checkForUpdates(nil)
  }
}
