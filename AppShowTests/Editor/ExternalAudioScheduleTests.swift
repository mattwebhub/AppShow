import Testing

@testable import AppShow

struct ExternalAudioScheduleTests {
  private func track(
    start: Double = 10,
    fileIn: Double = 0,
    fileOut: Double = 10,
    sourceDuration: Double = 30,
    fadeIn: Double = 0,
    fadeOut: Double = 0
  ) -> ExternalAudioTrackData {
    ExternalAudioTrackData(
      fileName: "audio-0badf00d.wav",
      displayName: "Bed",
      sourceDurationSeconds: sourceDuration,
      timelineStartSeconds: start,
      fileInSeconds: fileIn,
      fileOutSeconds: fileOut,
      fadeInSeconds: fadeIn,
      fadeOutSeconds: fadeOut
    )
  }

  private func near(_ a: Float, _ b: Float) -> Bool {
    abs(a - b) < 0.0001
  }

  @Test func fadeGainRampsLinearlyInsideTrackAndIsOneElsewhere() {
    let t = track(fadeIn: 1, fadeOut: 2)
    #expect(near(ExternalAudioSchedule.gain(at: 10, track: t), 0))
    #expect(near(ExternalAudioSchedule.gain(at: 10.5, track: t), 0.5))
    #expect(near(ExternalAudioSchedule.gain(at: 11, track: t), 1))
    #expect(near(ExternalAudioSchedule.gain(at: 15, track: t), 1))
    #expect(near(ExternalAudioSchedule.gain(at: 19, track: t), 0.5))
    #expect(near(ExternalAudioSchedule.gain(at: 20, track: t), 0))
    #expect(near(ExternalAudioSchedule.gain(at: 9.9, track: t), 0))
    #expect(near(ExternalAudioSchedule.gain(at: 20.1, track: t), 0))
  }

  @Test func gainIsOneInsideTrackWithoutFades() {
    let t = track()
    #expect(near(ExternalAudioSchedule.gain(at: 10, track: t), 1))
    #expect(near(ExternalAudioSchedule.gain(at: 19.99, track: t), 1))
    #expect(near(ExternalAudioSchedule.gain(at: 20, track: t), 0))
  }

  @Test func fadesAreClampedToHalfTheTrackLength() {
    let t = track(fileOut: 1, fadeIn: 5, fadeOut: 5)
    let fades = ExternalAudioSchedule.effectiveFades(for: t)
    #expect(fades.fadeIn == 0.5)
    #expect(fades.fadeOut == 0.5)
    #expect(near(ExternalAudioSchedule.gain(at: 10.5, track: t), 1))
    #expect(near(ExternalAudioSchedule.gain(at: 10.25, track: t), 0.5))
  }

  @Test func scheduleReturnsNilBeforeTrackStartAndAfterEnd() {
    let t = track()
    #expect(ExternalAudioSchedule.segment(track: t, at: 9.9, sampleRate: 48_000) == nil)
    #expect(ExternalAudioSchedule.segment(track: t, at: 20, sampleRate: 48_000) == nil)
    #expect(ExternalAudioSchedule.segment(track: t, at: 25, sampleRate: 48_000) == nil)
  }

  @Test func scheduleOffsetsIntoFileByElapsedTime() throws {
    let t = track(fileIn: 1, fileOut: 8)
    let segment = try #require(ExternalAudioSchedule.segment(track: t, at: 12, sampleRate: 48_000))
    #expect(segment.startFrame == 144_000)
    #expect(segment.frameCount == Int64((8.0 - 3.0) * 48_000))
    #expect(segment.delayFrames == 0)
  }

  @Test func scheduleForFutureTrackReturnsDelayFrames() throws {
    let t = track(fileIn: 1, fileOut: 8)
    let segment = try #require(ExternalAudioSchedule.upcomingSegment(track: t, at: 8, sampleRate: 48_000))
    #expect(segment.delayFrames == 96_000)
    #expect(segment.startFrame == 48_000)
    #expect(segment.frameCount == Int64(7.0 * 48_000))
    #expect(ExternalAudioSchedule.upcomingSegment(track: t, at: 17, sampleRate: 48_000) == nil)
    let inside = try #require(ExternalAudioSchedule.upcomingSegment(track: t, at: 12, sampleRate: 48_000))
    #expect(inside == ExternalAudioSchedule.segment(track: t, at: 12, sampleRate: 48_000))
  }

  @Test func previewGapSkipRestartsMusicAtNextRegion() {
    let regions: [(start: Double, end: Double)] = [(0, 2), (5, 7)]
    #expect(ExternalAudioSchedule.nextAudibleTime(after: 3, in: regions) == 5)
    #expect(ExternalAudioSchedule.nextAudibleTime(after: 2, in: regions) == 5)
    #expect(ExternalAudioSchedule.nextAudibleTime(after: 1, in: regions) == 1)
    #expect(ExternalAudioSchedule.nextAudibleTime(after: 8, in: regions) == nil)
    #expect(ExternalAudioSchedule.nextAudibleTime(after: 3, in: []) == 3)
  }

  @Test func resyncIsRequestedAboveFortyMillisecondsOfDrift() {
    #expect(!ExternalAudioSchedule.exceedsDriftTolerance(anchorTime: 10, playedSeconds: 2, timelineTime: 12.03))
    #expect(!ExternalAudioSchedule.exceedsDriftTolerance(anchorTime: 10, playedSeconds: 2, timelineTime: 11.97))
    #expect(ExternalAudioSchedule.exceedsDriftTolerance(anchorTime: 10, playedSeconds: 2, timelineTime: 12.05))
    #expect(ExternalAudioSchedule.exceedsDriftTolerance(anchorTime: 10, playedSeconds: 2, timelineTime: 11.9))
  }
}
