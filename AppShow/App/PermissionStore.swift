import Foundation
import Observation

enum PermissionKind {
  case screenRecording
  case accessibility

  var settingsURL: URL {
    let pane = self == .screenRecording ? "Privacy_ScreenCapture" : "Privacy_Accessibility"
    return URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")!
  }
}

@MainActor
@Observable
final class PermissionStore {
  private(set) var screenRecordingGranted: Bool
  private(set) var accessibilityGranted: Bool
  var onAccessibilityChanged: ((Bool) -> Void)?

  private let screenRecordingCheck: () -> Bool
  private let accessibilityCheck: () -> Bool
  private let screenRecordingRequest: () -> Void
  private let accessibilityRequest: () -> Void

  let requiresAccessibility: Bool

  var allGranted: Bool { screenRecordingGranted && (!requiresAccessibility || accessibilityGranted) }

  init(
    screenRecordingCheck: @escaping () -> Bool,
    accessibilityCheck: @escaping () -> Bool,
    screenRecordingRequest: @escaping () -> Void,
    accessibilityRequest: @escaping () -> Void,
    requiresAccessibility: Bool = true
  ) {
    self.requiresAccessibility = requiresAccessibility
    self.screenRecordingCheck = screenRecordingCheck
    self.accessibilityCheck = accessibilityCheck
    self.screenRecordingRequest = screenRecordingRequest
    self.accessibilityRequest = accessibilityRequest
    screenRecordingGranted = screenRecordingCheck()
    accessibilityGranted = requiresAccessibility && accessibilityCheck()
  }

  func refresh() {
    screenRecordingGranted = screenRecordingCheck()
    let trusted = requiresAccessibility && accessibilityCheck()
    if trusted != accessibilityGranted {
      accessibilityGranted = trusted
      onAccessibilityChanged?(trusted)
    }
  }

  func request(_ kind: PermissionKind) {
    switch kind {
    case .screenRecording: screenRecordingRequest()
    case .accessibility:
      if requiresAccessibility { accessibilityRequest() }
    }
    refresh()
  }

  static func live() -> PermissionStore {
    if LaunchEnvironment.isTestHost {
      return PermissionStore(
        screenRecordingCheck: { false },
        accessibilityCheck: { false },
        screenRecordingRequest: {},
        accessibilityRequest: {},
        requiresAccessibility: !AppDistribution.isStore
      )
    }
    return PermissionStore(
      screenRecordingCheck: { Permissions.hasScreenRecordingPermission },
      accessibilityCheck: { Permissions.hasAccessibilityPermission },
      screenRecordingRequest: { Permissions.requestScreenRecordingPermission() },
      accessibilityRequest: { Permissions.requestAccessibilityPermission() },
      requiresAccessibility: !AppDistribution.isStore
    )
  }
}
