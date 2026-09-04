import AVFoundation
import CoreMedia
import Foundation
import Logging

@MainActor
@Observable
final class ExternalAudioWaveformStore {
  static let sampleCount = 200

  private(set) var samples: [UUID: [Float]] = [:]
  private var generating: Set<UUID> = []
  private var tasks: [UUID: Task<[Float], Never>] = [:]
  nonisolated private static let logger = Logger(label: "eu.jankuri.reframed.external-audio-waveform-store")

  func isGenerating(_ id: UUID) -> Bool {
    generating.contains(id)
  }

  func generate(for id: UUID, url: URL) async {
    tasks[id]?.cancel()
    generating.insert(id)
    let task = Task.detached(priority: .userInitiated) {
      await Self.load(url: url, count: Self.sampleCount)
    }
    tasks[id] = task
    let result = await task.value
    guard tasks[id] == task else { return }
    tasks[id] = nil
    generating.remove(id)
    samples[id] = result.isEmpty ? nil : result
  }

  func remove(_ id: UUID) {
    tasks[id]?.cancel()
    tasks[id] = nil
    generating.remove(id)
    samples[id] = nil
  }

  func teardown() {
    for task in tasks.values {
      task.cancel()
    }
    tasks = [:]
    generating = []
  }

  nonisolated static func sidecarURL(for audioURL: URL) -> URL {
    audioURL.deletingPathExtension().appendingPathExtension("waveform.json")
  }

  nonisolated static func load(url: URL, count: Int) async -> [Float] {
    let sidecar = sidecarURL(for: url)
    if let cached = readSidecar(sidecar), cached.count == count {
      return cached
    }
    let generated = await extractSamples(from: url, count: count)
    guard !generated.isEmpty, !Task.isCancelled else { return generated }
    writeSidecar(generated, to: sidecar)
    return generated
  }

  nonisolated private static func readSidecar(_ url: URL) -> [Float]? {
    guard let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder().decode([Float].self, from: data)
  }

  nonisolated private static func writeSidecar(_ samples: [Float], to url: URL) {
    do {
      try JSONEncoder().encode(samples).write(to: url, options: .atomic)
    } catch {
      logger.warning("Failed to write waveform cache \(url.lastPathComponent): \(error)")
    }
  }

  nonisolated private static func extractSamples(from url: URL, count: Int) async -> [Float] {
    let asset = AVURLAsset(url: url)
    guard let track = try? await asset.loadTracks(withMediaType: .audio).first else { return [] }
    guard let reader = try? AVAssetReader(asset: asset) else { return [] }

    let formats = (try? await track.load(.formatDescriptions)) ?? []
    let description = formats.first.flatMap { CMAudioFormatDescriptionGetStreamBasicDescription($0)?.pointee }
    let sampleRate = description.map(\.mSampleRate).flatMap { $0 > 0 ? $0 : nil } ?? 48_000
    let channels = max(1, Int(description?.mChannelsPerFrame ?? 1))
    let trackRange = try? await track.load(.timeRange)
    let assetDuration = try? await asset.load(.duration)
    let durationSeconds = CMTimeGetSeconds(trackRange?.duration ?? assetDuration ?? .zero)
    let totalFrames = Int((durationSeconds * sampleRate).rounded())

    let settings: [String: Any] = [
      AVFormatIDKey: kAudioFormatLinearPCM,
      AVLinearPCMBitDepthKey: 16,
      AVLinearPCMIsFloatKey: false,
      AVLinearPCMIsBigEndianKey: false,
      AVLinearPCMIsNonInterleaved: false,
    ]
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
    output.alwaysCopiesSampleData = false
    guard reader.canAdd(output) else { return [] }
    reader.add(output)
    guard reader.startReading() else { return [] }

    var downsampler = AudioWaveformDownsampler(totalFrames: totalFrames, count: count, channels: channels)
    var scratch: [Int16] = []
    var sawSamples = false
    while let buffer = output.copyNextSampleBuffer() {
      if Task.isCancelled {
        reader.cancelReading()
        return []
      }
      guard let block = CMSampleBufferGetDataBuffer(buffer) else { continue }
      let length = CMBlockBufferGetDataLength(block)
      let sampleCount = length / MemoryLayout<Int16>.size
      guard sampleCount > 0 else { continue }
      if scratch.count < sampleCount {
        scratch = [Int16](repeating: 0, count: sampleCount)
      }
      scratch.withUnsafeMutableBufferPointer { pointer in
        guard let base = pointer.baseAddress else { return }
        CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: sampleCount * MemoryLayout<Int16>.size, destination: base)
        downsampler.append(UnsafeBufferPointer(start: base, count: sampleCount))
      }
      sawSamples = true
    }
    guard reader.status == .completed, sawSamples else {
      if let error = reader.error {
        logger.error("Waveform extraction failed for \(url.lastPathComponent): \(error)")
      }
      return []
    }
    return downsampler.finish()
  }
}
