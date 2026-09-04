import CoreMedia
import Testing

@testable import AppShow

struct SharedRecordingClockTests {
  private func time(_ seconds: Double, timescale: CMTimeScale = 600) -> CMTime {
    CMTime(seconds: seconds, preferredTimescale: timescale)
  }

  @Test func referenceIsNilUntilEveryStreamHasRegistered() {
    let clock = SharedRecordingClock(streamCount: 3)
    #expect(clock.referenceTimeSeconds == nil)
    clock.registerStream(firstPTS: time(1))
    #expect(clock.referenceTimeSeconds == nil)
    clock.registerStream(firstPTS: time(2))
    #expect(clock.referenceTimeSeconds == nil)
    clock.registerStream(firstPTS: time(3))
    #expect(clock.referenceTimeSeconds == 3)
  }

  @Test func referenceIsTheLatestFirstPTSAcrossStreams() {
    let clock = SharedRecordingClock(streamCount: 3)
    clock.registerStream(firstPTS: time(2.5))
    clock.registerStream(firstPTS: time(4))
    clock.registerStream(firstPTS: time(1))
    #expect(clock.referenceTimeSeconds == 4)
  }

  @Test func referenceComparesAcrossTimescales() {
    let clock = SharedRecordingClock(streamCount: 2)
    clock.registerStream(firstPTS: time(1, timescale: 600))
    clock.registerStream(firstPTS: time(1.5, timescale: 48_000))
    #expect(clock.referenceTimeSeconds == 1.5)
  }

  @Test func singleStreamSetsTheReferenceImmediately() {
    let clock = SharedRecordingClock(streamCount: 1)
    clock.registerStream(firstPTS: time(0.25))
    #expect(clock.referenceTimeSeconds == 0.25)
  }

  @Test func registrationsBeyondTheStreamCountAreIgnored() {
    let clock = SharedRecordingClock(streamCount: 1)
    clock.registerStream(firstPTS: time(1))
    clock.registerStream(firstPTS: time(9))
    #expect(clock.referenceTimeSeconds == 1)
  }

  @Test func zeroStreamsNeverEstablishAReference() {
    let clock = SharedRecordingClock(streamCount: 0)
    clock.registerStream(firstPTS: time(1))
    #expect(clock.referenceTimeSeconds == nil)
    #expect(clock.adjustPTS(time(5), pauseOffset: .zero) == nil)
  }

  @Test func adjustPTSIsNilBeforeTheReferenceExists() {
    let clock = SharedRecordingClock(streamCount: 2)
    clock.registerStream(firstPTS: time(1))
    #expect(clock.adjustPTS(time(5), pauseOffset: .zero) == nil)
  }

  @Test func adjustPTSSubtractsTheReference() {
    let clock = SharedRecordingClock(streamCount: 1)
    clock.registerStream(firstPTS: time(2))
    let adjusted = clock.adjustPTS(time(5), pauseOffset: .zero)
    #expect(adjusted == time(3))
  }

  @Test func adjustPTSReturnsZeroForTheReferenceItself() {
    let clock = SharedRecordingClock(streamCount: 1)
    clock.registerStream(firstPTS: time(2))
    let adjusted = clock.adjustPTS(time(2), pauseOffset: .zero)
    #expect(adjusted == .zero)
  }

  @Test func adjustPTSIsNilWhenTheResultWouldBeNegative() {
    let clock = SharedRecordingClock(streamCount: 1)
    clock.registerStream(firstPTS: time(2))
    #expect(clock.adjustPTS(time(1.5), pauseOffset: .zero) == nil)
    #expect(clock.adjustPTS(time(2.5), pauseOffset: time(1)) == nil)
  }

  @Test func pauseOffsetShiftsTheAdjustedPTSByExactlyThatAmount() {
    let clock = SharedRecordingClock(streamCount: 1)
    clock.registerStream(firstPTS: time(2))
    let unpaused = clock.adjustPTS(time(10), pauseOffset: .zero)
    let paused = clock.adjustPTS(time(10), pauseOffset: time(1.5))
    #expect(unpaused == time(8))
    #expect(paused == time(6.5))
    #expect(CMTimeSubtract(unpaused!, paused!) == time(1.5))
  }

  @Test func adjustedPTSKeepsTheTimescaleArithmeticExact() {
    let clock = SharedRecordingClock(streamCount: 1)
    clock.registerStream(firstPTS: CMTime(value: 48_000, timescale: 48_000))
    let adjusted = clock.adjustPTS(CMTime(value: 96_001, timescale: 48_000), pauseOffset: CMTime(value: 600, timescale: 600))
    #expect(adjusted == CMTime(value: 1, timescale: 48_000))
  }
}
