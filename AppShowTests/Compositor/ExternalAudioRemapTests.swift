import CoreMedia
import Foundation
import Testing

@testable import AppShow

struct ExternalAudioRemapTests {
  private func seconds(_ value: Double) -> CMTime {
    CMTime(seconds: value, preferredTimescale: 600)
  }

  private func range(_ start: Double, _ end: Double) -> CMTimeRange {
    CMTimeRange(start: seconds(start), end: seconds(end))
  }

  private func track(
    _ start: Double,
    _ end: Double,
    fileIn: Double = 0,
    volume: Float = 1,
    fadeIn: Double = 0,
    fadeOut: Double = 0
  ) -> ExternalAudioExportTrack {
    ExternalAudioExportTrack(
      url: URL(fileURLWithPath: "/dev/null/audio-0badf00d.wav"),
      timelineRange: range(start, end),
      fileStart: seconds(fileIn),
      volume: volume,
      fadeIn: seconds(fadeIn),
      fadeOut: seconds(fadeOut)
    )
  }

  private func segment(_ start: Double, _ end: Double, at compositionStart: Double) -> VideoCompositor.VideoSegmentInfo {
    VideoCompositor.VideoSegmentInfo(sourceRange: range(start, end), compositionStart: seconds(compositionStart))
  }

  private func near(_ a: Double, _ b: Double) -> Bool {
    abs(a - b) < 0.001
  }

  private func near(_ a: Float, _ b: Float) -> Bool {
    abs(a - b) < 0.001
  }

  @Test func insertionWithoutCutsIsClippedToTrimAndOffsetIntoFile() throws {
    let insertions = VideoCompositor.insertions(for: track(3, 8, fileIn: 1), trim: range(5, 10), segments: nil)
    let insertion = try #require(insertions.first)
    #expect(insertions.count == 1)
    #expect(near(insertion.compositionRange.start.seconds, 0))
    #expect(near(insertion.compositionRange.end.seconds, 3))
    #expect(near(insertion.fileRange.start.seconds, 3))
    #expect(near(insertion.fileRange.end.seconds, 6))
  }

  @Test func insertionEntirelyOutsideTrimIsDropped() {
    #expect(VideoCompositor.insertions(for: track(12, 15), trim: range(5, 10), segments: nil).isEmpty)
    #expect(VideoCompositor.insertions(for: track(1, 5), trim: range(5, 10), segments: nil).isEmpty)
  }

  @Test func insertionsFollowVideoSegmentsAndKeepFileContinuity() throws {
    let segments = [segment(0, 2, at: 0), segment(5, 7, at: 2)]
    let insertions = VideoCompositor.insertions(for: track(1, 6), trim: range(0, 10), segments: segments)
    #expect(insertions.count == 2)
    #expect(insertions.map { $0.compositionRange.start.seconds } == [1, 2])
    #expect(insertions.map { $0.compositionRange.end.seconds } == [2, 3])
    #expect(insertions.map { $0.fileRange.start.seconds } == [0, 4])
    #expect(insertions.map { $0.fileRange.end.seconds } == [1, 5])
  }

  @Test func fadeRampsAreMappedIntoCompositionTimeAndSplitByCuts() throws {
    let segments = [segment(0, 2, at: 0), segment(5, 7, at: 2)]
    let t = track(1, 6, fadeIn: 2)
    let insertions = VideoCompositor.insertions(for: t, trim: range(0, 10), segments: segments)
    let ramps = VideoCompositor.volumeRamps(for: t, insertions: insertions)
    let ramp = try #require(ramps.first)
    #expect(ramps.count == 1)
    #expect(near(ramp.timeRange.start.seconds, 1))
    #expect(near(ramp.timeRange.end.seconds, 2))
    #expect(near(ramp.startVolume, 0))
    #expect(near(ramp.endVolume, 0.5))
  }

  @Test func fadeInAndFadeOutRampsWithoutCutsAreScaledByVolume() throws {
    let t = track(1, 6, volume: 0.5, fadeIn: 1, fadeOut: 2)
    let insertions = VideoCompositor.insertions(for: t, trim: range(0, 10), segments: nil)
    let ramps = VideoCompositor.volumeRamps(for: t, insertions: insertions)
    #expect(ramps.count == 2)
    #expect(near(ramps[0].timeRange.start.seconds, 1))
    #expect(near(ramps[0].timeRange.end.seconds, 2))
    #expect(near(ramps[0].startVolume, 0))
    #expect(near(ramps[0].endVolume, 0.5))
    #expect(near(ramps[1].timeRange.start.seconds, 4))
    #expect(near(ramps[1].timeRange.end.seconds, 6))
    #expect(near(ramps[1].startVolume, 0.5))
    #expect(near(ramps[1].endVolume, 0))
  }

  @Test func fadesAreClampedToHalfTheTrackLengthAtExport() {
    let t = track(1, 2, fadeIn: 5, fadeOut: 5)
    let insertions = VideoCompositor.insertions(for: t, trim: range(0, 10), segments: nil)
    let ramps = VideoCompositor.volumeRamps(for: t, insertions: insertions)
    #expect(ramps.count == 2)
    #expect(near(ramps[0].timeRange.end.seconds, 1.5))
    #expect(near(ramps[1].timeRange.start.seconds, 1.5))
  }

  @Test func trimInsideFadeInStartsRampAtInterpolatedVolume() throws {
    let t = track(0, 10, fadeIn: 2)
    let insertions = VideoCompositor.insertions(for: t, trim: range(1, 10), segments: nil)
    let ramp = try #require(VideoCompositor.volumeRamps(for: t, insertions: insertions).first)
    #expect(near(ramp.timeRange.start.seconds, 0))
    #expect(near(ramp.timeRange.end.seconds, 1))
    #expect(near(ramp.startVolume, 0.5))
    #expect(near(ramp.endVolume, 1))
  }

  @Test func trackBeforeTrimStartIsDroppedEvenWithFades() {
    let t = track(1, 4, fadeIn: 1, fadeOut: 1)
    let insertions = VideoCompositor.insertions(for: t, trim: range(5, 10), segments: nil)
    #expect(insertions.isEmpty)
    #expect(VideoCompositor.volumeRamps(for: t, insertions: insertions).isEmpty)
    let segments = [segment(5, 7, at: 0), segment(8, 10, at: 2)]
    #expect(VideoCompositor.insertions(for: t, trim: range(0, 10), segments: segments).isEmpty)
  }

  @Test func fadeOutSurvivesWhenLastSegmentCutsTheTrackEnd() throws {
    let t = track(0, 10, fadeOut: 2)
    let segments = [segment(0, 4, at: 0), segment(7, 9, at: 4)]
    let insertions = VideoCompositor.insertions(for: t, trim: range(0, 10), segments: segments)
    #expect(insertions.count == 2)
    let ramps = VideoCompositor.volumeRamps(for: t, insertions: insertions)
    let ramp = try #require(ramps.first)
    #expect(ramps.count == 1)
    #expect(near(ramp.timeRange.start.seconds, 5))
    #expect(near(ramp.timeRange.end.seconds, 6))
    #expect(near(ramp.startVolume, 1))
    #expect(near(ramp.endVolume, 0.5))
  }
}
