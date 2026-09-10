import AVFoundation
import Foundation
import Testing

@testable import AppShow

@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["APPSHOW_RUN_EXPORT_TESTS"] == "1"))
struct ExportPipelineTests {
  private func slices() -> [VideoRegionData] {
    [
      VideoRegionData(startSeconds: 0, endSeconds: 0.5),
      VideoRegionData(startSeconds: 1.5, endSeconds: 2),
    ]
  }

  @Test(arguments: [true, false])
  func narrationAndMusicKeepTheirNormalTiming(isMicrophone: Bool) async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let screen = try await VideoFixtures.screenMovie(in: dir)
    let audio = try AudioFixtures.toneWithGap(duration: 2, gap: 0...0.75, in: dir)
    let result = RecordingResult(
      screenVideoURL: screen,
      webcamVideoURL: nil,
      systemAudioURL: nil,
      microphoneAudioURL: isMicrophone ? audio : nil,
      cursorMetadataURL: nil,
      screenSize: VideoFixtures.screenSize,
      webcamSize: nil,
      fps: 30,
      captureQuality: .standard,
      isHDR: false
    )
    var config = ExportConfiguration(
      cameraLayout: CameraLayout(),
      trimRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 2, preferredTimescale: 600)),
      outputURL: dir.appendingPathComponent("normal-audio.mp4")
    )
    config.speedRegions = [SpeedRegionData(startSeconds: 0, endSeconds: 2, rate: 2)]
    if !isMicrophone {
      config.externalAudioTracks = [
        ExternalAudioExportTrack(
          url: audio,
          timelineRange: config.trimRange,
          fileStart: .zero,
          volume: 1,
          fadeIn: .zero,
          fadeOut: .zero
        )
      ]
    }
    let url = try await VideoCompositor.export(result: result, config: config)
    #expect(try await AudioFixtures.rmsDecibels(of: url, from: 0.2, to: 0.5) < -60)
    #expect(try await AudioFixtures.rmsDecibels(of: url, from: 0.85, to: 0.95) > -25)
  }

  @Test(arguments: [ExportMode.normal, ExportMode.parallel])
  func webcamFramesRemainAtNormalSpeedWhileScreenAccelerates(mode: ExportMode) async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let screen = try await VideoFixtures.screenMovie(in: dir)
    let webcam = try await VideoFixtures.screenMovie(in: dir, name: "webcam")
    let result = RecordingResult(
      screenVideoURL: screen,
      webcamVideoURL: webcam,
      systemAudioURL: nil,
      microphoneAudioURL: nil,
      cursorMetadataURL: nil,
      screenSize: VideoFixtures.screenSize,
      webcamSize: VideoFixtures.screenSize,
      fps: 30,
      captureQuality: .standard,
      isHDR: false
    )
    var config = ExportConfiguration(
      cameraLayout: CameraLayout(relativeX: 0, relativeY: 0, relativeWidth: 1),
      trimRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 2, preferredTimescale: 600)),
      outputURL: dir.appendingPathComponent("webcam-speed.mp4")
    )
    config.exportSettings.mode = mode
    config.speedRegions = [SpeedRegionData(startSeconds: 0, endSeconds: 2, rate: 2)]
    config.cameraCornerRadius = 0
    let url = try await VideoCompositor.export(result: result, config: config)
    let frames = try await VideoFixtures.centerPixels(of: url)
    let middle = try #require(frames.first { $0.seconds >= 0.5 })
    #expect(abs(VideoFixtures.frameIndex(for: middle.color) - 15) <= 2)
    #expect(abs(try await AVURLAsset(url: url).load(.duration).seconds - 1) < 0.002)
  }

  @Test(arguments: [1.5, 2.0, 4.0, 8.0, 16.0, 32.0])
  func speedPresetsShortenVideoAndRetainAudio(rate: Double) async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let result = try await ProjectFixtures.recordingResult(in: dir, webcam: true, systemAudio: true, microphone: true, cursor: false)
    var config = ExportConfiguration(
      cameraLayout: CameraLayout(),
      trimRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 2, preferredTimescale: 600)),
      outputURL: dir.appendingPathComponent("speed.mp4")
    )
    config.speedRegions = [SpeedRegionData(startSeconds: 0, endSeconds: 2, rate: rate)]
    let url = try await VideoCompositor.export(result: result, config: config)
    let asset = AVURLAsset(url: url)
    #expect(abs(try await asset.load(.duration).seconds - 2 / rate) < 0.002)
    #expect(try await asset.loadTracks(withMediaType: .video).count == 1)
    #expect(try await asset.loadTracks(withMediaType: .audio).count == 1)
    #expect(try await AudioFixtures.rmsDecibels(of: url, from: 0, to: 2 / rate) > -50)
  }

  @Test(arguments: [false, true], [ExportMode.normal, ExportMode.parallel])
  func speedExportsWithCutsAndEffects(isHDR: Bool, mode: ExportMode) async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let result = try await ProjectFixtures.recordingResult(
      in: dir,
      webcam: true,
      systemAudio: true,
      microphone: false,
      cursor: false,
      isHDR: isHDR
    )
    var config = ExportConfiguration(
      cameraLayout: CameraLayout(),
      trimRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 2, preferredTimescale: 600)),
      outputURL: dir.appendingPathComponent("cut-speed.mp4")
    )
    config.exportSettings.mode = mode
    config.speedRegions = [SpeedRegionData(startSeconds: 0.5, endSeconds: 1.5, rate: 4)]
    config.videoRegions = EditorState.exportVideoRegions(
      from: [VideoRegionData(startSeconds: 0, endSeconds: 0.75), VideoRegionData(startSeconds: 1.25, endSeconds: 2)],
      trimStart: 0,
      trimEnd: 2
    )
    config.blurRegions = [BlurRegionData(startSeconds: 0.5, endSeconds: 1.5, x: 0.2, y: 0.2, width: 0.3, height: 0.3)]
    let url = try await VideoCompositor.export(result: result, config: config)
    let actualDuration = try await AVURLAsset(url: url).load(.duration).seconds
    #expect(abs(actualDuration - 1.125) < 0.002, "Duration: \(actualDuration)")
    #expect(try await AudioFixtures.rmsDecibels(of: url, from: 0.1, to: 1.0) > -50)
  }

  @Test(arguments: [false, true])
  func areaZoomAndTimedBlurExportTogether(isHDR: Bool) async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let result = try await ProjectFixtures.recordingResult(
      in: dir,
      webcam: false,
      systemAudio: false,
      microphone: false,
      cursor: false,
      isHDR: isHDR
    )
    var config = ExportConfiguration(
      cameraLayout: CameraLayout(),
      trimRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 2, preferredTimescale: 600)),
      outputURL: dir.appendingPathComponent("area-effects.mp4")
    )
    config.zoomTimeline = ZoomTimeline(
      keyframes: try ZoomTimeline.areaKeyframes(
        rect: CGRect(x: 0.6, y: 0.1, width: 0.3, height: 0.2),
        start: 0.1,
        end: 1.9,
        transition: 0.2
      )
    )
    config.blurRegions = [BlurRegionData(startSeconds: 0.3, endSeconds: 1.5, x: 0.65, y: 0.1, width: 0.1, height: 0.1)]
    let url = try await VideoCompositor.export(result: result, config: config)
    let asset = AVURLAsset(url: url)
    #expect(abs(try await asset.load(.duration).seconds - 2) < 0.05)
    let frame = try await AVAssetImageGenerator(asset: asset).image(at: CMTime(seconds: 1, preferredTimescale: 600))
    #expect(frame.image.width > 0 && frame.image.height > 0)
  }

  @Test(arguments: [false, true], [CameraRegionType.fullscreen, .leftHalf, .rightThird])
  func webcamFocusExportsAcrossCuts(isHDR: Bool, presentation: CameraRegionType) async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let result = try await ProjectFixtures.recordingResult(
      in: dir,
      webcam: true,
      systemAudio: false,
      microphone: false,
      cursor: false,
      isHDR: isHDR
    )
    let duration = CMTime(seconds: 2, preferredTimescale: 600)
    var config = ExportConfiguration(
      cameraLayout: WebcamPresentation().layout(canvasSize: result.screenSize),
      trimRange: CMTimeRange(start: .zero, duration: duration),
      outputURL: dir.appendingPathComponent("webcam-focus.mp4")
    )
    config.cameraAspect = .ratio1x1
    config.cameraCornerRadius = 50
    config.cameraFullscreenFillMode = .fill
    config.cameraFullscreenRegions = [
      RegionTransitionInfo(
        timeRange: CMTimeRange(start: CMTime(seconds: 0.25, preferredTimescale: 600), end: CMTime(seconds: 1.75, preferredTimescale: 600)),
        entryTransition: .scale,
        entryDuration: 0.4,
        exitTransition: .scale,
        exitDuration: 0.4,
        cameraPresentation: presentation
      )
    ]
    config.videoRegions = EditorState.exportVideoRegions(
      from: [VideoRegionData(startSeconds: 0, endSeconds: 0.75), VideoRegionData(startSeconds: 1.25, endSeconds: 2)],
      trimStart: 0,
      trimEnd: 2
    )
    let url = try await VideoCompositor.export(result: result, config: config)
    let asset = AVURLAsset(url: url)
    #expect(abs(try await asset.load(.duration).seconds - 1.5) < 0.05)
    #expect(try await asset.loadTracks(withMediaType: .video).count == 1)
    let generator = AVAssetImageGenerator(asset: asset)
    let frame = try await generator.image(at: CMTime(seconds: 0.75, preferredTimescale: 600))
    #expect(frame.image.width > 0 && frame.image.height > 0)
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
