import Foundation

enum ExternalAudioWaveformWindow {
  static func slice(samples: [Float], fileIn: Double, fileOut: Double, sourceDuration: Double) -> [Float] {
    let count = samples.count
    guard count > 1, sourceDuration > 0, fileOut > fileIn else { return [] }
    let scale = Double(count) / sourceDuration
    let start = min(max(0, Int((fileIn * scale).rounded(.down))), count - 2)
    let end = min(max(start + 2, Int((fileOut * scale).rounded(.up))), count)
    return Array(samples[start..<end])
  }
}
