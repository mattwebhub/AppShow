import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
  let session = SessionState()
  let permissions = PermissionStore.live()
  private var permissionsWindow: NSWindow?
  private var shortcutManager: KeyboardShortcutManager?
  private var eventMonitor: Any?

  func applicationDidFinishLaunching(_ notification: Notification) {
    guard !LaunchEnvironment.isTestHost else { return }
    _ = SparkleUpdater.shared
    ConfigService.shared.applyAppearance()

    let manager = KeyboardShortcutManager(session: session)
    manager.start(enableGlobalShortcuts: permissions.accessibilityGranted)
    shortcutManager = manager
    permissions.onAccessibilityChanged = { [weak manager] granted in
      manager?.stop()
      manager?.start(enableGlobalShortcuts: granted)
    }
    session.onScreenRecordingPermissionRequired = { [weak self] in
      self?.showPermissionsWindow()
    }

    if permissions.allGranted {
      session.showToolbar()
    } else {
      showPermissionsWindow()
    }

    eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
      guard let self else { return event }
      guard let button = self.session.statusItemButton,
        event.window === button.window
      else { return event }
      switch self.session.state {
      case .recording, .paused:
        Task {
          try? await self.session.stopRecording()
        }
        return nil
      default:
        return event
      }
    }
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    permissions.refresh()
    session.showToolbar()
    return false
  }

  func applicationDidBecomeActive(_ notification: Notification) {
    guard !LaunchEnvironment.isTestHost else { return }
    permissions.refresh()
    session.logger.info(
      "Permissions: screenRecording=\(permissions.screenRecordingGranted), accessibility=\(permissions.accessibilityGranted)"
    )
  }

  func showPermissionsWindow() {
    permissions.refresh()
    if let permissionsWindow, permissionsWindow.isVisible {
      permissionsWindow.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      return
    }

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 720, height: 570),
      styleMask: [.titled, .closable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    window.isReleasedWhenClosed = false
    window.titlebarAppearsTransparent = true
    window.isMovableByWindowBackground = true
    window.backgroundColor = AppShowColors.backgroundNS
    window.center()

    window.collectionBehavior.insert(.moveToActiveSpace)

    window.delegate = self
    window.contentViewController = NSHostingController(
      rootView: PermissionsView(permissions: permissions) { [weak self] in
        MainActor.assumeIsolated {
          self?.dismissPermissionsWindow()
          self?.session.showToolbar()
        }
      }
    )

    let min = NSSize(width: 720, height: 570)
    window.contentMinSize = min
    window.minSize = min

    permissionsWindow = window
    window.level = .floating
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)

    DispatchQueue.main.async {
      window.level = .normal
    }
  }

  func windowWillClose(_ notification: Notification) {
    if (notification.object as? NSWindow) === permissionsWindow {
      permissionsWindow = nil
    }
  }

  func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls where AppShowIdentity.supportedProjectExtensions.contains(url.pathExtension.lowercased()) {
      session.openProject(at: url)
    }
  }

  private func dismissPermissionsWindow() {
    permissionsWindow?.close()
    permissionsWindow = nil
  }
}
