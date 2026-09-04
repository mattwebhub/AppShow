import CoreImage
import QuartzCore

extension VideoPreviewContainer {
  func updateBlurRegions(_ regions: [BlurRegionData], time: Double) {
    lastBlurRegions = regions
    lastBlurRegionTime = time
    applyBlurRegions()
  }

  func applyBlurRegions() {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    defer { CATransaction.commit() }

    blurOverlayLayer.frame = screenContainerLayer.bounds
    let active = lastBlurRegions.filter {
      lastBlurRegionTime >= $0.startSeconds && lastBlurRegionTime <= $0.endSeconds
    }
    var layers = blurOverlayLayer.sublayers ?? []
    while layers.count < active.count {
      let filter = CIFilter(name: "CIGaussianBlur")!
      let layer = CALayer()
      layer.masksToBounds = true
      layer.backgroundFilters = [filter]
      blurOverlayLayer.addSublayer(layer)
      layers.append(layer)
    }
    while layers.count > active.count {
      layers.removeLast().removeFromSuperlayer()
    }

    let sourceFrame = screenPlayerLayer.frame
    for (region, layer) in zip(active, layers) {
      let normalized = region.normalized()
      layer.frame = CGRect(
        x: sourceFrame.minX + normalized.x * sourceFrame.width,
        y: sourceFrame.minY + (1 - normalized.y - normalized.height) * sourceFrame.height,
        width: normalized.width * sourceFrame.width,
        height: normalized.height * sourceFrame.height
      )
      (layer.backgroundFilters?.first as? CIFilter)?.setValue(normalized.radius, forKey: kCIInputRadiusKey)
    }
  }
}
