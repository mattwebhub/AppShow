import AVFoundation

extension FrameRenderer {
  static func screenCornerRadius(instruction: CompositionInstruction, screenSize: CGSize, videoRect: CGRect) -> CGFloat {
    let padded = CGRect(origin: .zero, size: instruction.outputSize).insetBy(dx: instruction.paddingH, dy: instruction.paddingV)
    let original = AVMakeRect(aspectRatio: screenSize, insideRect: padded)
    let ratio = min(videoRect.width, videoRect.height) / max(1, min(original.width, original.height))
    return instruction.videoCornerRadius * ratio
  }

  static func splitCamera(instruction: CompositionInstruction, time: CMTime, canvas: CGRect) -> ResolvedCamera? {
    guard let split = instruction.webcamSplit(at: time, canvas: canvas), let pip = instruction.cameraRect else { return nil }
    let source = CGRect(x: pip.minX, y: canvas.height - pip.maxY, width: pip.width, height: pip.height)
    return ResolvedCamera(
      rect: CameraLayout.interpolatedRect(from: source, to: split.layout.camera, progress: split.progress),
      cornerRadius: instruction.cameraCornerRadius * (1 - split.progress),
      borderWidth: instruction.cameraBorderWidth * (1 - split.progress),
      borderColor: instruction.cameraBorderColor,
      shadow: instruction.cameraShadow * (1 - split.progress),
      mirrored: instruction.cameraMirrored
    )
  }
}
