import CoreGraphics
import Foundation

struct ZoomKeyframe: Codable, Sendable, Equatable {
  var t: Double
  var zoomLevel: Double
  var centerX: Double
  var centerY: Double
  var isAuto: Bool
  var targetRect: CGRect? = nil
}

final class ZoomTimeline: @unchecked Sendable {
  private let lock = NSLock()
  private var keyframes: [ZoomKeyframe] = []

  init(keyframes: [ZoomKeyframe] = []) {
    self.keyframes = keyframes.sorted { $0.t < $1.t }
  }

  var allKeyframes: [ZoomKeyframe] {
    lock.lock()
    let kfs = keyframes
    lock.unlock()
    return kfs
  }

  func zoomRect(at time: Double, cursorPosition: CGPoint? = nil) -> CGRect {
    lock.lock()
    let kfs = keyframes
    lock.unlock()

    guard !kfs.isEmpty else {
      return CGRect(x: 0, y: 0, width: 1, height: 1)
    }

    if time <= kfs.first!.t {
      return resolvedRect(for: kfs.first!, cursorPosition: cursorPosition)
    }
    if time >= kfs.last!.t {
      return resolvedRect(for: kfs.last!, cursorPosition: cursorPosition)
    }

    var lo = 0
    var hi = kfs.count - 1
    while lo < hi - 1 {
      let mid = (lo + hi) / 2
      if kfs[mid].t <= time {
        lo = mid
      } else {
        hi = mid
      }
    }

    let k0 = kfs[lo]
    let k1 = kfs[hi]
    let span = k1.t - k0.t
    guard span > 0 else {
      return resolvedRect(for: k1, cursorPosition: cursorPosition)
    }

    let linearT = (time - k0.t) / span
    let t = easeInOut(linearT)

    let inv0 = 1.0 / k0.zoomLevel
    let inv1 = 1.0 / k1.zoomLevel
    let zoom = 1.0 / (inv0 + (inv1 - inv0) * t)

    if zoom <= 1.0 {
      return CGRect(x: 0, y: 0, width: 1, height: 1)
    }

    let c0 = resolvedCenter(for: k0, zoom: zoom, cursorPosition: cursorPosition)
    let c1 = resolvedCenter(for: k1, zoom: zoom, cursorPosition: cursorPosition)
    let cx = c0.x + (c1.x - c0.x) * t
    let cy = c0.y + (c1.y - c0.y) * t
    let visibleW = 1.0 / zoom
    let visibleH = 1.0 / zoom
    let originX = cx * (1 - visibleW)
    let originY = cy * (1 - visibleH)

    return CGRect(x: originX, y: originY, width: visibleW, height: visibleH)
  }

  private func resolvedCenter(for k: ZoomKeyframe, zoom: Double, cursorPosition: CGPoint?) -> CGPoint {
    guard k.targetRect == nil, let cursorPosition else { return CGPoint(x: k.centerX, y: k.centerY) }
    let margin = min(0.3, 1.0 / (2.0 * max(1, zoom)) + 0.05)
    return CGPoint(x: Self.softClamp(cursorPosition.x, margin: margin), y: Self.softClamp(cursorPosition.y, margin: margin))
  }

  private func resolvedRect(for k: ZoomKeyframe, cursorPosition: CGPoint?) -> CGRect {
    if k.zoomLevel <= 1.0 {
      return CGRect(x: 0, y: 0, width: 1, height: 1)
    }
    let visibleW = 1.0 / k.zoomLevel
    let visibleH = 1.0 / k.zoomLevel
    let center = resolvedCenter(for: k, zoom: k.zoomLevel, cursorPosition: cursorPosition)
    let originX = center.x * (1 - visibleW)
    let originY = center.y * (1 - visibleH)
    return CGRect(x: originX, y: originY, width: visibleW, height: visibleH)
  }

  static func followCursor(_ rect: CGRect, cursorPosition: CGPoint) -> CGRect {
    guard rect.width < 1.0 || rect.height < 1.0 else { return rect }
    let zoomScale = 1.0 / min(rect.width, rect.height)
    let margin = min(0.3, 1.0 / (2.0 * zoomScale) + 0.05)
    let cx = softClamp(cursorPosition.x, margin: margin)
    let cy = softClamp(cursorPosition.y, margin: margin)
    let originX = cx * (1 - rect.width)
    let originY = cy * (1 - rect.height)
    return CGRect(x: originX, y: originY, width: rect.width, height: rect.height)
  }

  private static func softClamp(_ value: CGFloat, margin: CGFloat) -> CGFloat {
    if value < margin {
      let t = max(0, value / margin)
      return margin * softEase(t)
    }
    if value > 1.0 - margin {
      let t = max(0, (1.0 - value) / margin)
      return 1.0 - margin * softEase(t)
    }
    return value
  }

  private static func softEase(_ t: CGFloat) -> CGFloat {
    -t * t * t + 2 * t * t
  }

  private func easeInOut(_ t: Double) -> Double {
    t * t * t * (t * (t * 6 - 15) + 10)
  }
}
