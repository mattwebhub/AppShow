import AVFoundation
import Testing

@testable import Reframed

struct VideoFixtureTests {
  @Test func screenMovieHasRequestedDurationSizeAndFrameRate() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let url = try await VideoFixtures.screenMovie(in: dir)
    #expect(url.pathExtension == "mov")
    let asset = AVURLAsset(url: url)
    let duration = try await asset.load(.duration)
    #expect(abs(duration.seconds - 2.0) < 0.001)
    let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
    let size = try await track.load(.naturalSize)
    #expect(size == CGSize(width: 320, height: 180))
    let fps = try await track.load(.nominalFrameRate)
    #expect(abs(Double(fps) - 30) < 0.01)
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    let bytes = try #require(attributes[.size] as? Int)
    #expect(bytes <= 120 * 1024)
  }

  @Test func frameTenDecodesToItsRampColor() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let url = try await VideoFixtures.screenMovie(in: dir)
    let frames = try await VideoFixtures.centerPixels(of: url)
    #expect(frames.count == 60)
    let frame = try #require(frames.first { abs($0.seconds - 10.0 / 30.0) < 1e-6 })
    let expected = VideoFixtures.screenColor(frame: 10)
    #expect(abs(Int(frame.color.r) - Int(expected.r)) <= 3)
    #expect(abs(Int(frame.color.g) - Int(expected.g)) <= 3)
    #expect(abs(Int(frame.color.b) - Int(expected.b)) <= 3)
    #expect(VideoFixtures.frameIndex(for: frame.color) == 10)
  }

  @Test func everyFrameIsIdentifiableByItsColor() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let url = try await VideoFixtures.screenMovie(in: dir)
    let frames = try await VideoFixtures.centerPixels(of: url)
    let indices = frames.map { VideoFixtures.frameIndex(for: $0.color) }
    #expect(indices == Array(0..<60))
  }

  @Test func webcamMovieIsSmallerAndUniformlyColored() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let url = try await VideoFixtures.webcamMovie(in: dir)
    #expect(url.pathExtension == "mp4")
    let asset = AVURLAsset(url: url)
    let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
    let size = try await track.load(.naturalSize)
    #expect(size == CGSize(width: 160, height: 120))
    let frames = try await VideoFixtures.centerPixels(of: url)
    #expect(frames.count == 60)
    for frame in frames {
      #expect(abs(Int(frame.color.r) - Int(VideoFixtures.webcamColor.r)) <= 8)
      #expect(abs(Int(frame.color.g) - Int(VideoFixtures.webcamColor.g)) <= 8)
      #expect(abs(Int(frame.color.b) - Int(VideoFixtures.webcamColor.b)) <= 8)
    }
  }

  @Test func cursorMetadataFixtureHasExpectedShape() throws {
    let file = ProjectFixtures.cursorMetadata()
    #expect(file.version == 1)
    #expect(file.sampleRateHz == 120)
    #expect(file.samples.count == 240)
    #expect(file.clicks.count == 3)
    #expect(file.keystrokes.count == 12)
    #expect(file.samples.first?.t == 0)
    #expect(abs(file.samples.last!.t - (2 - 1.0 / 120)) < 1e-9)
    for sample in file.samples {
      #expect(sample.x >= 0 && sample.x <= 1)
      #expect(sample.y >= 0 && sample.y <= 1)
    }
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let url = try ProjectFixtures.writeCursorMetadata(file, in: dir)
    let decoded = try JSONDecoder().decode(CursorMetadataFile.self, from: Data(contentsOf: url))
    #expect(decoded.samples.count == file.samples.count)
    #expect(decoded.clicks.map(\.t) == file.clicks.map(\.t))
  }

  @Test func recordingResultFixturePointsAtGeneratedFiles() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let result = try await ProjectFixtures.recordingResult(in: dir)
    let fm = FileManager.default
    #expect(fm.fileExists(atPath: result.screenVideoURL.path))
    #expect(result.screenVideoURL.pathExtension == "mov")
    #expect(fm.fileExists(atPath: try #require(result.webcamVideoURL).path))
    #expect(fm.fileExists(atPath: try #require(result.systemAudioURL).path))
    #expect(fm.fileExists(atPath: try #require(result.microphoneAudioURL).path))
    #expect(fm.fileExists(atPath: try #require(result.cursorMetadataURL).path))
    #expect(result.screenSize == CGSize(width: 320, height: 180))
    #expect(result.webcamSize == CGSize(width: 160, height: 120))
    #expect(result.fps == 30)
    #expect(result.captureQuality == .standard)
    #expect(result.isHDR == false)
    let minimal = try await ProjectFixtures.recordingResult(
      in: dir,
      screenContainer: .mp4,
      webcam: false,
      systemAudio: false,
      microphone: false,
      cursor: false
    )
    #expect(minimal.screenVideoURL.pathExtension == "mp4")
    #expect(minimal.webcamVideoURL == nil)
    #expect(minimal.webcamSize == nil)
    #expect(minimal.cursorMetadataURL == nil)
  }
}
