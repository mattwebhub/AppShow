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
}
