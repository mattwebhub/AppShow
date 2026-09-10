import Testing

@testable import AppShow

struct ExternalAudioTrackMathTests {
  private func track(
    start: Double = 3,
    fileIn: Double = 1,
    fileOut: Double = 5,
    sourceDuration: Double = 6
  ) -> ExternalAudioTrackData {
    ExternalAudioTrackData(
      fileName: "audio-0badf00d.wav",
      displayName: "Loop",
      sourceDurationSeconds: sourceDuration,
      timelineStartSeconds: start,
      fileInSeconds: fileIn,
      fileOutSeconds: fileOut
    )
  }

  private func near(_ a: Double, _ b: Double) -> Bool {
    abs(a - b) < 0.0001
  }

  @Test func moveClampsWithinRecording() {
    let moved = ExternalAudioTrackMath.move(track(), to: 8, recordingDuration: 10)
    #expect(near(moved.timelineStartSeconds, 6))
    #expect(near(moved.timelineEndSeconds, 10))
    #expect(moved.fileInSeconds == 1)
    #expect(moved.fileOutSeconds == 5)

    let before = ExternalAudioTrackMath.move(track(), to: -1, recordingDuration: 10)
    #expect(before.timelineStartSeconds == 0)
    #expect(near(before.timelineEndSeconds, 4))

    let inside = ExternalAudioTrackMath.move(track(), to: 2.5, recordingDuration: 10)
    #expect(near(inside.timelineStartSeconds, 2.5))
  }

  @Test func trimStartShiftsFileInAndKeepsAudioAnchored() {
    let trimmed = ExternalAudioTrackMath.trimStart(track(), to: 4)
    #expect(near(trimmed.timelineStartSeconds, 4))
    #expect(near(trimmed.fileInSeconds, 2))
    #expect(trimmed.fileOutSeconds == 5)
    #expect(near(trimmed.timelineEndSeconds, 7))

    let tooFar = ExternalAudioTrackMath.trimStart(track(), to: 7.5)
    #expect(near(tooFar.timelineStartSeconds, 7 - ExternalAudioTrackMath.minimumLengthSeconds))
    #expect(near(tooFar.fileInSeconds, 5 - ExternalAudioTrackMath.minimumLengthSeconds))

    let beforeFile = ExternalAudioTrackMath.trimStart(track(), to: 1)
    #expect(near(beforeFile.timelineStartSeconds, 2))
    #expect(beforeFile.fileInSeconds == 0)

    let beforeTimeline = ExternalAudioTrackMath.trimStart(track(start: 0.5, fileIn: 2), to: -1)
    #expect(beforeTimeline.timelineStartSeconds == 0)
    #expect(near(beforeTimeline.fileInSeconds, 1.5))
  }

  @Test func trimEndClampsToSourceDurationAndRecording() {
    let toSource = ExternalAudioTrackMath.trimEnd(track(), to: 9, recordingDuration: 10)
    #expect(near(toSource.fileOutSeconds, 6))
    #expect(near(toSource.timelineEndSeconds, 8))

    let toRecording = ExternalAudioTrackMath.trimEnd(track(), to: 9, recordingDuration: 7)
    #expect(near(toRecording.fileOutSeconds, 5))
    #expect(near(toRecording.timelineEndSeconds, 7))

    let tooShort = ExternalAudioTrackMath.trimEnd(track(), to: 3.01, recordingDuration: 10)
    #expect(near(tooShort.fileOutSeconds, 1 + ExternalAudioTrackMath.minimumLengthSeconds))

    let shrunk = ExternalAudioTrackMath.trimEnd(track(), to: 6, recordingDuration: 10)
    #expect(near(shrunk.fileOutSeconds, 4))
    #expect(shrunk.timelineStartSeconds == 3)
    #expect(shrunk.fileInSeconds == 1)
  }

  @Test func clampedFitsTrackInsideRecordingAndSource() {
    let atPlayhead = ExternalAudioTrackMath.clamped(track(start: 1.5, fileIn: 0, fileOut: 2, sourceDuration: 2), to: 2)
    #expect(near(atPlayhead.timelineStartSeconds, 1.5))
    #expect(near(atPlayhead.fileOutSeconds, 0.5))

    let pastSource = ExternalAudioTrackMath.clamped(track(start: 0, fileIn: 0, fileOut: 9, sourceDuration: 6), to: 10)
    #expect(near(pastSource.fileOutSeconds, 6))

    let atEnd = ExternalAudioTrackMath.clamped(track(start: 2, fileIn: 0, fileOut: 2, sourceDuration: 2), to: 2)
    #expect(near(atEnd.timelineStartSeconds, 2 - ExternalAudioTrackMath.minimumLengthSeconds))
    #expect(near(atEnd.fileOutSeconds, ExternalAudioTrackMath.minimumLengthSeconds))

    let original = track()
    #expect(ExternalAudioTrackMath.clamped(original, to: 10) == original)
  }
}
