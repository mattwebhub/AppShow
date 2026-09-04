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

  nonisolated static func analyze(urls: [URL], config: SilenceDetectorConfig) async throws -> [ClosedRange<Double>] {
    var mixed: [Float] = []
    var windowDuration = config.windowSeconds
    for url in urls {
      let track = try rmsWindows(url: url, windowSeconds: config.windowSeconds)
      windowDuration = track.windowDuration
      mixed = louder(mixed, track.windows)
    }
    return SilenceDetector.silentSpans(rms: mixed, windowDuration: windowDuration, config: config)
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
    let scale = 1 / Float(channelCount)
    if buffer.format.isInterleaved {
      let interleaved = channels[0]
      for frame in 0..<frames {
        var sum: Float = 0
        for channel in 0..<channelCount {
          sum += interleaved[frame * channelCount + channel]
        }
        accumulator.append(sum * scale)
      }
    } else {
      for frame in 0..<frames {
        var sum: Float = 0
        for channel in 0..<channelCount {
          sum += channels[channel][frame]
        }
        accumulator.append(sum * scale)
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
