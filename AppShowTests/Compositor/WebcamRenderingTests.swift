import AVFoundation
import AppKit
import CoreImage
import CoreMedia
import CoreVideo
import Testing

@testable import AppShow

struct WebcamRenderingTests {
  @Test func hdrFocusStartsAtTheCircleAndExpandsToFillTheCanvas() throws {
    let canvas = CGRect(x: 0, y: 0, width: 64, height: 36)
    let camera = CIImage(color: CIColor(red: 0, green: 0, blue: 1)).cropped(to: CGRect(x: 0, y: 0, width: 40, height: 30))
    let background = CIImage(color: CIColor(red: 0, green: 1, blue: 0)).cropped(to: canvas)
    let instruction = CompositionInstruction(
      timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 2, preferredTimescale: 600)),
      screenTrackID: 1,
      webcamTrackID: 2,
      cameraRect: CGRect(x: 4, y: 4, width: 12, height: 12),
      cameraCornerRadius: 6,
      outputSize: canvas.size,
      cameraFullscreenFillMode: .fill
    )
    for progress: CGFloat in [0, 0.5, 1] {
      let result = FrameRenderer.hdrComposeWebcam(
        webcamImage: camera,
        over: background,
        instruction: instruction,
        compositionTime: .zero,
        outputWidth: 64,
        outputHeight: 36,
        isCamFullscreen: true,
        regionTransition: (.scale, progress)
      )
      let point = progress == 0 ? CGPoint(x: 10, y: 26) : progress == 1 ? CGPoint(x: 1, y: 1) : CGPoint(x: 20, y: 20)
      let pixel = rgba(result, at: point)
      #expect(pixel[2] > 240 && pixel[1] < 15)
      if progress == 0 {
        let corner = rgba(result, at: CGPoint(x: 4, y: 31))
        #expect(corner[1] > 240 && corner[2] < 15)
      }
    }
  }

  @Test func sdrFocusFillsTheCanvasAtTheEndOfTheAnimation() throws {
    let canvas = CGRect(x: 0, y: 0, width: 64, height: 36)
    let blue = CIImage(color: CIColor(red: 0, green: 0, blue: 1)).cropped(to: CGRect(x: 0, y: 0, width: 40, height: 30))
    let camera = try #require(FrameRenderer.hdrCIContext.createCGImage(blue, from: blue.extent))
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    let context = try #require(
      CGContext(
        data: nil,
        width: 64,
        height: 36,
        bitsPerComponent: 8,
        bytesPerRow: 256,
        space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
    )
    let instruction = CompositionInstruction(
      timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 2, preferredTimescale: 600)),
      screenTrackID: 1,
      webcamTrackID: 2,
      cameraRect: CGRect(x: 4, y: 4, width: 12, height: 12),
      cameraCornerRadius: 6,
      outputSize: canvas.size,
      cameraFullscreenFillMode: .fill
    )
    for progress: CGFloat in [0, 0.5, 1] {
      context.setFillColor(CGColor(red: 0, green: 1, blue: 0, alpha: 1))
      context.fill(canvas)
      FrameRenderer.drawWebcam(
        in: context,
        webcamImage: camera,
        instruction: instruction,
        compositionTime: .zero,
        outputWidth: 64,
        outputHeight: 36,
        isCamFullscreen: true,
        regionTransition: (.scale, progress),
        colorSpace: space
      )
      let result = CIImage(cgImage: try #require(context.makeImage()))
      let point = progress == 0 ? CGPoint(x: 10, y: 26) : progress == 1 ? CGPoint(x: 1, y: 1) : CGPoint(x: 20, y: 20)
      let pixel = rgba(result, at: point)
      #expect(pixel[2] > 240 && pixel[1] < 15)
    }
  }

  @MainActor
  @Test func previewUsesTheSameCircleToFullscreenGeometry() {
    let canvas = CGRect(x: 0, y: 0, width: 64, height: 36)
    let view = VideoPreviewContainer(frame: canvas)
    view.webcamPlayerLayer.player = AVPlayer()
    view.isCameraFullscreen = true
    view.currentFullscreenFillMode = .fill
    view.cameraTransitionType = .scale
    for progress: CGFloat in [0, 0.5, 1] {
      view.cameraTransitionProgress = progress
      view.updateCameraLayout(
        CameraLayout(relativeX: 4.0 / 64, relativeY: 4.0 / 36, relativeWidth: 12.0 / 64),
        webcamSize: CGSize(width: 40, height: 30),
        screenSize: canvas.size,
        canvasSize: canvas.size,
        cameraAspect: .ratio1x1,
        cameraCornerRadius: 50
      )
      let expected = CameraLayout.interpolatedRect(from: CGRect(x: 4, y: 20, width: 12, height: 12), to: canvas, progress: progress)
      #expect(view.webcamWrapper.frame == expected)
      #expect(view.webcamView.layer?.cornerRadius == 6 * (1 - progress))
    }
  }

  @MainActor
  @Test(arguments: [CameraRegionType.leftHalf, .rightHalf, .leftThird, .rightThird])
  func splitPreviewAndBothRenderersAgree(_ type: CameraRegionType) throws {
    let canvas = CGRect(x: 0, y: 0, width: 120, height: 80)
    let cameraImage = CIImage(color: CIColor(red: 0, green: 0, blue: 1)).cropped(to: CGRect(x: 0, y: 0, width: 40, height: 30))
    let green = CIImage(color: CIColor(red: 0, green: 1, blue: 0)).cropped(to: canvas)
    let image = try #require(FrameRenderer.hdrCIContext.createCGImage(cameraImage, from: cameraImage.extent))
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    let context = try #require(
      CGContext(
        data: nil,
        width: 120,
        height: 80,
        bitsPerComponent: 8,
        bytesPerRow: 480,
        space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
    )
    let region = RegionTransitionInfo(
      timeRange: CMTimeRange(start: .zero, end: CMTime(seconds: 4, preferredTimescale: 600)),
      entryTransition: .scale,
      entryDuration: 1,
      exitTransition: .scale,
      exitDuration: 1,
      cameraPresentation: type
    )
    let instruction = CompositionInstruction(
      timeRange: region.timeRange,
      screenTrackID: 1,
      webcamTrackID: 2,
      cameraRect: CGRect(x: 90, y: 50, width: 24, height: 24),
      cameraCornerRadius: 12,
      outputSize: canvas.size,
      cameraFullscreenRegions: [region]
    )
    let split = try #require(WebcamSplitLayout(type: type, canvas: canvas))
    let view = VideoPreviewContainer(frame: canvas)
    view.webcamPlayerLayer.player = AVPlayer()
    view.cameraSplitType = type
    view.cameraTransitionType = .scale
    for time in [0.0, 0.5, 2, 3.5] {
      let t = CMTime(seconds: time, preferredTimescale: 600)
      let p = FrameRenderer.computeRegionTransition(compositionTime: t, region: region)
      view.cameraTransitionProgress = p
      view.updateCameraLayout(
        CameraLayout(relativeX: 0.75, relativeY: 0.625, relativeWidth: 0.2),
        webcamSize: CGSize(width: 40, height: 30),
        screenSize: canvas.size,
        canvasSize: canvas.size,
        cameraAspect: .ratio1x1,
        cameraCornerRadius: 50
      )
      let resolved = try #require(FrameRenderer.splitCamera(instruction: instruction, time: t, canvas: canvas))
      #expect(view.webcamWrapper.frame == resolved.rect)
      #expect(view.webcamView.layer?.cornerRadius == resolved.cornerRadius)
      let expectedScreen = split.screenRect(screenSize: canvas.size, originalArea: canvas, progress: p)
      #expect(abs(view.screenContainerLayer.frame.minX - expectedScreen.minX) < 0.000001)
      #expect(abs(view.screenContainerLayer.frame.minY - expectedScreen.minY) < 0.000001)
      #expect(abs(view.screenContainerLayer.frame.width - expectedScreen.width) < 0.000001)
      #expect(abs(view.screenContainerLayer.frame.height - expectedScreen.height) < 0.000001)
      context.setFillColor(CGColor(red: 0, green: 1, blue: 0, alpha: 1))
      context.fill(canvas)
      FrameRenderer.drawWebcam(
        in: context,
        webcamImage: image,
        instruction: instruction,
        compositionTime: t,
        outputWidth: 120,
        outputHeight: 80,
        isCamFullscreen: false,
        regionTransition: (.scale, p),
        colorSpace: space
      )
      let sdr = CIImage(cgImage: try #require(context.makeImage()))
      let hdr = FrameRenderer.hdrComposeWebcam(
        webcamImage: cameraImage,
        over: green,
        instruction: instruction,
        compositionTime: t,
        outputWidth: 120,
        outputHeight: 80,
        isCamFullscreen: false,
        regionTransition: (.scale, p)
      )
      let middle = CGPoint(x: resolved.rect.midX, y: resolved.rect.midY)
      #expect(rgba(sdr, at: middle)[2] > 240)
      #expect(rgba(hdr, at: middle)[2] > 240)
      if p == 1 {
        let screenPoint = CGPoint(x: split.screenArea.midX, y: split.screenArea.midY)
        #expect(rgba(sdr, at: screenPoint)[1] > 240)
        #expect(rgba(hdr, at: screenPoint)[1] > 240)
      }
    }
  }

  private func rgba(_ image: CIImage, at point: CGPoint) -> [UInt8] {
    var values = [UInt8](repeating: 0, count: 4)
    values.withUnsafeMutableBytes { bytes in
      FrameRenderer.hdrCIContext.render(
        image,
        toBitmap: bytes.baseAddress!,
        rowBytes: 4,
        bounds: CGRect(origin: point, size: CGSize(width: 1, height: 1)),
        format: .RGBA8,
        colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
      )
    }
    return values
  }
}
