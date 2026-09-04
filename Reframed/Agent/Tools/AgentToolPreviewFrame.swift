import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct AgentToolPreviewFrameRequest: Sendable {
  let result: RecordingResult
  let configuration: ExportConfiguration
  let atSeconds: Double
  let width: Int
  let outputURL: URL
}

struct AgentToolPreviewFrameOutput: Sendable, Equatable {
  let url: URL
  let width: Int
  let height: Int
  let atSeconds: Double
}

enum AgentToolPreviewFrame {
  static let defaultWidth = 640
  static let minWidth = 16
  static let maxWidth = 1920

  private static let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue

  static func fileName(atSeconds: Double, width: Int) -> String {
    "frame-\(Int((atSeconds * 1000).rounded()))ms-\(width)w.png"
  }

  static func render(_ request: AgentToolPreviewFrameRequest) async throws -> AgentToolPreviewFrameOutput {
    let screenAsset = AVURLAsset(url: request.result.screenVideoURL)
    guard let track = try await screenAsset.loadTracks(withMediaType: .video).first else {
      throw CaptureError.recordingFailed("No video track in screen recording")
    }
    let naturalSize = try await track.load(.naturalSize)
    let assetDuration = try await screenAsset.load(.duration)
    let clamped = min(max(0, request.atSeconds), max(0, CMTimeGetSeconds(assetDuration)))
    let time = CMTime(seconds: clamped, preferredTimescale: 600)
    let canvasSize = VideoCompositor.computeCanvasSize(
      screenNaturalSize: naturalSize,
      canvasAspect: request.configuration.canvasAspect,
      padding: request.configuration.padding
    )
    let height = max(1, Int((Double(request.width) * Double(canvasSize.height) / max(Double(canvasSize.width), 1)).rounded()))
    let renderSize = CGSize(width: request.width, height: height)
    let instruction = try await VideoCompositor.buildCompositionInstruction(
      composition: AVMutableComposition(),
      result: request.result,
      config: request.configuration,
      effectiveTrim: CMTimeRange(start: .zero, duration: assetDuration),
      screenNaturalSize: naturalSize,
      hasVideoRegions: false,
      videoSegments: [],
      compositionDuration: assetDuration,
      canvasSize: canvasSize,
      renderSize: renderSize
    )
    let screenBuffer = try buffer(from: try await frame(of: screenAsset, at: time))
    var webcamBuffer: CVPixelBuffer?
    if let webcamURL = request.result.webcamVideoURL, let image = try? await frame(of: AVURLAsset(url: webcamURL), at: time) {
      webcamBuffer = try buffer(from: image)
    }
    let output = try makeBuffer(width: request.width, height: height)
    FrameRenderer.renderFrame(
      screenBuffer: screenBuffer,
      webcamBuffer: webcamBuffer,
      outputBuffer: output,
      compositionTime: time,
      instruction: instruction
    )
    try writePNG(output, to: request.outputURL)
    return AgentToolPreviewFrameOutput(url: request.outputURL, width: request.width, height: height, atSeconds: clamped)
  }

  private static func frame(of asset: AVURLAsset, at time: CMTime) async throws -> CGImage {
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 15)
    generator.requestedTimeToleranceAfter = .zero
    return try await generator.image(at: time).image
  }

  private static func makeBuffer(width: Int, height: Int) throws -> CVPixelBuffer {
    var buffer: CVPixelBuffer?
    let attributes: [CFString: Any] = [
      kCVPixelBufferCGImageCompatibilityKey: true,
      kCVPixelBufferCGBitmapContextCompatibilityKey: true,
    ]
    let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attributes as CFDictionary, &buffer)
    guard status == kCVReturnSuccess, let buffer else {
      throw CaptureError.recordingFailed("Could not allocate a \(width)x\(height) frame buffer")
    }
    return buffer
  }

  private static func context(for buffer: CVPixelBuffer) -> CGContext? {
    CGContext(
      data: CVPixelBufferGetBaseAddress(buffer),
      width: CVPixelBufferGetWidth(buffer),
      height: CVPixelBufferGetHeight(buffer),
      bitsPerComponent: 8,
      bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
      space: CGColorSpace(name: CGColorSpace.sRGB)!,
      bitmapInfo: bitmapInfo
    )
  }

  private static func buffer(from image: CGImage) throws -> CVPixelBuffer {
    let buffer = try makeBuffer(width: image.width, height: image.height)
    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
    guard let context = context(for: buffer) else {
      throw CaptureError.recordingFailed("Could not draw the source frame")
    }
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    return buffer
  }

  private static func writePNG(_ buffer: CVPixelBuffer, to url: URL) throws {
    CVPixelBufferLockBaseAddress(buffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
    guard let image = context(for: buffer)?.makeImage() else {
      throw CaptureError.recordingFailed("Could not read the rendered frame")
    }
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
      throw CaptureError.recordingFailed("Could not create \(url.lastPathComponent)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
      throw CaptureError.recordingFailed("Could not write \(url.lastPathComponent)")
    }
  }
}

@MainActor
struct AgentToolPreviewFrameHandler: AgentToolHandler {
  var definition: AgentToolDefinition { AgentToolCatalog.renderPreviewFrame }

  func call(arguments: JSONValue, context: AgentToolContext) async throws -> JSONValue {
    let state = context.editorState
    let duration = CMTimeGetSeconds(state.duration)
    let atSeconds = min(max(0, arguments["atSeconds"]?.doubleValue ?? 0), max(0, duration))
    let width = arguments["width"]?.intValue ?? AgentToolPreviewFrame.defaultWidth
    try FileManager.default.createDirectory(at: context.framesDirectory, withIntermediateDirectories: true)
    let request = AgentToolPreviewFrameRequest(
      result: state.agentPreviewResult,
      configuration: state.agentPreviewConfiguration(),
      atSeconds: atSeconds,
      width: width,
      outputURL: context.framesDirectory.appendingPathComponent(AgentToolPreviewFrame.fileName(atSeconds: atSeconds, width: width))
    )
    let output = try await AgentToolPreviewFrame.render(request)
    if !state.isPlaying {
      state.seek(to: CMTime(seconds: output.atSeconds, preferredTimescale: 600))
    }
    return [
      "path": .string(output.url.path),
      "width": JSONValue(output.width),
      "height": JSONValue(output.height),
      "atSeconds": AgentToolSummaries.seconds(output.atSeconds),
    ]
  }
}

extension EditorState {
  var agentPreviewResult: RecordingResult {
    RecordingResult(
      screenVideoURL: result.screenVideoURL,
      webcamVideoURL: webcamEnabled ? result.webcamVideoURL : nil,
      systemAudioURL: result.systemAudioURL,
      microphoneAudioURL: result.microphoneAudioURL,
      cursorMetadataURL: result.cursorMetadataURL,
      screenSize: result.screenSize,
      webcamSize: webcamEnabled ? result.webcamSize : nil,
      fps: result.fps,
      captureQuality: result.captureQuality,
      isHDR: false
    )
  }

  func agentPreviewConfiguration() -> ExportConfiguration {
    func timeRange(_ start: Double, _ end: Double) -> CMTimeRange {
      CMTimeRange(
        start: CMTime(seconds: start, preferredTimescale: 600),
        end: CMTime(seconds: end, preferredTimescale: 600)
      )
    }
    func transition(_ region: CameraRegionData) -> RegionTransitionInfo {
      RegionTransitionInfo(
        timeRange: timeRange(region.startSeconds, region.endSeconds),
        entryTransition: region.entryTransition ?? .none,
        entryDuration: region.entryTransitionDuration ?? 0.3,
        exitTransition: region.exitTransition ?? .none,
        exitDuration: region.exitTransitionDuration ?? 0.3
      )
    }
    let fullscreen = cameraRegions.filter { $0.type == .fullscreen }.map(transition)
    let hidden = cameraRegions.filter { $0.type == .hidden }.map(transition)
    let custom: [CameraCustomRegion] = cameraRegions.compactMap { region in
      guard region.type == .custom, let layout = region.customLayout else { return nil }
      return CameraCustomRegion(
        timeRange: timeRange(region.startSeconds, region.endSeconds),
        layout: layout,
        cameraAspect: region.customCameraAspect ?? cameraAspect,
        cornerRadius: region.customCornerRadius ?? cameraCornerRadius,
        shadow: region.customShadow ?? cameraShadow,
        borderWidth: region.customBorderWidth ?? cameraBorderWidth,
        borderColor: (region.customBorderColor ?? cameraBorderColor).cgColor,
        mirrored: region.customMirrored ?? cameraMirrored,
        entryTransition: region.entryTransition ?? .none,
        entryDuration: region.entryTransitionDuration ?? 0.3,
        exitTransition: region.exitTransition ?? .none,
        exitDuration: region.exitTransitionDuration ?? 0.3
      )
    }
    return ExportConfiguration(
      cameraLayout: cameraLayout,
      cameraAspect: cameraAspect,
      trimRange: CMTimeRange(start: .zero, end: duration),
      cameraFullscreenRegions: fullscreen.isEmpty ? nil : fullscreen,
      cameraHiddenRegions: hidden.isEmpty ? nil : hidden,
      cameraCustomRegions: custom.isEmpty ? nil : custom,
      backgroundStyle: backgroundStyle,
      backgroundImageURL: backgroundImageURL(),
      backgroundImageFillMode: backgroundImageFillMode,
      canvasAspect: canvasAspect,
      padding: padding,
      videoCornerRadius: videoCornerRadius,
      cameraCornerRadius: cameraCornerRadius,
      cameraBorderWidth: cameraBorderWidth,
      cameraBorderColor: cameraBorderColor,
      videoShadow: videoShadow,
      cameraShadow: cameraShadow,
      cameraMirrored: cameraMirrored,
      cameraFullscreenFillMode: cameraFullscreenFillMode,
      cameraFullscreenAspect: cameraFullscreenAspect,
      cursorSnapshot: showCursor ? activeCursorProvider?.makeSnapshot() : nil,
      cursorStyle: cursorStyle,
      cursorSize: cursorSize,
      cursorFillColor: cursorFillColor,
      cursorStrokeColor: cursorStrokeColor,
      showClickHighlights: showClickHighlights,
      clickHighlightColor: clickHighlightColor,
      clickHighlightSize: clickHighlightSize,
      useSystemCursor: useSystemCursor,
      cursorSway: cursorSway,
      cursorMotionBlur: cursorMotionBlur,
      clickBounce: clickBounce,
      zoomFollowCursor: zoomFollowCursor,
      zoomTimeline: zoomEnabled ? zoomTimeline : nil,
      cameraBackgroundStyle: cameraBackgroundStyle,
      cameraBackgroundImageURL: cameraBackgroundImageURL(),
      captionSegments: captionSegments,
      captionsEnabled: captionsEnabled,
      captionFontSize: captionFontSize,
      captionFontWeight: captionFontWeight,
      captionTextColor: captionTextColor,
      captionBackgroundColor: captionBackgroundColor,
      captionBackgroundOpacity: captionBackgroundOpacity,
      captionShowBackground: captionShowBackground,
      captionPosition: captionPosition,
      captionMaxWordsPerLine: captionMaxWordsPerLine,
      spotlightRegions: spotlightEnabled && showCursor ? spotlightRegions : [],
      spotlightRadius: spotlightRadius,
      spotlightDimOpacity: spotlightDimOpacity,
      spotlightEdgeSoftness: spotlightEdgeSoftness
    )
  }
}
