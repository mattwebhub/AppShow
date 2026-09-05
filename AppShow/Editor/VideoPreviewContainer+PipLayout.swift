import AVFoundation
import AppKit

extension VideoPreviewContainer {
  func layoutPipWebcam(canvasRect: CGRect, ws: CGSize, scaleX: CGFloat, scaleY: CGFloat) {
    screenContainerLayer.isHidden = false
    cursorOverlay.isHidden = false
    webcamView.layer?.backgroundColor = NSColor.clear.cgColor

    let camAspect = currentCameraAspect.heightToWidthRatio(webcamSize: ws)
    let w = canvasRect.width * currentLayout.relativeWidth
    let h = w * camAspect
    let x = canvasRect.origin.x + canvasRect.width * currentLayout.relativeX
    let y = canvasRect.origin.y + canvasRect.height * currentLayout.relativeY

    if isCustomRegionTransition {
      let defaultAspect = defaultPipCameraAspect.heightToWidthRatio(webcamSize: ws)
      let defW = canvasRect.width * defaultPipLayout.relativeWidth
      let defH = defW * defaultAspect
      let defX = canvasRect.origin.x + canvasRect.width * defaultPipLayout.relativeX
      let defY = canvasRect.origin.y + canvasRect.height * defaultPipLayout.relativeY
      let defFrame = CGRect(x: defX, y: bounds.height - defY - defH, width: defW, height: defH)
      let customFrame = CGRect(x: x, y: bounds.height - y - h, width: w, height: h)

      let p = cameraTransitionProgress
      let interpFrame = CGRect(
        x: defFrame.origin.x + (customFrame.origin.x - defFrame.origin.x) * p,
        y: defFrame.origin.y + (customFrame.origin.y - defFrame.origin.y) * p,
        width: defFrame.width + (customFrame.width - defFrame.width) * p,
        height: defFrame.height + (customFrame.height - defFrame.height) * p
      )

      let defMinDim = min(defW, defH)
      let defRadius = defMinDim * (defaultPipCornerRadius / 100.0)
      let customMinDim = min(w, h)
      let customRadius = customMinDim * (currentCameraCornerRadius / 100.0)
      let interpRadius = defRadius + (customRadius - defRadius) * p

      let defBorder = defaultPipBorderWidth * min(scaleX, scaleY)
      let customBorder = currentCameraBorderWidth * min(scaleX, scaleY)
      let interpBorder = defBorder + (customBorder - defBorder) * p

      let interpShadow = defaultPipShadow + (currentCameraShadow - defaultPipShadow) * p
      let mirrored = p < 0.5 ? defaultPipMirrored : currentCameraMirrored

      webcamWrapper.frame = interpFrame
      webcamView.frame = webcamWrapper.bounds
      webcamView.layer?.cornerRadius = interpRadius
      webcamView.layer?.borderWidth = interpBorder
      webcamView.layer?.borderColor =
        interpBorder > 0
        ? (p < 0.5 ? defaultPipBorderColor : currentCameraBorderColor)
        : NSColor.clear.cgColor

      webcamPlayerLayer.videoGravity = .resizeAspectFill
      webcamPlayerLayer.setAffineTransform(.identity)
      webcamPlayerLayer.frame = webcamView.bounds
      webcamPlayerLayer.setAffineTransform(
        mirrored ? CGAffineTransform(scaleX: -1, y: 1) : .identity
      )

      if interpShadow > 0 {
        let interpMinDim = min(interpFrame.width, interpFrame.height)
        let camBlur = interpMinDim * interpShadow / 2000.0
        webcamWrapper.layer?.shadowColor = NSColor.black.cgColor
        webcamWrapper.layer?.shadowOffset = .zero
        webcamWrapper.layer?.shadowRadius = camBlur
        webcamWrapper.layer?.shadowOpacity = 0.6
        webcamWrapper.layer?.shadowPath = CGPath(
          roundedRect: webcamView.bounds,
          cornerWidth: interpRadius,
          cornerHeight: interpRadius,
          transform: nil
        )
      } else {
        webcamWrapper.layer?.shadowOpacity = 0
      }

      syncProcessedWebcamLayer()
      webcamWrapper.alphaValue = 1.0
      webcamWrapper.layer?.transform = CATransform3DIdentity
      CATransaction.commit()
      return
    }

    let minDim = min(w, h)
    let scaledRadius = minDim * (currentCameraCornerRadius / 100.0)
    let scaledBorder = currentCameraBorderWidth * min(scaleX, scaleY)

    let webcamFrame = CGRect(x: x, y: bounds.height - y - h, width: w, height: h)
    webcamWrapper.frame = webcamFrame
    webcamView.frame = webcamWrapper.bounds
    webcamView.layer?.cornerRadius = scaledRadius
    webcamView.layer?.borderWidth = scaledBorder
    webcamView.layer?.borderColor =
      scaledBorder > 0
      ? currentCameraBorderColor
      : NSColor.clear.cgColor
    webcamPlayerLayer.videoGravity = .resizeAspectFill
    webcamPlayerLayer.setAffineTransform(.identity)
    webcamPlayerLayer.frame = webcamView.bounds
    webcamPlayerLayer.setAffineTransform(
      currentCameraMirrored ? CGAffineTransform(scaleX: -1, y: 1) : .identity
    )

    if currentCameraShadow > 0 {
      let camBlur = minDim * currentCameraShadow / 2000.0
      webcamWrapper.layer?.shadowColor = NSColor.black.cgColor
      webcamWrapper.layer?.shadowOffset = .zero
      webcamWrapper.layer?.shadowRadius = camBlur
      webcamWrapper.layer?.shadowOpacity = 0.6
      webcamWrapper.layer?.shadowPath = CGPath(
        roundedRect: webcamView.bounds,
        cornerWidth: scaledRadius,
        cornerHeight: scaledRadius,
        transform: nil
      )
    } else {
      webcamWrapper.layer?.shadowOpacity = 0
    }

    syncProcessedWebcamLayer()
    applyTransitionEffect()
    CATransaction.commit()
  }
}
