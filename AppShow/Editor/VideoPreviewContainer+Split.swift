import AVFoundation
import AppKit

extension VideoPreviewContainer {
  func splitLayout(canvas: CGRect) -> WebcamSplitLayout? {
    guard let cameraSplitType, !isCameraHidden, currentWebcamSize != nil, webcamPlayerLayer.player != nil else { return nil }
    return WebcamSplitLayout(type: cameraSplitType, canvas: canvas)
  }

  func previewScreenRect(canvas: CGRect, paddedArea: CGRect) -> CGRect {
    splitLayout(canvas: canvas)?.screenRect(screenSize: currentScreenSize, originalArea: paddedArea, progress: cameraTransitionProgress)
      ?? AVMakeRect(aspectRatio: currentScreenSize, insideRect: paddedArea)
  }

  func layoutSplitWebcam(canvas: CGRect, webcamSize: CGSize, scale: CGFloat) -> Bool {
    guard let split = splitLayout(canvas: canvas) else { return false }
    let topPip = currentLayout.pixelRect(screenSize: canvas.size, webcamSize: webcamSize, cameraAspect: currentCameraAspect)
    let pip = CGRect(x: canvas.minX + topPip.minX, y: canvas.maxY - topPip.maxY, width: topPip.width, height: topPip.height)
    let p = cameraTransitionProgress
    webcamWrapper.frame = CameraLayout.interpolatedRect(from: pip, to: split.camera, progress: p)
    webcamWrapper.alphaValue = 1
    webcamWrapper.layer?.transform = CATransform3DIdentity
    webcamWrapper.layer?.shadowOpacity = 0
    webcamView.frame = webcamWrapper.bounds
    webcamView.layer?.backgroundColor = NSColor.clear.cgColor
    webcamView.layer?.cornerRadius = min(pip.width, pip.height) * currentCameraCornerRadius / 100 * (1 - p)
    webcamView.layer?.borderWidth = currentCameraBorderWidth * scale * (1 - p)
    webcamView.layer?.borderColor = currentCameraBorderColor
    webcamPlayerLayer.videoGravity = .resizeAspectFill
    webcamPlayerLayer.setAffineTransform(.identity)
    webcamPlayerLayer.frame = webcamView.bounds
    webcamPlayerLayer.setAffineTransform(currentCameraMirrored ? CGAffineTransform(scaleX: -1, y: 1) : .identity)
    screenContainerLayer.isHidden = false
    cursorOverlay.isHidden = false
    syncProcessedWebcamLayer()
    return true
  }
}
