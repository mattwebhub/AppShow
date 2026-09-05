import AVFoundation
import Foundation

enum SilenceAnalysisError: Error {
  case unsupportedFormat(URL)
}

enum SilenceAnalysis {
  private static let chunkFrames: AVAudioFrameCount = 65_536

  nonisolated static func analyze(url: URL, config: SilenceDetectorConfig) async throws -> [ClosedRange<Double>] {
    try await analyze(urls: [url], config: config)
  }

  nonisolated static func analyze(
    urls: [URL],
    config: SilenceDetectorConfig,
    driftRatios: [Double] = []
  ) async throws -> [ClosedRange<Double>] {
    try Task.checkCancellation()
    var mixed: [Float] = []
    for (index, url) in urls.enumerated() {
      let candidate = index < driftRatios.count ? driftRatios[index] : 1
      let ratio = candidate.isFinite && candidate > 0 ? candidate : 1
      let track = try rmsWindows(url: url, windowSeconds: config.windowSeconds * ratio)
      let step = track.windowDuration / ratio
      let count = Int(ceil(Double(track.windows.count) * step / config.windowSeconds))
      var aligned = [Float](repeating: 0, count: count)
      for (window, rms) in track.windows.enumerated() {
        let first = max(0, Int(floor(Double(window) * step / config.windowSeconds + 1e-9)))
        let last = min(count, Int(ceil(Double(window + 1) * step / config.windowSeconds - 1e-9)))
        for bin in first..<max(first, last) { aligned[bin] = max(aligned[bin], rms) }
      }
      mixed = louder(mixed, aligned)
    }
    try Task.checkCancellation()
    return SilenceDetector.silentSpans(rms: mixed, windowDuration: config.windowSeconds, config: config)
  }

  nonisolated static func rmsWindows(url: URL, windowSeconds: Double) throws -> (windows: [Float], windowDuration: Double) {
    let file = try AVAudioFile(forReading: url)
    let format = file.processingFormat
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkFrames) else {
      throw SilenceAnalysisError.unsupportedFormat(url)
    }
    var accumulator = RmsWindowAccumulator(sampleRate: format.sampleRate, windowSeconds: windowSeconds)
    while file.framePosition < file.length {
      try Task.checkCancellation()
      try file.read(into: buffer, frameCount: chunkFrames)
      guard buffer.frameLength > 0 else { break }
      accumulate(buffer, into: &accumulator)
    }
    return (accumulator.finish(), accumulator.windowDuration)
  }

  nonisolated private static func accumulate(_ buffer: AVAudioPCMBuffer, into accumulator: inout RmsWindowAccumulator) {
    guard let channels = buffer.floatChannelData else { return }
    let channelCount = Int(buffer.format.channelCount)
    let frames = Int(buffer.frameLength)
    guard channelCount > 0, frames > 0 else { return }
    if buffer.format.isInterleaved {
      let interleaved = channels[0]
      for frame in 0..<frames {
        var peak: Float = 0
        for channel in 0..<channelCount {
          peak = max(peak, abs(interleaved[frame * channelCount + channel]))
        }
        accumulator.append(peak)
      }
    } else {
      for frame in 0..<frames {
        var peak: Float = 0
        for channel in 0..<channelCount {
          peak = max(peak, abs(channels[channel][frame]))
        }
        accumulator.append(peak)
      }
    }
  }

  nonisolated private static func louder(_ a: [Float], _ b: [Float]) -> [Float] {
    guard !a.isEmpty else { return b }
    guard !b.isEmpty else { return a }
    let count = max(a.count, b.count)
    return (0..<count).map { index in
      let left = index < a.count ? a[index] : 0
      let right = index < b.count ? b[index] : 0
      return max(left, right)
    }
  }
}
