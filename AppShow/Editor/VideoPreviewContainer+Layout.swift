import AVFoundation
import AppKit

extension VideoPreviewContainer {
  func layoutAll() {
    CATransaction.begin()
    CATransaction.setDisableActions(true)

    let canvasRect = AVMakeRect(aspectRatio: currentCanvasSize, insideRect: bounds)
    let scaleX = canvasRect.width / max(currentCanvasSize.width, 1)
    let scaleY = canvasRect.height / max(currentCanvasSize.height, 1)
    let padH = currentPadding * currentScreenSize.width * scaleX
    let padV = currentPadding * currentScreenSize.height * scaleY

    let paddedArea = CGRect(
      x: canvasRect.origin.x + padH,
      y: canvasRect.origin.y + padV,
      width: canvasRect.width - padH * 2,
      height: canvasRect.height - padV * 2
    )
    let screenRect = previewScreenRect(canvas: canvasRect, paddedArea: paddedArea)

    screenContainerLayer.bounds = CGRect(origin: .zero, size: screenRect.size)
    screenContainerLayer.position = CGPoint(x: screenRect.midX, y: screenRect.midY)
    let cornerRadius = min(screenRect.width, screenRect.height) * (currentVideoCornerRadius / 100.0)
    let maskPath = CGPath(
      roundedRect: CGRect(origin: .zero, size: screenRect.size),
      cornerWidth: cornerRadius,
      cornerHeight: cornerRadius,
      transform: nil
    )
    screenMaskLayer.frame = CGRect(origin: .zero, size: screenRect.size)
    screenMaskLayer.path = maskPath
    screenContainerLayer.mask = screenMaskLayer

    if currentVideoShadow > 0 {
      let blur = min(screenRect.width, screenRect.height) * currentVideoShadow / 2000.0
      screenShadowLayer.frame = screenRect
      screenShadowLayer.shadowPath = CGPath(
        roundedRect: CGRect(origin: .zero, size: screenRect.size),
        cornerWidth: cornerRadius,
        cornerHeight: cornerRadius,
        transform: nil
      )
      screenShadowLayer.shadowRadius = blur
      screenShadowLayer.shadowOpacity = 0.6
      screenShadowLayer.isHidden = false
    } else {
      screenShadowLayer.isHidden = true
      screenShadowLayer.shadowOpacity = 0
    }

    let zr = currentZoomRect
    if zr.width < 1.0 || zr.height < 1.0 {
      let cw = screenRect.width
      let ch = screenRect.height
      let pw = cw / zr.width
      let ph = ch / zr.height
      let px = -zr.origin.x * pw
      let py = -(1 - zr.origin.y - zr.height) * ph
      screenPlayerLayer.frame = CGRect(x: px, y: py, width: pw, height: ph)
    } else {
      screenPlayerLayer.frame = screenContainerLayer.bounds
    }

    if isScreenHidden && screenTransitionType == .none {
      screenContainerLayer.opacity = 0
      screenShadowLayer.opacity = 0
    } else if screenTransitionType != .none {
      let p = Float(screenTransitionProgress)
      screenShadowLayer.opacity = 0
      switch screenTransitionType {
      case .none:
        screenContainerLayer.opacity = 1
        screenContainerLayer.transform = CATransform3DIdentity
      case .fade:
        screenContainerLayer.opacity = p
        screenContainerLayer.transform = CATransform3DIdentity
      case .scale:
        screenContainerLayer.opacity = 1
        screenContainerLayer.transform = CATransform3DMakeScale(CGFloat(p), CGFloat(p), 1)
      case .slide:
        screenContainerLayer.opacity = 1
        let offsetY = (1.0 - CGFloat(p)) * (screenRect.origin.y + screenRect.height)
        screenContainerLayer.transform = CATransform3DMakeTranslation(0, -offsetY, 0)
      }
    } else {
      screenContainerLayer.opacity = 1
      screenContainerLayer.transform = CATransform3DIdentity
      screenShadowLayer.opacity = currentVideoShadow > 0 ? 0.6 : 0
    }

    guard let ws = currentWebcamSize, webcamPlayerLayer.player != nil else {
      webcamWrapper.isHidden = true
      CATransaction.commit()
      return
    }

    if isDraggingCamera {
      CATransaction.commit()
      return
    }

    let hasActiveTransition = cameraTransitionType != .none && cameraTransitionProgress < 1.0
    if isCameraHidden && !hasActiveTransition {
      webcamWrapper.isHidden = true
      webcamWrapper.alphaValue = 1.0
      webcamWrapper.layer?.transform = CATransform3DIdentity
      screenContainerLayer.isHidden = false
      cursorOverlay.isHidden = false
      CATransaction.commit()
      return
    }

    webcamWrapper.isHidden = false

    if isCameraHidden && hasActiveTransition {
      webcamWrapper.alphaValue = 1.0
      webcamWrapper.layer?.transform = CATransform3DIdentity
      screenContainerLayer.isHidden = false
      cursorOverlay.isHidden = false
    }

    if layoutSplitWebcam(canvas: canvasRect, webcamSize: ws, scale: min(scaleX, scaleY)) {
      CATransaction.commit()
      return
    }

    if isCameraFullscreen {
      layoutFullscreenWebcam(canvasRect: canvasRect, ws: ws, scaleX: scaleX, scaleY: scaleY, hasActiveTransition: hasActiveTransition)
      return
    }

    layoutPipWebcam(canvasRect: canvasRect, ws: ws, scaleX: scaleX, scaleY: scaleY)
  }

}
