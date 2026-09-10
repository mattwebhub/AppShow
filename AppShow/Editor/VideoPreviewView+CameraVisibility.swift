import AVFoundation
import AppKit

extension VideoPreviewView {
  func updateCameraVisibility(_ nsView: VideoPreviewContainer) {
    let hiddenRegion = cameraHiddenRegions.first { currentTime >= $0.start && currentTime <= $0.end }
    let isCameraHidden = hiddenRegion != nil
    nsView.isCameraHidden = isCameraHidden
    let fsRegion = cameraFullscreenRegions.first { currentTime >= $0.start && currentTime <= $0.end }
    let isFullscreen = !isCameraHidden && fsRegion?.presentation == .fullscreen
    nsView.cameraSplitType = !isCameraHidden ? fsRegion?.presentation : nil
    nsView.isCameraFullscreen = isFullscreen
    nsView.currentFullscreenFillMode = cameraFullscreenFillMode
    nsView.currentFullscreenAspect = cameraFullscreenAspect

    let customRegion = cameraCustomRegions.first(where: { currentTime >= $0.start && currentTime <= $0.end })

    let transitionProgress: CGFloat = {
      if let r = hiddenRegion {
        let p = Self.computeTransitionProgress(
          time: currentTime,
          start: r.start,
          end: r.end,
          entryTransition: r.entryTransition,
          entryDuration: r.entryDuration,
          exitTransition: r.exitTransition,
          exitDuration: r.exitDuration
        )
        return 1.0 - p
      }
      if let r = fsRegion {
        return Self.computeTransitionProgress(
          time: currentTime,
          start: r.start,
          end: r.end,
          entryTransition: r.entryTransition,
          entryDuration: r.entryDuration,
          exitTransition: r.exitTransition,
          exitDuration: r.exitDuration
        )
      }
      if let r = customRegion {
        return Self.computeTransitionProgress(
          time: currentTime,
          start: r.start,
          end: r.end,
          entryTransition: r.entryTransition,
          entryDuration: r.entryDuration,
          exitTransition: r.exitTransition,
          exitDuration: r.exitDuration
        )
      }
      return 1.0
    }()

    let activeTransitionType: RegionTransitionType = {
      if let r = hiddenRegion {
        return Self.resolveTransitionType(
          time: currentTime,
          start: r.start,
          end: r.end,
          entryTransition: r.entryTransition,
          entryDuration: r.entryDuration,
          exitTransition: r.exitTransition,
          exitDuration: r.exitDuration
        )
      }
      if let r = fsRegion {
        return Self.resolveTransitionType(
          time: currentTime,
          start: r.start,
          end: r.end,
          entryTransition: r.entryTransition,
          entryDuration: r.entryDuration,
          exitTransition: r.exitTransition,
          exitDuration: r.exitDuration
        )
      }
      if let r = customRegion {
        return Self.resolveTransitionType(
          time: currentTime,
          start: r.start,
          end: r.end,
          entryTransition: r.entryTransition,
          entryDuration: r.entryDuration,
          exitTransition: r.exitTransition,
          exitDuration: r.exitDuration
        )
      }
      return .none
    }()

    nsView.cameraTransitionProgress = transitionProgress
    nsView.cameraTransitionType = activeTransitionType

    let isCustomTransition =
      customRegion != nil
      && hiddenRegion == nil
      && (activeTransitionType == .scale || activeTransitionType == .slide)
      && transitionProgress < 1.0
      && defaultPipLayout != nil
    nsView.isCustomRegionTransition = isCustomTransition
    if isCustomTransition {
      nsView.defaultPipLayout = defaultPipLayout!
      nsView.defaultPipCameraAspect = defaultPipCameraAspect ?? cameraAspect
      nsView.defaultPipCornerRadius = defaultPipCornerRadius ?? cameraCornerRadius
      nsView.defaultPipBorderWidth = defaultPipBorderWidth ?? cameraBorderWidth
      nsView.defaultPipBorderColor = defaultPipBorderColor ?? cameraBorderColor
      nsView.defaultPipShadow = defaultPipShadow ?? cameraShadow
      nsView.defaultPipMirrored = defaultPipMirrored ?? cameraMirrored
    }
  }

}
