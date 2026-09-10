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
