import CoreImage
import CoreMedia

extension FrameRenderer {
  static let screenEffectsCIContext = CIContext(options: [.cacheIntermediates: false])

  static func applyingBlurRegions(
    to source: CIImage,
    instruction: CompositionInstruction,
    compositionTime: CMTime
  ) -> CIImage {
    let active = instruction.blurRegions.filter { $0.timeRange.containsTime(compositionTime) }
    guard !active.isEmpty else { return source }
    let extent = source.extent
    return active.reduce(source) { image, region in
      let rect = CGRect(
        x: extent.minX + region.rect.minX * extent.width,
        y: extent.minY + (1 - region.rect.maxY) * extent.height,
        width: region.rect.width * extent.width,
        height: region.rect.height * extent.height
      ).intersection(extent)
      guard !rect.isNull, rect.width > 0, rect.height > 0 else { return image }
      let blurred =
        source
        .clampedToExtent()
        .applyingGaussianBlur(sigma: Double(region.radius))
        .cropped(to: rect)
      return blurred.composited(over: image)
    }
  }

  static func applyingBlurRegions(
    to source: CGImage,
    instruction: CompositionInstruction,
    compositionTime: CMTime
  ) -> CGImage {
    guard instruction.blurRegions.contains(where: { $0.timeRange.containsTime(compositionTime) }) else { return source }
    let image = CIImage(cgImage: source)
    let result = applyingBlurRegions(to: image, instruction: instruction, compositionTime: compositionTime)
    return screenEffectsCIContext.createCGImage(result, from: image.extent) ?? source
  }
}
