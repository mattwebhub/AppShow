import AVFoundation
import Foundation
import Testing

@testable import AppShow

struct SilenceAnalysisTests {
  private func near(_ range: ClosedRange<Double>, _ lower: Double, _ upper: Double, tolerance: Double) -> Bool {
    abs(range.lowerBound - lower) <= tolerance && abs(range.upperBound - upper) <= tolerance
  }

  @Test func analyzeFindsGapInGeneratedTone() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let url = try AudioFixtures.toneWithGap(duration: 3, gap: 1.0...2.2, in: dir)
    let spans = try await SilenceAnalysis.analyze(url: url, config: SilenceDetectorConfig())
    #expect(spans.count == 1)
    #expect(near(spans[0], 1.0, 2.2, tolerance: 0.05))
  }

  @Test func analyzeFindsGapInCompressedStereoFile() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let url = try AudioFixtures.toneWithGap(frequency: 880, duration: 3, gap: 1.0...2.2, channels: 2, container: .m4a, in: dir)
    let spans = try await SilenceAnalysis.analyze(url: url, config: SilenceDetectorConfig())
    #expect(spans.count == 1)
    #expect(near(spans[0], 1.0, 2.2, tolerance: 0.1))
  }

  @Test func analyzeOfUninterruptedToneHasNoSpans() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let url = try AudioFixtures.sineWave(duration: 2, in: dir)
    let spans = try await SilenceAnalysis.analyze(url: url, config: SilenceDetectorConfig())
    #expect(spans.isEmpty)
  }

  @Test func analyzeMixesTwoSourcesByLouderWindow() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let mic = try AudioFixtures.toneWithGap(duration: 3, gap: 0.7...1.5, in: dir, name: "mic")
    let system = try AudioFixtures.toneWithGap(frequency: 880, duration: 3, gap: 0.3...1.2, channels: 2, in: dir, name: "system")

    let strict = try await SilenceAnalysis.analyze(urls: [mic, system], config: SilenceDetectorConfig())
    #expect(strict.isEmpty)

    let loose = try await SilenceAnalysis.analyze(urls: [mic, system], config: SilenceDetectorConfig(minimumSilence: 0.4))
    #expect(loose.count == 1)
    #expect(near(loose[0], 0.7, 1.2, tolerance: 0.05))
  }

  @Test func oppositeStereoPhaseIsNotSilence() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let url = directory.appendingPathComponent("stereo.wav")
    let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2))
    let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 96000))
    buffer.frameLength = 96000
    let channels = try #require(buffer.floatChannelData)
    for frame in 0..<96000 {
      let sample = Float(sin(Double(frame) * 2 * .pi * 440 / 48000)) * 0.5
      channels[0][frame] = sample
      channels[1][frame] = -sample
    }
    do {
      let file = try AVAudioFile(forWriting: url, settings: format.settings)
      try file.write(from: buffer)
    }
    #expect(try AVAudioFile(forReading: url).length == 96000)
    let spans = try await SilenceAnalysis.analyze(url: url, config: SilenceDetectorConfig())
    #expect(spans.isEmpty)
  }

  @Test func silenceTimingUsesTheSourceClockAfterAudioDriftCorrection() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let url = try AudioFixtures.toneWithGap(duration: 4, gap: 1...3, in: directory)
    let spans = try await SilenceAnalysis.analyze(urls: [url], config: SilenceDetectorConfig(), driftRatios: [2])
    #expect(spans.count == 1)
    #expect(near(spans[0], 0.5, 1.5, tolerance: 0.05))
  }

  @Test func analyzeOfNoSourcesIsEmpty() async throws {
    let spans = try await SilenceAnalysis.analyze(urls: [], config: SilenceDetectorConfig())
    #expect(spans.isEmpty)
  }

  @Test func analyzeThrowsForMissingFile() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let missing = dir.appendingPathComponent("missing.wav")
    await #expect(throws: (any Error).self) {
      try await SilenceAnalysis.analyze(url: missing, config: SilenceDetectorConfig())
    }
  }
}
