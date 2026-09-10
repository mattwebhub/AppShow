import AVFoundation
import CoreGraphics

struct WebcamSplitLayout: Sendable {
  let camera: CGRect
  let screenArea: CGRect

  init?(type: CameraRegionType, canvas: CGRect) {
    guard type.isSplit else { return nil }
    let fraction: CGFloat = type == .leftHalf || type == .rightHalf ? 0.5 : 1.0 / 3
    let width = canvas.width * fraction
    let left = type == .leftHalf || type == .leftThird
    camera = CGRect(x: left ? canvas.minX : canvas.maxX - width, y: canvas.minY, width: width, height: canvas.height)
    screenArea = CGRect(x: left ? canvas.minX + width : canvas.minX, y: canvas.minY, width: canvas.width - width, height: canvas.height)
  }

  func screenRect(screenSize: CGSize, originalArea: CGRect, progress: CGFloat) -> CGRect {
    let target = screenArea.intersection(originalArea)
    return CameraLayout.interpolatedRect(
      from: AVMakeRect(aspectRatio: screenSize, insideRect: originalArea),
      to: AVMakeRect(aspectRatio: screenSize, insideRect: target),
      progress: progress
    )
  }
}

extension CameraRegionType {
  var isSplit: Bool { self == .leftHalf || self == .rightHalf || self == .leftThird || self == .rightThird }
  var isExpanded: Bool { self == .fullscreen || isSplit }
}

extension CompositionInstruction {
  func webcamSplit(at time: CMTime, canvas: CGRect) -> (layout: WebcamSplitLayout, progress: CGFloat)? {
    guard webcamTrackID != nil,
      !cameraHiddenRegions.contains(where: { $0.timeRange.containsTime(time) }),
      let region = cameraFullscreenRegions.first(where: { $0.timeRange.containsTime(time) }),
      let layout = WebcamSplitLayout(type: region.cameraPresentation, canvas: canvas)
    else { return nil }
    return (layout, FrameRenderer.computeRegionTransition(compositionTime: time, region: region))
  }
}
