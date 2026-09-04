import AVFoundation
import AppKit

@MainActor
final class WebcamPreviewWindow {
  private var panel: NSPanel?
  private var previewLayer: AVCaptureVideoPreviewLayer?
  private var loadingView: NSView?
  private var appearanceObserver: NSKeyValueObservation?

  private var presentation = WebcamPresentation()
  private var videoWidth: CGFloat = 240
  private var videoHeight: CGFloat { videoWidth }
  private var cornerRadius: CGFloat { videoWidth / 2 }

  private var totalWidth: CGFloat { videoWidth }
  private var totalHeight: CGFloat { videoHeight }

  func updatePresentation(_ value: WebcamPresentation) {
    presentation = value.normalized
    let screen = panel?.screen ?? NSScreen.main
    let canvas = screen?.visibleFrame.size ?? CGSize(width: 1200, height: 800)
    videoWidth = presentation.layout(canvasSize: canvas).relativeWidth * canvas.width
    guard let panel else { return }
    panel.setFrame(NSRect(origin: defaultOrigin(), size: NSSize(width: videoWidth, height: videoHeight)), display: true)
    guard let content = panel.contentView else { return }
    content.layer?.cornerRadius = cornerRadius
    for view in content.subviews {
      view.frame = content.bounds
      view.layer?.cornerRadius = cornerRadius
    }
    previewLayer?.frame = content.bounds
  }

  func showLoading() {
    if panel == nil {
      createPanel()
    }

    previewLayer?.removeFromSuperlayer()
    previewLayer = nil
    loadingView?.removeFromSuperview()

    guard let contentView = panel?.contentView else { return }

    let container = NSView(frame: NSRect(origin: .zero, size: NSSize(width: videoWidth, height: videoHeight)))
    container.wantsLayer = true
    container.layer?.cornerRadius = cornerRadius
    container.layer?.masksToBounds = true
    container.layer?.backgroundColor = AppShowColors.backgroundNS.cgColor

    let spinner = NSProgressIndicator(frame: NSRect(x: (videoWidth - 24) / 2, y: (videoHeight - 24) / 2 + 10, width: 24, height: 24))
    spinner.style = .spinning
    spinner.controlSize = .small
    spinner.appearance = NSAppearance(named: AppShowColors.isDark ? .darkAqua : .aqua)
    spinner.startAnimation(nil)
    container.addSubview(spinner)

    let label = NSTextField(labelWithString: "Camera is starting...")
    label.font = NSFont.systemFont(ofSize: FontSize.xs, weight: .medium)
    label.textColor = AppShowColors.secondaryTextNS
    label.alignment = .center
    label.frame = NSRect(x: 0, y: (videoHeight - 24) / 2 - 18, width: videoWidth, height: 16)
    container.addSubview(label)

    contentView.addSubview(container)
    loadingView = container

    panel?.orderFrontRegardless()
  }

  func show(captureSession: AVCaptureSession) {
    if panel == nil {
      createPanel()
    }

    previewLayer?.removeFromSuperlayer()
    previewLayer = nil

    guard let contentView = panel?.contentView else { return }

    let videoView = NSView(frame: NSRect(origin: .zero, size: NSSize(width: videoWidth, height: videoHeight)))
    videoView.wantsLayer = true
    videoView.layer?.cornerRadius = cornerRadius
    videoView.layer?.masksToBounds = true

    let layer = AVCaptureVideoPreviewLayer(session: captureSession)
    layer.videoGravity = .resizeAspectFill
    layer.frame = videoView.bounds
    layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
    videoView.layer?.addSublayer(layer)
    self.previewLayer = layer

    contentView.addSubview(videoView, positioned: .below, relativeTo: loadingView)
    panel?.orderFrontRegardless()

    let pendingLoadingView = loadingView
    loadingView = nil
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      pendingLoadingView?.removeFromSuperview()
    }
  }

  func showError(_ message: String) {
    if panel == nil {
      createPanel()
    }

    previewLayer?.removeFromSuperlayer()
    previewLayer = nil
    loadingView?.removeFromSuperview()
    loadingView = nil

    guard let contentView = panel?.contentView else { return }

    let container = NSView(frame: NSRect(origin: .zero, size: NSSize(width: videoWidth, height: videoHeight)))
    container.wantsLayer = true
    container.layer?.cornerRadius = cornerRadius
    container.layer?.masksToBounds = true
    container.layer?.backgroundColor = AppShowColors.backgroundNS.cgColor

    let icon = NSImageView(frame: NSRect(x: (videoWidth - 24) / 2, y: (videoHeight - 24) / 2 + 10, width: 24, height: 24))
    icon.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Error")
    icon.contentTintColor = .systemOrange
    container.addSubview(icon)

    let label = NSTextField(labelWithString: message)
    label.font = NSFont.systemFont(ofSize: FontSize.xs, weight: .medium)
    label.textColor = AppShowColors.secondaryTextNS
    label.alignment = .center
    label.lineBreakMode = .byTruncatingTail
    label.frame = NSRect(x: 4, y: (videoHeight - 24) / 2 - 18, width: videoWidth - 8, height: 16)
    container.addSubview(label)

    contentView.addSubview(container)
    loadingView = container

    panel?.orderFrontRegardless()
  }

  func hide() {
    panel?.orderOut(nil)
  }

  func unhide() {
    panel?.orderFrontRegardless()
  }

  func close() {
    appearanceObserver?.invalidate()
    appearanceObserver = nil
    previewLayer?.removeFromSuperlayer()
    previewLayer = nil
    loadingView?.removeFromSuperview()
    loadingView = nil
    panel?.orderOut(nil)
    panel?.contentView = nil
    panel = nil
  }

  private func createPanel() {
    let origin = resolvedOrigin()

    let panel = NSPanel(
      contentRect: NSRect(origin: origin, size: NSSize(width: totalWidth, height: totalHeight)),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
    panel.isFloatingPanel = true
    panel.isMovableByWindowBackground = true
    panel.hasShadow = true
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.sharingType = Window.sharingType

    let contentView = NSView(frame: NSRect(origin: .zero, size: NSSize(width: totalWidth, height: totalHeight)))
    contentView.wantsLayer = true
    contentView.layer?.cornerRadius = cornerRadius
    contentView.layer?.masksToBounds = true
    contentView.layer?.backgroundColor = NSColor.clear.cgColor

    panel.contentView = contentView
    self.panel = panel

    appearanceObserver = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
      MainActor.assumeIsolated {
        self?.updateColors()
      }
    }
  }

  private func updateColors() {
    if let container = loadingView {
      container.layer?.backgroundColor = AppShowColors.backgroundNS.cgColor
      for subview in container.subviews {
        if let label = subview as? NSTextField {
          label.textColor = AppShowColors.secondaryTextNS
        }
        if let spinner = subview as? NSProgressIndicator {
          spinner.appearance = NSAppearance(named: AppShowColors.isDark ? .darkAqua : .aqua)
        }
      }
    }
  }

  private func resolvedOrigin() -> CGPoint {
    defaultOrigin()
  }

  private func defaultOrigin() -> CGPoint {
    guard let screen = panel?.screen ?? NSScreen.main else { return .zero }
    let frame = screen.visibleFrame
    let layout = presentation.layout(canvasSize: frame.size)
    return CGPoint(x: frame.minX + frame.width * layout.relativeX, y: frame.maxY - frame.height * layout.relativeY - videoHeight)
  }

}
