import Accelerate
import Foundation

struct AudioWaveformDownsampler {
  private let totalFrames: Int
  private let channels: Int
  private var peaks: [Float]
  private var sampleIndex = 0

  init(totalFrames: Int, count: Int, channels: Int = 1) {
    self.totalFrames = max(0, totalFrames)
    self.channels = max(1, channels)
    peaks = [Float](repeating: 0, count: max(0, count))
  }

  mutating func append(_ samples: [Int16]) {
    samples.withUnsafeBufferPointer { append($0) }
  }

  mutating func append(_ samples: UnsafeBufferPointer<Int16>) {
    guard let base = samples.baseAddress, !samples.isEmpty else { return }
    var floats = [Float](repeating: 0, count: samples.count)
    vDSP_vflt16(base, 1, &floats, 1, vDSP_Length(samples.count))
    var scale: Float = 1 / 32768
    vDSP_vsmul(floats, 1, &scale, &floats, 1, vDSP_Length(samples.count))
    floats.withUnsafeBufferPointer { append($0) }
  }

  mutating func append(_ samples: [Float]) {
    samples.withUnsafeBufferPointer { append($0) }
  }

  mutating func append(_ samples: UnsafeBufferPointer<Float>) {
    guard let base = samples.baseAddress, !samples.isEmpty else { return }
    guard !peaks.isEmpty else {
      sampleIndex += samples.count
      return
    }
    var offset = 0
    while offset < samples.count {
      let bucket = bucketIndex(forFrame: (sampleIndex + offset) / channels)
      let runEnd =
        bucket == peaks.count - 1
        ? samples.count
        : min(samples.count, bucketStartFrame(bucket + 1) * channels - sampleIndex)
      let length = max(1, runEnd - offset)
      var peak: Float = 0
      vDSP_maxmgv(base + offset, 1, &peak, vDSP_Length(length))
      if peak > peaks[bucket] {
        peaks[bucket] = peak
      }
      offset += length
    }
    sampleIndex += samples.count
  }

  func finish() -> [Float] {
    guard let peak = peaks.max(), peak > 0 else { return peaks }
    return peaks.map { $0 / peak }
  }

  private func bucketIndex(forFrame frame: Int) -> Int {
    guard totalFrames > 0 else { return min(peaks.count - 1, frame) }
    return min(peaks.count - 1, frame * peaks.count / totalFrames)
  }

  private func bucketStartFrame(_ bucket: Int) -> Int {
    (bucket * totalFrames + peaks.count - 1) / peaks.count
  }
}
