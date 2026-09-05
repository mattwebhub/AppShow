import AVFoundation
import AppKit

extension VideoPreviewContainer {
  func syncProcessedWebcamLayer() {
    if currentCameraBackgroundStyle != .none {
      processedWebcamLayer.frame = webcamPlayerLayer.frame
      if isCameraFullscreen {
        processedWebcamLayer.contentsGravity =
          currentFullscreenFillMode == .fill ? .resizeAspectFill : .resizeAspect
      } else {
        processedWebcamLayer.contentsGravity = .resizeAspectFill
      }
      if currentCameraMirrored {
        processedWebcamLayer.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1))
      } else {
        processedWebcamLayer.setAffineTransform(.identity)
      }
    }
  }

  func applyTransitionEffect() {
    guard cameraTransitionType != .none else {
      webcamWrapper.alphaValue = 1.0
      webcamWrapper.layer?.transform = CATransform3DIdentity
      return
    }
    let p = cameraTransitionProgress
    switch cameraTransitionType {
    case .none:
      webcamWrapper.alphaValue = 1.0
      webcamWrapper.layer?.transform = CATransform3DIdentity
    case .fade:
      webcamWrapper.alphaValue = p
      webcamWrapper.layer?.transform = CATransform3DIdentity
    case .scale:
      webcamWrapper.alphaValue = 1.0
      let cx = webcamWrapper.bounds.width / 2
      let cy = webcamWrapper.bounds.height / 2
      var transform = CATransform3DIdentity
      transform = CATransform3DTranslate(transform, cx, cy, 0)
      transform = CATransform3DScale(transform, p, p, 1)
      transform = CATransform3DTranslate(transform, -cx, -cy, 0)
      webcamWrapper.layer?.transform = transform
    case .slide:
      webcamWrapper.alphaValue = 1.0
      let distanceToBottom = webcamWrapper.frame.origin.y + webcamWrapper.frame.height
      let offsetY = (1.0 - p) * distanceToBottom
      webcamWrapper.layer?.transform = CATransform3DMakeTranslation(0, -offsetY, 0)
    }
  }

  func updateZoomRect(_ rect: CGRect) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    currentZoomRect = rect
    let containerBounds = screenContainerLayer.bounds
    if rect.width >= 1.0 && rect.height >= 1.0 {
      screenPlayerLayer.frame = containerBounds
    } else {
      let cw = containerBounds.width
      let ch = containerBounds.height
      let pw = cw / rect.width
      let ph = ch / rect.height
      let px = -rect.origin.x * pw
      let py = -(1 - rect.origin.y - rect.height) * ph
      screenPlayerLayer.frame = CGRect(x: px, y: py, width: pw, height: ph)
    }
    CATransaction.commit()
  }

  func updateCameraLayout(
    _ layout: CameraLayout,
    webcamSize: CGSize?,
    screenSize: CGSize,
    canvasSize: CGSize,
    padding: CGFloat = 0,
    videoCornerRadius: CGFloat = 0,
    cameraAspect: CameraAspect = .original,
    cameraCornerRadius: CGFloat = 12,
    cameraBorderWidth: CGFloat = 0,
    cameraBorderColor: CGColor = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.3),
    videoShadow: CGFloat = 0,
    cameraShadow: CGFloat = 0,
    cameraMirrored: Bool = false
  ) {
    currentLayout = layout
    currentWebcamSize = webcamSize
    currentScreenSize = screenSize
    currentCanvasSize = canvasSize.width > 0 ? canvasSize : screenSize
    currentPadding = padding
    currentVideoCornerRadius = videoCornerRadius
    currentCameraAspect = cameraAspect
    currentCameraCornerRadius = cameraCornerRadius
    currentCameraBorderWidth = cameraBorderWidth
    currentCameraBorderColor = cameraBorderColor
    currentVideoShadow = videoShadow
    currentCameraShadow = cameraShadow
    currentCameraMirrored = cameraMirrored
    layoutAll()
  }
}
