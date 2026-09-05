import AVFoundation
import AppKit

extension VideoPreviewContainer {
  func layoutFullscreenWebcam(canvasRect: CGRect, ws: CGSize, scaleX: CGFloat, scaleY: CGFloat, hasActiveTransition: Bool) {
    let isPipTransition =
      (cameraTransitionType == .scale || cameraTransitionType == .slide)
      && cameraTransitionProgress < 1.0

    if isPipTransition {
      screenContainerLayer.isHidden = false
      cursorOverlay.isHidden = false
      webcamWrapper.layer?.shadowOpacity = 0
      webcamView.layer?.backgroundColor = NSColor.clear.cgColor

      let camAspect = currentCameraAspect.heightToWidthRatio(webcamSize: ws)
      let pipW = canvasRect.width * currentLayout.relativeWidth
      let pipH = pipW * camAspect
      let pipX = canvasRect.origin.x + canvasRect.width * currentLayout.relativeX
      let pipY = canvasRect.origin.y + canvasRect.height * currentLayout.relativeY
      let pipFrame = CGRect(x: pipX, y: bounds.height - pipY - pipH, width: pipW, height: pipH)

      let fsTargetRect: CGRect
      if currentFullscreenAspect == .original {
        fsTargetRect = canvasRect
      } else {
        let targetAspect = currentFullscreenAspect.aspectRatio(webcamSize: ws)
        let virtualSize = CGSize(width: targetAspect * 1000, height: 1000)
        let fsContainer = CGRect(origin: .zero, size: canvasRect.size)
        let innerRect: CGRect
        if currentFullscreenFillMode == .fill {
          let rectAspect = fsContainer.width / max(fsContainer.height, 1)
          let vAspect = virtualSize.width / max(virtualSize.height, 1)
          if vAspect > rectAspect {
            let h = fsContainer.width / max(vAspect, 0.001)
            innerRect = CGRect(x: 0, y: fsContainer.midY - h / 2, width: fsContainer.width, height: h)
          } else {
            let w = fsContainer.height * vAspect
            innerRect = CGRect(x: fsContainer.midX - w / 2, y: 0, width: w, height: fsContainer.height)
          }
        } else {
          innerRect = AVMakeRect(aspectRatio: virtualSize, insideRect: fsContainer)
        }
        fsTargetRect = CGRect(
          x: canvasRect.origin.x + innerRect.origin.x,
          y: canvasRect.origin.y + innerRect.origin.y,
          width: innerRect.width,
          height: innerRect.height
        )
      }

      let p = cameraTransitionProgress
      let interpFrame = CameraLayout.interpolatedRect(from: pipFrame, to: fsTargetRect, progress: p)

      let pipMinDim = min(pipW, pipH)
      let pipRadius = pipMinDim * (currentCameraCornerRadius / 100.0)
      let interpRadius = pipRadius * (1.0 - p)
      let pipBorder = currentCameraBorderWidth * min(scaleX, scaleY)
      let interpBorder = pipBorder * (1.0 - p)

      webcamWrapper.frame = interpFrame
      webcamView.frame = webcamWrapper.bounds
      webcamView.layer?.cornerRadius = interpRadius
      webcamView.layer?.borderWidth = interpBorder
      webcamView.layer?.borderColor = interpBorder > 0 ? currentCameraBorderColor : NSColor.clear.cgColor

      webcamPlayerLayer.videoGravity = .resizeAspectFill
      webcamPlayerLayer.setAffineTransform(.identity)
      webcamPlayerLayer.frame = webcamView.bounds
      webcamPlayerLayer.setAffineTransform(
        currentCameraMirrored ? CGAffineTransform(scaleX: -1, y: 1) : .identity
      )

      syncProcessedWebcamLayer()
      webcamWrapper.alphaValue = 1.0
      webcamWrapper.layer?.transform = CATransform3DIdentity
      CATransaction.commit()
      return
    }

    webcamWrapper.layer?.shadowOpacity = 0
    let fsTransitioning = hasActiveTransition
    screenContainerLayer.isHidden = !fsTransitioning
    screenShadowLayer.isHidden = !fsTransitioning
    cursorOverlay.isHidden = !fsTransitioning
    webcamWrapper.frame = canvasRect
    webcamView.frame = webcamWrapper.bounds
    webcamView.layer?.cornerRadius = 0
    webcamView.layer?.borderWidth = 0
    webcamView.layer?.borderColor = NSColor.clear.cgColor
    webcamView.layer?.backgroundColor = NSColor.clear.cgColor

    webcamPlayerLayer.setAffineTransform(.identity)
    let gravity: AVLayerVideoGravity =
      currentFullscreenFillMode == .fill
      ? .resizeAspectFill : .resizeAspect
    webcamPlayerLayer.videoGravity = gravity

    let containerBounds = webcamView.bounds
    if currentFullscreenAspect == .original {
      webcamPlayerLayer.frame = containerBounds
    } else {
      let targetAspect = currentFullscreenAspect.aspectRatio(webcamSize: ws)
      let virtualSize = CGSize(width: targetAspect * 1000, height: 1000)
      let aspectRect: CGRect
      if currentFullscreenFillMode == .fill {
        let rectAspect = containerBounds.width / max(containerBounds.height, 1)
        let vAspect = virtualSize.width / max(virtualSize.height, 1)
        if vAspect > rectAspect {
          let h = containerBounds.width / max(vAspect, 0.001)
          aspectRect = CGRect(
            x: 0,
            y: containerBounds.midY - h / 2,
            width: containerBounds.width,
            height: h
          )
        } else {
          let w = containerBounds.height * vAspect
          aspectRect = CGRect(
            x: containerBounds.midX - w / 2,
            y: 0,
            width: w,
            height: containerBounds.height
          )
        }
      } else {
        aspectRect = AVMakeRect(aspectRatio: virtualSize, insideRect: containerBounds)
      }
      webcamPlayerLayer.frame = aspectRect
    }

    webcamPlayerLayer.setAffineTransform(
      currentCameraMirrored ? CGAffineTransform(scaleX: -1, y: 1) : .identity
    )
    syncProcessedWebcamLayer()
    applyTransitionEffect()
    CATransaction.commit()
    return
  }
}
