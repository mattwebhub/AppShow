import CoreGraphics
import Foundation

struct CameraLayout: Sendable, Codable, Equatable {
  var relativeX: CGFloat = 0.02
  var relativeY: CGFloat = 0.02
  var relativeWidth: CGFloat = 0.25

  static func interpolatedRect(from: CGRect, to: CGRect, progress: CGFloat) -> CGRect {
    let p = max(0, min(1, progress))
    return CGRect(
      x: from.minX + (to.minX - from.minX) * p,
      y: from.minY + (to.minY - from.minY) * p,
      width: from.width + (to.width - from.width) * p,
      height: from.height + (to.height - from.height) * p
    )
  }

  func pixelRect(screenSize: CGSize, webcamSize: CGSize, cameraAspect: CameraAspect = .original) -> CGRect {
    let w = screenSize.width * relativeWidth
    let aspect = cameraAspect.heightToWidthRatio(webcamSize: webcamSize)
    let h = w * aspect
    let x = screenSize.width * relativeX
    let y = screenSize.height * relativeY
    return CGRect(x: x, y: y, width: w, height: h)
  }
}

struct WebcamPresentation: Sendable, Codable, Equatable {
  var corner: CameraCorner = .bottomRight
  var relativeWidth: CGFloat = 0.2

  var normalized: WebcamPresentation {
    WebcamPresentation(corner: corner, relativeWidth: relativeWidth.isFinite ? min(0.5, max(0.1, relativeWidth)) : 0.2)
  }

  func layout(canvasSize: CGSize) -> CameraLayout {
    let ratio = max(canvasSize.width, 1) / max(canvasSize.height, 1)
    let width = min(normalized.relativeWidth, 0.96 / ratio)
    let height = width * ratio
    let marginX: CGFloat = min(0.02, max(0, (1 - height) / (2 * ratio)))
    let marginY = marginX * ratio
    let right = corner == .topRight || corner == .bottomRight
    let bottom = corner == .bottomLeft || corner == .bottomRight
    return CameraLayout(
      relativeX: right ? 1 - width - marginX : marginX,
      relativeY: bottom ? 1 - height - marginY : marginY,
      relativeWidth: width
    )
  }
}
