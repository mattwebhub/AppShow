import AVFoundation
import Foundation

final class FixtureAnchor {}

enum TestPaths {
  static func makeTemporaryDirectory(_ name: String = #function) throws -> URL {
    let base = FileManager.default.temporaryDirectory
      .appendingPathComponent("reframed-tests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    return base
  }

  static func remove(_ url: URL) {
    try? FileManager.default.removeItem(at: url)
  }
}

enum AudioFixtures {
  enum Container {
    case wav
    case caf
    case m4a

    var fileExtension: String {
      switch self {
      case .wav: "wav"
      case .caf: "caf"
      case .m4a: "m4a"
      }
    }

    var settings: [String: Any] {
      switch self {
      case .wav, .caf:
        [
          AVFormatIDKey: kAudioFormatLinearPCM,
          AVLinearPCMBitDepthKey: 16,
          AVLinearPCMIsFloatKey: false,
          AVLinearPCMIsBigEndianKey: false,
        ]
      case .m4a:
        [
          AVFormatIDKey: kAudioFormatMPEG4AAC,
          AVEncoderBitRateKey: 64_000,
        ]
      }
    }
  }

  @discardableResult
  static func sineWave(
    frequency: Double = 440,
    duration: Double = 2,
    sampleRate: Double = 48_000,
    channels: UInt32 = 1,
    container: Container = .wav,
    in directory: URL,
    name: String = "tone"
  ) throws -> URL {
    try writeTone(
      frequency: frequency,
      duration: duration,
      sampleRate: sampleRate,
      channels: channels,
      container: container,
      in: directory,
      name: name,
      gap: nil
    )
  }

  @discardableResult
  static func toneWithGap(
    frequency: Double = 440,
    duration: Double = 3,
    gap: ClosedRange<Double>,
    sampleRate: Double = 48_000,
    channels: UInt32 = 1,
    container: Container = .wav,
    in directory: URL,
    name: String = "tone-gap"
  ) throws -> URL {
    try writeTone(
      frequency: frequency,
      duration: duration,
      sampleRate: sampleRate,
      channels: channels,
      container: container,
      in: directory,
      name: name,
      gap: gap
    )
  }

  private static func writeTone(
    frequency: Double,
    duration: Double,
    sampleRate: Double,
    channels: UInt32,
    container: Container,
    in directory: URL,
    name: String,
    gap: ClosedRange<Double>?
  ) throws -> URL {
    let url = directory.appendingPathComponent("\(name).\(container.fileExtension)")
    var settings = container.settings
    settings[AVSampleRateKey] = sampleRate
    settings[AVNumberOfChannelsKey] = channels
    let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels)!
    let file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
    let frameCount = AVAudioFrameCount(duration * sampleRate)
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
    buffer.frameLength = frameCount
    for channel in 0..<Int(channels) {
      let samples = buffer.floatChannelData![channel]
      for frame in 0..<Int(frameCount) {
        let time = Double(frame) / sampleRate
        if let gap, gap.contains(time) {
          samples[frame] = 0
        } else {
          samples[frame] = Float(sin(2 * .pi * frequency * time)) * 0.5
        }
      }
    }
    try file.write(from: buffer)
    return url
  }
}
