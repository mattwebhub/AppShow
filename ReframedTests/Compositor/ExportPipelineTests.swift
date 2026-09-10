import AVFoundation
import Foundation
import Testing

@testable import Reframed

@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["REFRAMED_RUN_EXPORT_TESTS"] == "1"))
struct ExportPipelineTests {
  private func slices() -> [VideoRegionData] {
    [
      VideoRegionData(startSeconds: 0, endSeconds: 0.5),
      VideoRegionData(startSeconds: 1.5, endSeconds: 2),
    ]
  }

  @Test func twoSliceExportHasKeptDuration() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let result = try await ProjectFixtures.recordingResult(
      in: dir,
      webcam: false,
      systemAudio: true,
      microphone: false,
      cursor: false
    )
    let out = dir.appendingPathComponent("out", isDirectory: true)
    try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    let regions = EditorState.exportVideoRegions(from: slices(), trimStart: 0, trimEnd: 2)
    let duration = CMTime(seconds: 2, preferredTimescale: 600)
    var config = ExportConfiguration(
      cameraLayout: CameraLayout(),
      trimRange: EditorState.exportTrimRange(videoRegions: regions, trimStart: .zero, trimEnd: duration, duration: duration),
      videoRegions: regions,
      outputDirectory: out
    )
    config.systemAudioRegions = [CMTimeRange(start: .zero, duration: duration)]
    let url = try await VideoCompositor.export(result: result, config: config)
    #expect(url.path.hasPrefix(out.path))
    let asset = AVURLAsset(url: url)
    let exported = try await asset.load(.duration).seconds
    #expect(abs(exported - 1.0) <= 1.0 / 30 + 0.01)
    #expect(try await asset.loadTracks(withMediaType: .video).count == 1)
    #expect(try await asset.loadTracks(withMediaType: .audio).count == 1)
  }

  @Test func singleFullSliceExportKeepsFullDuration() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let result = try await ProjectFixtures.recordingResult(
      in: dir,
      webcam: false,
      systemAudio: false,
      microphone: false,
      cursor: false
    )
    let out = dir.appendingPathComponent("out", isDirectory: true)
    try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    let duration = CMTime(seconds: 2, preferredTimescale: 600)
    var config = ExportConfiguration(
      cameraLayout: CameraLayout(),
      trimRange: CMTimeRange(start: .zero, end: duration),
      outputDirectory: out
    )
    config.padding = 0.05
    let url = try await VideoCompositor.export(result: result, config: config)
    let exported = try await AVURLAsset(url: url).load(.duration).seconds
    #expect(abs(exported - 2.0) <= 1.0 / 30 + 0.01)
  }

  @Test func exportMixesMusicIntoTrimmedOutput() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let result = try await ProjectFixtures.recordingResult(
      in: dir,
      webcam: false,
      systemAudio: false,
      microphone: false,
      cursor: false
    )
    let music = try AudioFixtures.sineWave(frequency: 880, duration: 2, in: dir, name: "audio-0badf00d")
    let out = dir.appendingPathComponent("out", isDirectory: true)
    try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    let duration = CMTime(seconds: 2, preferredTimescale: 600)
    var config = ExportConfiguration(
      cameraLayout: CameraLayout(),
      trimRange: CMTimeRange(start: .zero, end: duration),
      outputDirectory: out
    )
    config.externalAudioTracks = [
      ExternalAudioExportTrack(
        url: music,
        timelineRange: CMTimeRange(
          start: CMTime(seconds: 0.5, preferredTimescale: 600),
          end: CMTime(seconds: 1.5, preferredTimescale: 600)
        ),
        fileStart: .zero,
        volume: 1,
        fadeIn: .zero,
        fadeOut: .zero
      )
    ]
    let url = try await VideoCompositor.export(result: result, config: config)
    #expect(url.path.hasPrefix(out.path))
    let asset = AVURLAsset(url: url)
    #expect(try await asset.loadTracks(withMediaType: .audio).count == 1)
    let exported = try await asset.load(.duration).seconds
    #expect(abs(exported - 2.0) <= 1.0 / 30 + 0.05)
    let loud = try await AudioFixtures.rmsDecibels(of: url, from: 0.6, to: 1.4)
    let silent = try await AudioFixtures.rmsDecibels(of: url, from: 0, to: 0.4)
    #expect(loud > -20)
    #expect(silent < -60)
  }

  @Test func exactDestinationIsUsedOnceAndNeverOverwritten() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let result = try await ProjectFixtures.recordingResult(
      in: dir,
      webcam: false,
      systemAudio: false,
      microphone: false,
      cursor: false
    )
    let destination = dir.appendingPathComponent("Presentation.mp4")
    let duration = CMTime(seconds: 2, preferredTimescale: 600)
    let config = ExportConfiguration(
      cameraLayout: CameraLayout(),
      trimRange: CMTimeRange(start: .zero, end: duration),
      outputURL: destination
    )

    let url = try await VideoCompositor.export(result: result, config: config)
    #expect(url == destination)
    #expect(FileManager.default.fileExists(atPath: destination.path))
    let originalSize = try Data(contentsOf: destination).count

    await #expect(throws: (any Error).self) {
      try await VideoCompositor.export(result: result, config: config)
    }
    #expect(try Data(contentsOf: destination).count == originalSize)
  }

  @Test func blurRegionExportsThroughTheCompositor() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let result = try await ProjectFixtures.recordingResult(
      in: directory,
      webcam: false,
      systemAudio: false,
      microphone: false,
      cursor: false
    )
    let output = directory.appendingPathComponent("out", isDirectory: true)
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    let duration = CMTime(seconds: 2, preferredTimescale: 600)
    var config = ExportConfiguration(
      cameraLayout: CameraLayout(),
      trimRange: CMTimeRange(start: .zero, end: duration),
      outputDirectory: output
    )
    config.blurRegions = [
      BlurRegionData(startSeconds: 0.25, endSeconds: 1.75, x: 0.2, y: 0.2, width: 0.6, height: 0.6)
    ]

    let url = try await VideoCompositor.export(result: result, config: config)
    let asset = AVURLAsset(url: url)

    #expect(abs(try await asset.load(.duration).seconds - 2.0) <= 1.0 / 30 + 0.01)
    #expect(try await asset.loadTracks(withMediaType: .video).count == 1)
  }
}
