import Testing

@testable import Reframed

struct AudioWaveformDownsamplerTests {
  private let frames: [Int16] = [100, -800, 300, 50, 1600, -200, 10, 3200, 400, -50, 20, 6400]

  private func near(_ a: [Float], _ b: [Float]) -> Bool {
    a.count == b.count && zip(a, b).allSatisfy { abs($0 - $1) < 0.0001 }
  }

  @Test func streamingDownsamplerKeepsOnePeakPerBucketAcrossBuffers() {
    var streaming = AudioWaveformDownsampler(totalFrames: frames.count, count: 4)
    streaming.append(Array(frames[0..<5]))
    streaming.append(Array(frames[5..<9]))
    streaming.append(Array(frames[9..<12]))
    let result = streaming.finish()

    var oneShot = AudioWaveformDownsampler(totalFrames: frames.count, count: 4)
    oneShot.append(frames)

    #expect(result.count == 4)
    #expect(near(result, [0.125, 0.25, 0.5, 1.0]))
    #expect(near(result, oneShot.finish()))
  }

  @Test func floatSamplesAndInterleavedChannelsShareBuckets() {
    let stereo: [Float] = [0.1, -0.4, 0.2, 0.05, 0.8, 0.1, 0.3, -0.2]
    var downsampler = AudioWaveformDownsampler(totalFrames: 4, count: 2, channels: 2)
    downsampler.append(Array(stereo[0..<3]))
    downsampler.append(Array(stereo[3..<8]))
    #expect(near(downsampler.finish(), [0.5, 1.0]))
  }

  @Test func framesBeyondTheAnnouncedTotalLandInTheLastBucket() {
    var downsampler = AudioWaveformDownsampler(totalFrames: 4, count: 2)
    downsampler.append([Int16(400), 400, 400, 400, 800, 800])
    #expect(near(downsampler.finish(), [0.5, 1.0]))
  }

  @Test func silenceAndEmptyInputStayZero() {
    var silent = AudioWaveformDownsampler(totalFrames: 3, count: 3)
    silent.append([Int16(0), 0, 0])
    #expect(silent.finish() == [0, 0, 0])

    let empty = AudioWaveformDownsampler(totalFrames: 0, count: 3)
    #expect(empty.finish() == [0, 0, 0])
  }
}
