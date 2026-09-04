import CoreMedia
import Testing

@testable import Reframed

struct RegionRemappingTests {
  private func seconds(_ value: Double) -> CMTime {
    CMTime(seconds: value, preferredTimescale: 600)
  }

  private func range(_ start: Double, _ end: Double) -> CMTimeRange {
    CMTimeRange(start: seconds(start), end: seconds(end))
  }

  private func region(_ start: Double, _ end: Double) -> RegionTransitionInfo {
    RegionTransitionInfo(
      timeRange: range(start, end),
      entryTransition: .fade,
      entryDuration: 0.25,
      exitTransition: .slide,
      exitDuration: 0.5
    )
  }

  private func config(trim: CMTimeRange) -> ExportConfiguration {
    ExportConfiguration(cameraLayout: CameraLayout(), trimRange: trim)
  }

  private func remap(_ config: ExportConfiguration, trim: CMTimeRange) -> VideoCompositor.RemappedRegions {
    VideoCompositor.remapAllRegions(
      config: config,
      hasVideoRegions: false,
      videoSegments: [],
      effectiveTrim: trim,
      scaleX: 1
    )
  }

  @Test func regionOverlappingTrimStartIsClippedAndShiftedByTrimStart() throws {
    let trim = range(5, 10)
    var config = config(trim: trim)
    config.cameraFullscreenRegions = [region(2, 8)]

    let remapped = remap(config, trim: trim)

    #expect(remapped.cameraFullscreen.count == 1)
    let result = try #require(remapped.cameraFullscreen.first)
    #expect(result.timeRange.start.seconds == 0)
    #expect(result.timeRange.end.seconds == 3)
    #expect(result.entryTransition == .fade)
    #expect(result.entryDuration == 0.25)
    #expect(result.exitTransition == .slide)
    #expect(result.exitDuration == 0.5)
  }

  @Test func regionEntirelyBeforeTrimStartIsDropped() {
    let trim = range(5, 10)
    var config = config(trim: trim)
    config.cameraFullscreenRegions = [region(1, 4)]
    config.cameraHiddenRegions = [region(0, 5)]

    let remapped = remap(config, trim: trim)

    #expect(remapped.cameraFullscreen.isEmpty)
    #expect(remapped.cameraHidden.isEmpty)
  }

  @Test func regionEntirelyAfterTrimEndIsDropped() {
    let trim = range(5, 10)
    var config = config(trim: trim)
    config.cameraHiddenRegions = [region(10, 12), region(11, 14)]

    let remapped = remap(config, trim: trim)

    #expect(remapped.cameraHidden.isEmpty)
  }

  @Test func regionSpanningTrimIsClippedToTrimLength() throws {
    let trim = range(5, 10)
    var config = config(trim: trim)
    config.cameraHiddenRegions = [region(0, 20)]

    let remapped = remap(config, trim: trim)

    let result = try #require(remapped.cameraHidden.first)
    #expect(result.timeRange.start.seconds == 0)
    #expect(result.timeRange.end.seconds == 5)
  }

  @Test func spotlightRegionIsShiftedByTrimStart() throws {
    let trim = range(5, 10)
    var config = config(trim: trim)
    let original = SpotlightRegionData(startSeconds: 2, endSeconds: 8, customRadius: 120)
    config.spotlightRegions = [original, SpotlightRegionData(startSeconds: 0, endSeconds: 4)]

    let remapped = remap(config, trim: trim)

    #expect(remapped.spotlight.count == 1)
    let result = try #require(remapped.spotlight.first)
    #expect(result.id == original.id)
    #expect(result.startSeconds == 0)
    #expect(result.endSeconds == 3)
    #expect(result.customRadius == 120)
  }

  @Test func captionWordsAreClippedAndShiftedByTrimStart() throws {
    let trim = range(5, 10)
    var config = config(trim: trim)
    config.captionsEnabled = true
    config.captionSegments = [
      CaptionSegment(
        startSeconds: 2,
        endSeconds: 8,
        text: "hello world again",
        words: [
          CaptionWord(word: "hello", startSeconds: 2, endSeconds: 4),
          CaptionWord(word: "world", startSeconds: 4, endSeconds: 6),
          CaptionWord(word: "again", startSeconds: 6, endSeconds: 8),
        ]
      )
    ]

    let remapped = remap(config, trim: trim)

    let result = try #require(remapped.captions.first)
    #expect(result.startSeconds == 0)
    #expect(result.endSeconds == 3)
    #expect(result.words?.map(\.word) == ["world", "again"])
    #expect(result.words?.map(\.startSeconds) == [0, 1])
    #expect(result.words?.map(\.endSeconds) == [1, 3])
  }

  @Test func captionsAreDroppedWhenDisabled() {
    let trim = range(0, 10)
    var config = config(trim: trim)
    config.captionsEnabled = false
    config.captionSegments = [CaptionSegment(startSeconds: 1, endSeconds: 2, text: "muted")]

    let remapped = remap(config, trim: trim)

    #expect(remapped.captions.isEmpty)
  }

  @Test func videoRegionsAreEmptyWithoutCuts() {
    let trim = range(0, 10)
    var config = config(trim: trim)
    config.videoRegions = [region(1, 2)]

    let remapped = remap(config, trim: trim)

    #expect(remapped.video.isEmpty)
  }

  private func segments() -> [VideoCompositor.VideoSegment] {
    [
      VideoCompositor.VideoSegment(sourceRange: range(0, 2), compositionStart: seconds(0)),
      VideoCompositor.VideoSegment(sourceRange: range(5, 7), compositionStart: seconds(2)),
    ]
  }

  private func remapWithCuts(_ config: ExportConfiguration, scaleX: CGFloat = 1) -> VideoCompositor.RemappedRegions {
    VideoCompositor.remapAllRegions(
      config: config,
      hasVideoRegions: true,
      videoSegments: segments(),
      effectiveTrim: range(0, 10),
      scaleX: scaleX
    )
  }

  private func customRegion(_ start: Double, _ end: Double, borderWidth: CGFloat) -> CameraCustomRegion {
    CameraCustomRegion(
      timeRange: range(start, end),
      layout: CameraLayout(relativeX: 0.1, relativeY: 0.2, relativeWidth: 0.3),
      cameraAspect: .ratio1x1,
      cornerRadius: 10,
      shadow: 20,
      borderWidth: borderWidth,
      borderColor: CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1),
      mirrored: true,
      entryTransition: .scale,
      entryDuration: 0.3,
      exitTransition: .fade,
      exitDuration: 0.4
    )
  }

  @Test func cameraRegionSpanningTwoSegmentsIsSplitPerSegment() throws {
    var config = config(trim: range(0, 10))
    config.cameraFullscreenRegions = [region(1, 6)]

    let remapped = remapWithCuts(config)

    #expect(remapped.cameraFullscreen.count == 2)
    let first = try #require(remapped.cameraFullscreen.first)
    let second = try #require(remapped.cameraFullscreen.last)
    #expect(first.timeRange.start.seconds == 1)
    #expect(first.timeRange.end.seconds == 2)
    #expect(second.timeRange.start.seconds == 2)
    #expect(second.timeRange.end.seconds == 3)
    #expect(second.entryTransition == .fade)
    #expect(second.exitTransition == .slide)
  }

  @Test func cameraRegionInsideRemovedGapIsDroppedUnderCuts() {
    var config = config(trim: range(0, 10))
    config.cameraHiddenRegions = [region(2.5, 4.5)]

    let remapped = remapWithCuts(config)

    #expect(remapped.cameraHidden.isEmpty)
  }

  @Test func videoRegionsAreKeptOnlyWhenMatchingASegmentWithinTolerance() {
    var config = config(trim: range(0, 10))
    config.videoRegions = [region(0, 2.005), region(3, 4), region(5, 7)]

    let remapped = remapWithCuts(config)

    #expect(remapped.video.map { $0.timeRange.start.seconds } == [0, 2])
    #expect(remapped.video.map { $0.timeRange.end.seconds } == [2, 4])
  }

  @Test func videoRegionOffByMoreThanToleranceIsDropped() {
    var config = config(trim: range(0, 10))
    config.videoRegions = [region(0, 2.02), region(5.02, 7)]

    let remapped = remapWithCuts(config)

    #expect(remapped.video.isEmpty)
  }

  @Test func customRegionBorderWidthIsScaledByScaleXUnderCuts() throws {
    var config = config(trim: range(0, 10))
    config.cameraCustomRegions = [customRegion(1, 6, borderWidth: 4)]

    let remapped = remapWithCuts(config, scaleX: 0.5)

    #expect(remapped.cameraCustom.count == 2)
    let first = try #require(remapped.cameraCustom.first)
    #expect(first.borderWidth == 2)
    #expect(first.timeRange.start.seconds == 1)
    #expect(first.timeRange.end.seconds == 2)
    #expect(first.layout == CameraLayout(relativeX: 0.1, relativeY: 0.2, relativeWidth: 0.3))
    #expect(first.cameraAspect == .ratio1x1)
    #expect(first.cornerRadius == 10)
    #expect(first.shadow == 20)
    #expect(first.mirrored)
    #expect(first.entryTransition == .scale)
    #expect(first.exitDuration == 0.4)
  }

  @Test func customRegionBorderWidthIsNotScaledOnTrimPath() throws {
    let trim = range(0, 10)
    var config = config(trim: trim)
    config.cameraCustomRegions = [customRegion(1, 6, borderWidth: 4)]

    let remapped = VideoCompositor.remapAllRegions(
      config: config,
      hasVideoRegions: false,
      videoSegments: [],
      effectiveTrim: trim,
      scaleX: 0.5
    )

    let result = try #require(remapped.cameraCustom.first)
    #expect(result.borderWidth == 4)
  }

  @Test func captionSegmentSpanningTwoSegmentsIsSplitWithWordsRemapped() throws {
    var config = config(trim: range(0, 10))
    config.captionsEnabled = true
    config.captionSegments = [
      CaptionSegment(
        startSeconds: 1,
        endSeconds: 6,
        text: "one two three",
        words: [
          CaptionWord(word: "one", startSeconds: 1, endSeconds: 1.5),
          CaptionWord(word: "two", startSeconds: 1.5, endSeconds: 3),
          CaptionWord(word: "three", startSeconds: 5.5, endSeconds: 6),
        ]
      )
    ]

    let remapped = remapWithCuts(config)

    #expect(remapped.captions.count == 2)
    let first = try #require(remapped.captions.first)
    let second = try #require(remapped.captions.last)
    #expect(first.startSeconds == 1)
    #expect(first.endSeconds == 2)
    #expect(first.words?.map(\.word) == ["one", "two"])
    #expect(first.words?.map(\.endSeconds) == [1.5, 2])
    #expect(second.startSeconds == 2)
    #expect(second.endSeconds == 3)
    #expect(second.words?.map(\.word) == ["three"])
    #expect(second.words?.map(\.startSeconds) == [2.5])
    #expect(second.words?.map(\.endSeconds) == [3])
    #expect(second.text == "one two three")
  }

  @Test func spotlightRegionSpanningTwoSegmentsIsSplitWithFreshIds() throws {
    var config = config(trim: range(0, 10))
    let original = SpotlightRegionData(startSeconds: 1, endSeconds: 6, customRadius: 90, fadeDuration: 0.2)
    config.spotlightRegions = [original]

    let remapped = remapWithCuts(config)

    #expect(remapped.spotlight.count == 2)
    let first = try #require(remapped.spotlight.first)
    let second = try #require(remapped.spotlight.last)
    #expect(first.startSeconds == 1)
    #expect(first.endSeconds == 2)
    #expect(second.startSeconds == 2)
    #expect(second.endSeconds == 3)
    #expect(first.id != original.id)
    #expect(second.id != original.id)
    #expect(first.id != second.id)
    #expect(second.customRadius == 90)
    #expect(second.fadeDuration == 0.2)
  }

  @Test func textOverlayIsClippedAndShiftedByTrimStart() throws {
    let trim = range(5, 10)
    var config = config(trim: trim)
    let original = TextOverlayData(startSeconds: 2, endSeconds: 8, text: "Kept")
    config.textOverlays = [original, TextOverlayData(startSeconds: 0, endSeconds: 4, text: "Dropped")]

    let remapped = remap(config, trim: trim)

    #expect(remapped.textOverlays.count == 1)
    let result = try #require(remapped.textOverlays.first)
    #expect(result.id == original.id)
    #expect(result.startSeconds == 0)
    #expect(result.endSeconds == 3)
    #expect(result.text == "Kept")
  }

  @Test func textOverlaySpanningTwoSegmentsIsSplitWithFreshIds() throws {
    var config = config(trim: range(0, 10))
    var original = TextOverlayData(startSeconds: 1, endSeconds: 6, text: "Split")
    original.position = .topLeft
    config.textOverlays = [original, TextOverlayData(startSeconds: 3, endSeconds: 4, text: "Gone")]

    let remapped = remapWithCuts(config)

    #expect(remapped.textOverlays.count == 2)
    let first = try #require(remapped.textOverlays.first)
    let second = try #require(remapped.textOverlays.last)
    #expect(first.startSeconds == 1)
    #expect(first.endSeconds == 2)
    #expect(second.startSeconds == 2)
    #expect(second.endSeconds == 3)
    #expect(first.id != original.id)
    #expect(second.id != original.id)
    #expect(first.id != second.id)
    #expect(second.text == "Split")
    #expect(second.position == .topLeft)
  }

  @Test func imageOverlayIsClippedAndShiftedByTrimStart() throws {
    let trim = range(5, 10)
    var config = config(trim: trim)
    let original = ImageOverlayData(startSeconds: 2, endSeconds: 8, filename: "kept.png")
    config.imageOverlays = [original, ImageOverlayData(startSeconds: 0, endSeconds: 4, filename: "dropped.png")]

    let remapped = remap(config, trim: trim)

    #expect(remapped.imageOverlays.count == 1)
    let result = try #require(remapped.imageOverlays.first)
    #expect(result.id == original.id)
    #expect(result.startSeconds == 0)
    #expect(result.endSeconds == 3)
    #expect(result.filename == "kept.png")
  }

  @Test func imageOverlaySpanningTwoSegmentsIsSplitWithFreshIds() throws {
    var config = config(trim: range(0, 10))
    var original = ImageOverlayData(startSeconds: 1, endSeconds: 6, filename: "split.png")
    original.position = .topLeft
    config.imageOverlays = [original, ImageOverlayData(startSeconds: 3, endSeconds: 4, filename: "gone.png")]

    let remapped = remapWithCuts(config)

    #expect(remapped.imageOverlays.count == 2)
    let first = try #require(remapped.imageOverlays.first)
    let second = try #require(remapped.imageOverlays.last)
    #expect(first.startSeconds == 1)
    #expect(first.endSeconds == 2)
    #expect(second.startSeconds == 2)
    #expect(second.endSeconds == 3)
    #expect(first.id != original.id)
    #expect(second.id != original.id)
    #expect(first.id != second.id)
    #expect(second.filename == "split.png")
    #expect(second.position == .topLeft)
  }

  @Test func blurRegionIsClippedAndShiftedByTrimStart() throws {
    let trim = range(5, 10)
    var config = config(trim: trim)
    let original = BlurRegionData(startSeconds: 2, endSeconds: 8, x: 0.1, y: 0.2, width: 0.3, height: 0.4)
    config.blurRegions = [original, BlurRegionData(startSeconds: 0, endSeconds: 4)]

    let remapped = remap(config, trim: trim)

    #expect(remapped.blurRegions.count == 1)
    let result = try #require(remapped.blurRegions.first)
    #expect(result.id == original.id)
    #expect(result.startSeconds == 0)
    #expect(result.endSeconds == 3)
    #expect(result.rect == original.rect)
  }

  @Test func blurRegionSpanningTwoSegmentsIsSplitWithFreshIds() throws {
    var config = config(trim: range(0, 10))
    let original = BlurRegionData(startSeconds: 1, endSeconds: 6, radius: 30)
    config.blurRegions = [original, BlurRegionData(startSeconds: 3, endSeconds: 4)]

    let remapped = remapWithCuts(config)

    #expect(remapped.blurRegions.count == 2)
    let first = try #require(remapped.blurRegions.first)
    let second = try #require(remapped.blurRegions.last)
    #expect(first.startSeconds == 1)
    #expect(first.endSeconds == 2)
    #expect(second.startSeconds == 2)
    #expect(second.endSeconds == 3)
    #expect(first.id != original.id)
    #expect(second.id != original.id)
    #expect(first.id != second.id)
    #expect(second.radius == 30)
  }
}
