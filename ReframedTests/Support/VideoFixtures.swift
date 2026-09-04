import AVFoundation
import CoreVideo
import Foundation

enum VideoFixtureError: Error {
  case writerFailed(String)
  case readerFailed(String)
  case noVideoTrack
  case pixelBufferAllocationFailed
}

enum VideoFixtures {
  struct RGB: Sendable, Equatable {
    let r: UInt8
    let g: UInt8
    let b: UInt8
  }

  struct FramePixel: Sendable {
    let seconds: Double
    let color: RGB
  }

  enum Container: Sendable {
    case mov
    case mp4

    var fileExtension: String {
      switch self {
      case .mov: "mov"
      case .mp4: "mp4"
      }
    }

    var fileType: AVFileType {
      switch self {
      case .mov: .mov
      case .mp4: .mp4
      }
    }
  }

  static let screenSize = CGSize(width: 320, height: 180)
  static let webcamSize = CGSize(width: 160, height: 120)
  static let fps = 30
  static let duration = 2.0
  static let webcamColor = RGB(r: 40, g: 90, b: 220)

  private static let rampOffset = 8
  private static let rampStep = 4

  static func screenColor(frame index: Int) -> RGB {
    let value = UInt8(clamping: rampOffset + index * rampStep)
    return RGB(r: value, g: value, b: value)
  }

  static func frameIndex(for color: RGB) -> Int {
    (Int(color.r) - rampOffset + rampStep / 2) / rampStep
  }

  @discardableResult
  static func screenMovie(
    duration: Double = duration,
    container: Container = .mov,
    in directory: URL,
    name: String = "screen"
  ) async throws -> URL {
    try await movie(
      size: screenSize,
      fps: fps,
      duration: duration,
      container: container,
      in: directory,
      name: name,
      color: { screenColor(frame: $0) }
    )
  }

  @discardableResult
  static func webcamMovie(
    duration: Double = duration,
    container: Container = .mp4,
    in directory: URL,
    name: String = "webcam"
  ) async throws -> URL {
    try await movie(
      size: webcamSize,
      fps: fps,
      duration: duration,
      container: container,
      in: directory,
      name: name,
      color: { _ in webcamColor }
    )
  }

  static func movie(
    size: CGSize,
    fps: Int,
    duration: Double,
    container: Container,
    in directory: URL,
    name: String,
    color: @escaping @Sendable (Int) -> RGB
  ) async throws -> URL {
    let url = directory.appendingPathComponent("\(name).\(container.fileExtension)")
    try? FileManager.default.removeItem(at: url)
    let writer = try MovieWriter(
      url: url,
      fileType: container.fileType,
      width: Int(size.width),
      height: Int(size.height),
      fps: fps,
      frameCount: Int((duration * Double(fps)).rounded()),
      color: color
    )
    try await writer.write()
    return url
  }

  static func centerPixels(of url: URL) async throws -> [FramePixel] {
    let asset = AVURLAsset(url: url)
    guard let track = try await asset.loadTracks(withMediaType: .video).first else {
      throw VideoFixtureError.noVideoTrack
    }
    let reader = try AVAssetReader(asset: asset)
    let output = AVAssetReaderTrackOutput(
      track: track,
      outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    )
    output.alwaysCopiesSampleData = false
    reader.add(output)
    guard reader.startReading() else {
      throw VideoFixtureError.readerFailed(reader.error?.localizedDescription ?? "startReading returned false")
    }
    var frames: [FramePixel] = []
    while let sample = output.copyNextSampleBuffer() {
      guard let buffer = CMSampleBufferGetImageBuffer(sample) else { continue }
      let seconds = CMSampleBufferGetPresentationTimeStamp(sample).seconds
      frames.append(FramePixel(seconds: seconds, color: centerColor(of: buffer)))
    }
    if reader.status == .failed {
      throw VideoFixtureError.readerFailed(reader.error?.localizedDescription ?? "reader failed")
    }
    return frames.sorted { $0.seconds < $1.seconds }
  }

  private static func centerColor(of buffer: CVPixelBuffer) -> RGB {
    CVPixelBufferLockBaseAddress(buffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
    let base = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
    let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
    let x = CVPixelBufferGetWidth(buffer) / 2
    let y = CVPixelBufferGetHeight(buffer) / 2
    let pixel = base + y * bytesPerRow + x * 4
    return RGB(r: pixel[2], g: pixel[1], b: pixel[0])
  }
}

private final class MovieWriter: @unchecked Sendable {
  private let writer: AVAssetWriter
  private let input: AVAssetWriterInput
  private let adaptor: AVAssetWriterInputPixelBufferAdaptor
  private let width: Int
  private let height: Int
  private let fps: Int
  private let frameCount: Int
  private let color: @Sendable (Int) -> VideoFixtures.RGB
  private let queue = DispatchQueue(label: "reframed-tests.video-fixture")
  private var nextFrame = 0
  private var finished = false

  init(
    url: URL,
    fileType: AVFileType,
    width: Int,
    height: Int,
    fps: Int,
    frameCount: Int,
    color: @escaping @Sendable (Int) -> VideoFixtures.RGB
  ) throws {
    self.width = width
    self.height = height
    self.fps = fps
    self.frameCount = frameCount
    self.color = color
    writer = try AVAssetWriter(outputURL: url, fileType: fileType)
    writer.shouldOptimizeForNetworkUse = false
    let settings: [String: Any] = [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: width,
      AVVideoHeightKey: height,
      AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: 20_000_000,
        AVVideoMaxKeyFrameIntervalKey: 1,
        AVVideoAllowFrameReorderingKey: false,
        AVVideoExpectedSourceFrameRateKey: fps,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
      ],
    ]
    input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
    input.expectsMediaDataInRealTime = false
    adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: input,
      sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height,
      ]
    )
    guard writer.canAdd(input) else {
      throw VideoFixtureError.writerFailed("cannot add video input")
    }
    writer.add(input)
  }

  func write() async throws {
    guard writer.startWriting() else {
      throw VideoFixtureError.writerFailed(writer.error?.localizedDescription ?? "startWriting returned false")
    }
    writer.startSession(atSourceTime: .zero)
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      input.requestMediaDataWhenReady(on: queue) { [self] in
        pump(continuation)
      }
    }
  }

  private func pump(_ continuation: CheckedContinuation<Void, Error>) {
    guard !finished else { return }
    while input.isReadyForMoreMediaData {
      if nextFrame == frameCount {
        finished = true
        input.markAsFinished()
        writer.endSession(atSourceTime: CMTime(value: CMTimeValue(frameCount), timescale: CMTimeScale(fps)))
        writer.finishWriting { [self] in
          if writer.status == .completed {
            continuation.resume()
          } else {
            continuation.resume(
              throwing: VideoFixtureError.writerFailed(writer.error?.localizedDescription ?? "status \(writer.status.rawValue)")
            )
          }
        }
        return
      }
      do {
        let buffer = try makePixelBuffer(color(nextFrame))
        let time = CMTime(value: CMTimeValue(nextFrame), timescale: CMTimeScale(fps))
        guard adaptor.append(buffer, withPresentationTime: time) else {
          throw VideoFixtureError.writerFailed(writer.error?.localizedDescription ?? "append returned false")
        }
        nextFrame += 1
      } catch {
        finished = true
        input.markAsFinished()
        writer.cancelWriting()
        continuation.resume(throwing: error)
        return
      }
    }
  }

  private func makePixelBuffer(_ color: VideoFixtures.RGB) throws -> CVPixelBuffer {
    var buffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, nil, &buffer)
    guard status == kCVReturnSuccess, let buffer else {
      throw VideoFixtureError.pixelBufferAllocationFailed
    }
    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
    let base = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
    let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
    for y in 0..<height {
      let row = base + y * bytesPerRow
      for x in 0..<width {
        row[x * 4] = color.b
        row[x * 4 + 1] = color.g
        row[x * 4 + 2] = color.r
        row[x * 4 + 3] = 255
      }
    }
    return buffer
  }
}
