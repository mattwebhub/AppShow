import AVFoundation
import CoreMedia
import Testing

@testable import AppShow

struct WebcamSplitTests {
  @Test(arguments: [CameraRegionType.leftHalf, .rightHalf, .leftThird, .rightThird])
  func splitPreservesScreenAspectAndReservesRequestedSide(_ type: CameraRegionType) throws {
    let canvas = CGRect(x: 20, y: 30, width: 1200, height: 800)
    let target = try #require(WebcamSplitLayout(type: type, canvas: canvas))
    let fraction: CGFloat = type == .leftHalf || type == .rightHalf ? 0.5 : 1.0 / 3
    #expect(abs(target.camera.width - canvas.width * fraction) < 0.001)
    #expect(target.camera.height == canvas.height)
    #expect(target.camera.maxX <= canvas.maxX)
    #expect(target.camera.intersection(target.screenArea).width <= 0)
    let source = CGSize(width: 1920, height: 1080)
    let screen = target.screenRect(screenSize: source, originalArea: canvas, progress: 1)
    #expect(abs(screen.width / screen.height - source.width / source.height) < 0.001)
    #expect(target.screenArea.contains(screen))
    #expect(target.screenRect(screenSize: source, originalArea: canvas, progress: 0) == AVMakeRect(aspectRatio: source, insideRect: canvas))
    let midpoint = target.screenRect(screenSize: source, originalArea: canvas, progress: 0.5)
    #expect(midpoint == CameraLayout.interpolatedRect(from: AVMakeRect(aspectRatio: source, insideRect: canvas), to: screen, progress: 0.5))
    let encoded = try JSONEncoder().encode(CameraRegionData(startSeconds: 1, endSeconds: 5, type: type))
    #expect(try JSONDecoder().decode(CameraRegionData.self, from: encoded).type == type)
  }

  @Test func screenCornerRadiusScalesWithTheSplitVideo() {
    let size = CGSize(width: 120, height: 80)
    let instruction = CompositionInstruction(
      timeRange: .zero,
      screenTrackID: 1,
      webcamTrackID: nil,
      cameraRect: nil,
      cameraCornerRadius: 0,
      outputSize: size,
      videoCornerRadius: 10
    )
    let radius = FrameRenderer.screenCornerRadius(
      instruction: instruction,
      screenSize: size,
      videoRect: CGRect(x: 60, y: 20, width: 60, height: 40)
    )
    #expect(radius == 5)
  }

  @Test func splitMetadataAndAnimationClockSurviveCuts() throws {
    let region = RegionTransitionInfo(
      timeRange: CMTimeRange(start: .zero, end: CMTime(seconds: 6, preferredTimescale: 600)),
      entryTransition: .scale,
      entryDuration: 1,
      exitTransition: .scale,
      exitDuration: 1,
      cameraPresentation: .rightThird
    )
    var config = ExportConfiguration(cameraLayout: CameraLayout(), trimRange: region.timeRange)
    config.cameraFullscreenRegions = [region]
    let remapped = VideoCompositor.remapAllRegions(
      config: config,
      hasVideoRegions: true,
      videoSegments: [
        .init(
          sourceRange: CMTimeRange(start: CMTime(seconds: 2, preferredTimescale: 600), end: CMTime(seconds: 4, preferredTimescale: 600)),
          compositionStart: .zero
        )
      ],
      effectiveTrim: region.timeRange,
      scaleX: 1
    )
    let mapped = try #require(remapped.cameraFullscreen.first)
    #expect(mapped.cameraPresentation == .rightThird)
    #expect(FrameRenderer.computeRegionTransition(compositionTime: .zero, region: mapped) == 1)
  }
}
