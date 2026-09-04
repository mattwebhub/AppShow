import CoreMedia
import Foundation
import Testing

@testable import Reframed

struct InstructionBuilderTests {
  private static let screen = CGSize(width: 1920, height: 1080)

  private static let canvasSizes: [(aspect: CanvasAspect, expected: CGSize)] = [
    (.original, CGSize(width: 1920, height: 1080)),
    (.ratio16x9, CGSize(width: 1920, height: 1080)),
    (.ratio1x1, CGSize(width: 1920, height: 1920)),
    (.ratio4x3, CGSize(width: 1920, height: 1440)),
    (.ratio9x16, CGSize(width: 607.5, height: 1080)),
  ]

  @Test(arguments: canvasSizes.map(\.aspect)) func canvasSizeFollowsAspect(aspect: CanvasAspect) throws {
    let expected = try #require(Self.canvasSizes.first { $0.aspect == aspect }?.expected)

    let size = VideoCompositor.computeCanvasSize(screenNaturalSize: Self.screen, canvasAspect: aspect, padding: 0)

    #expect(size == expected)
  }

  @Test func allCanvasAspectsAreCovered() {
    #expect(Set(Self.canvasSizes.map(\.aspect)) == Set(CanvasAspect.allCases))
  }

  @Test func originalAspectWithPaddingScalesBothDimensions() {
    let size = VideoCompositor.computeCanvasSize(screenNaturalSize: Self.screen, canvasAspect: .original, padding: 0.1)

    #expect(abs(size.width - 2304) < 1e-9)
    #expect(abs(size.height - 1296) < 1e-9)
  }

  @Test func fixedAspectIgnoresPadding() {
    let size = VideoCompositor.computeCanvasSize(screenNaturalSize: Self.screen, canvasAspect: .ratio16x9, padding: 0.1)

    #expect(size == CGSize(width: 1920, height: 1080))
  }

  @Test func renderSizeIsUnchangedForOriginalResolution() {
    let canvas = CGSize(width: 2304, height: 1296)

    let size = VideoCompositor.computeRenderSize(canvasSize: canvas, resolution: .original)

    #expect(size == canvas)
  }

  @Test(arguments: [
    (ExportResolution.uhd4k, CGSize(width: 3840, height: 2160)),
    (ExportResolution.fhd1080, CGSize(width: 1920, height: 1080)),
    (ExportResolution.hd720, CGSize(width: 1280, height: 720)),
  ])
  func renderSizeKeepsAspect(resolution: ExportResolution, expected: CGSize) {
    let size = VideoCompositor.computeRenderSize(canvasSize: CGSize(width: 2304, height: 1296), resolution: resolution)

    #expect(size == expected)
  }

  @Test func renderSizeRoundsHeight() {
    let size = VideoCompositor.computeRenderSize(canvasSize: CGSize(width: 1000, height: 333), resolution: .hd720)

    #expect(size == CGSize(width: 1280, height: 426))
  }

  private func result(
    webcam: Bool = false,
    quality: CaptureQuality = .standard
  ) -> RecordingResult {
    RecordingResult(
      screenVideoURL: URL(fileURLWithPath: "/dev/null/screen.mp4"),
      webcamVideoURL: webcam ? URL(fileURLWithPath: "/dev/null/webcam.mp4") : nil,
      systemAudioURL: nil,
      microphoneAudioURL: nil,
      cursorMetadataURL: nil,
      screenSize: Self.screen,
      webcamSize: webcam ? CGSize(width: 640, height: 480) : nil,
      fps: 60,
      captureQuality: quality,
      isHDR: false
    )
  }

  private func config() -> ExportConfiguration {
    ExportConfiguration(cameraLayout: CameraLayout(), trimRange: CMTimeRange(start: .zero, duration: .zero))
  }

  private func needsCompositor(
    _ config: ExportConfiguration,
    result: RecordingResult? = nil,
    clickSoundURL: URL? = nil,
    hasVideoRegions: Bool = false
  ) -> Bool {
    VideoCompositor.checkNeedsCompositor(
      result: result ?? self.result(),
      config: config,
      clickSoundURL: clickSoundURL,
      hasVideoRegions: hasVideoRegions,
      screenNaturalSize: Self.screen
    )
  }

  private func snapshot() -> CursorMetadataSnapshot {
    CursorMetadataSnapshot(samples: [], clicks: [], captureAreaWidth: 1920, captureAreaHeight: 1080)
  }

  @Test func standardCaptureWithDefaultSettingsIsPassthrough() {
    #expect(!needsCompositor(config()))
  }

  @Test func blackSolidBackgroundIsStillPassthrough() {
    var config = config()
    config.backgroundStyle = .solidColor(CodableColor(r: 0, g: 0, b: 0))

    #expect(!needsCompositor(config))
  }

  @Test func nonBlackSolidBackgroundNeedsCompositor() {
    var config = config()
    config.backgroundStyle = .solidColor(CodableColor(r: 1, g: 0, b: 0))

    #expect(needsCompositor(config))
  }

  @Test func gradientBackgroundNeedsCompositor() {
    var config = config()
    config.backgroundStyle = .gradient(0)

    #expect(needsCompositor(config))
  }

  @Test func imageBackgroundNeedsCompositor() {
    var config = config()
    config.backgroundStyle = .image("background-image.png")

    #expect(needsCompositor(config))
  }

  @Test func paddingNeedsCompositor() {
    var config = config()
    config.padding = 0.05

    #expect(needsCompositor(config))
  }

  @Test func videoCornerRadiusNeedsCompositor() {
    var config = config()
    config.videoCornerRadius = 4

    #expect(needsCompositor(config))
  }

  @Test func videoShadowNeedsCompositor() {
    var config = config()
    config.videoShadow = 10

    #expect(needsCompositor(config))
  }

  @Test func canvasAspectNeedsCompositor() {
    var config = config()
    config.canvasAspect = .ratio1x1

    #expect(needsCompositor(config))
  }

  @Test func webcamNeedsCompositor() {
    #expect(needsCompositor(config(), result: result(webcam: true)))
  }

  @Test func cursorSnapshotNeedsCompositor() {
    var config = config()
    config.cursorSnapshot = snapshot()

    #expect(needsCompositor(config))
  }

  @Test func zoomTimelineNeedsCompositor() {
    var config = config()
    config.zoomTimeline = ZoomTimeline()

    #expect(needsCompositor(config))
  }

  @Test func captionsWithSegmentsNeedCompositor() {
    var config = config()
    config.captionsEnabled = true
    config.captionSegments = [CaptionSegment(startSeconds: 0, endSeconds: 1, text: "hi")]

    #expect(needsCompositor(config))
  }

  @Test func captionsWithoutSegmentsStayPassthrough() {
    var config = config()
    config.captionsEnabled = true

    #expect(!needsCompositor(config))
  }

  @Test func gifFormatNeedsCompositor() {
    var config = config()
    config.exportSettings.format = .gif

    #expect(needsCompositor(config))
  }

  @Test func clickSoundNeedsCompositor() {
    #expect(needsCompositor(config(), clickSoundURL: URL(fileURLWithPath: "/dev/null/click.m4a")))
  }

  @Test func videoCutsNeedCompositor() {
    #expect(needsCompositor(config(), hasVideoRegions: true))
  }

  @Test func spotlightNeedsCompositorOnlyWithCursorSnapshot() {
    var config = config()
    config.spotlightRegions = [SpotlightRegionData(startSeconds: 0, endSeconds: 1)]

    #expect(!needsCompositor(config))

    config.cursorSnapshot = snapshot()

    #expect(needsCompositor(config))
  }

  @Test func codecChangeNeedsCompositor() {
    var config = config()
    config.exportSettings.codec = .h264

    #expect(needsCompositor(config))
  }

  @Test func resolutionChangeNeedsCompositor() {
    var config = config()
    config.exportSettings.resolution = .fhd1080

    #expect(needsCompositor(config))
  }

  @Test func fpsChangeNeedsCompositor() {
    var config = config()
    config.exportSettings.fps = .fps30

    #expect(needsCompositor(config))
  }

  @Test func proResCaptureIsPassthroughOnlyWithMatchingCodec() {
    var config = config()

    #expect(needsCompositor(config, result: result(quality: .high)))

    config.exportSettings.codec = .proRes422

    #expect(!needsCompositor(config, result: result(quality: .high)))
    #expect(needsCompositor(config, result: result(quality: .veryHigh)))

    config.exportSettings.codec = .proRes4444

    #expect(!needsCompositor(config, result: result(quality: .veryHigh)))
  }

  @Test func textOverlayNeedsCompositor() {
    var config = config()
    config.textOverlays = [TextOverlayData(startSeconds: 0, endSeconds: 1)]

    #expect(needsCompositor(config))
  }

  @Test func imageOverlayNeedsCompositor() {
    var config = config()
    config.imageOverlays = [ImageOverlayData(startSeconds: 0, endSeconds: 1, filename: "image.png")]

    #expect(needsCompositor(config))
  }
}
