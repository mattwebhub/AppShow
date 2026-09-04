import AVFoundation
import CryptoKit
import Foundation
import UniformTypeIdentifiers

struct ImportedExternalAudio: Sendable, Equatable {
  let fileName: String
  let displayName: String
  let durationSeconds: Double
}

enum ExternalAudioImporter {
  nonisolated static let contentTypes: [UTType] = [
    .mp3, .mpeg4Audio, .wav, .aiff,
    UTType("public.aac-audio"),
    UTType("com.apple.coreaudio-format"),
    UTType("org.xiph.flac"),
  ].compactMap { $0 }

  nonisolated static func `import`(sourceURL: URL, into bundleURL: URL) async throws -> ImportedExternalAudio {
    let asset = AVURLAsset(url: sourceURL)
    let audioTracks = (try? await asset.loadTracks(withMediaType: .audio)) ?? []
    guard !audioTracks.isEmpty else {
      throw CaptureError.recordingFailed("\(sourceURL.lastPathComponent) has no audio track")
    }
    let duration = (try? await asset.load(.duration).seconds) ?? 0
    guard duration.isFinite, duration > 0 else {
      throw CaptureError.recordingFailed("\(sourceURL.lastPathComponent) has no playable duration")
    }
    let hash = try contentHash(of: sourceURL)
    let fileName = "audio-\(hash.prefix(8)).\(sourceURL.pathExtension.lowercased())"
    let destination = bundleURL.appendingPathComponent(fileName)
    if !FileManager.default.fileExists(atPath: destination.path) {
      try FileManager.default.copyItem(at: sourceURL, to: destination)
    }
    return ImportedExternalAudio(
      fileName: fileName,
      displayName: sourceURL.deletingPathExtension().lastPathComponent,
      durationSeconds: duration
    )
  }

  nonisolated static func contentHash(of url: URL) throws -> String {
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    var hasher = SHA256()
    while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
      hasher.update(data: chunk)
    }
    return hasher.finalize().map { String(format: "%02x", $0) }.joined()
  }
}
