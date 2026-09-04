import AVFoundation
import Testing

@testable import Reframed

struct AudioMixTests {
  private let trim = CMTimeRange(start: .zero, duration: CMTime(seconds: 2, preferredTimescale: 600))

  private func source(_ url: URL, volume: Float) -> VideoCompositor.AudioSource {
    VideoCompositor.AudioSource(url: url, regions: [trim], volume: volume)
  }

  private func insertClickTrack(_ url: URL, into composition: AVMutableComposition) async throws {
    let asset = AVURLAsset(url: url)
    let track = try #require(try await asset.loadTracks(withMediaType: .audio).first)
    let compTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
    try compTrack?.insertTimeRange(trim, of: track, at: .zero)
  }

  private func volume(of params: AVAudioMixInputParameters) -> Float {
    var start: Float = -1
    var end: Float = -1
    var range = CMTimeRange.invalid
    _ = params.getVolumeRamp(for: .zero, startVolume: &start, endVolume: &end, timeRange: &range)
    return start
  }

  private func sourceURL(of track: AVCompositionTrack) -> URL? {
    track.segments.first?.sourceURL
  }

  private func seconds(_ value: Double) -> CMTime {
    CMTime(seconds: value, preferredTimescale: 600)
  }

  @Test func mixIsNilWhenAllVolumesAreUnity() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let system = try AudioFixtures.sineWave(frequency: 440, in: dir, name: "system")
    let mic = try AudioFixtures.sineWave(frequency: 880, in: dir, name: "mic")
    let composition = AVMutableComposition()
    let sources = [source(system, volume: 1), source(mic, volume: 1)]
    try await VideoCompositor.addAudioTracks(to: composition, sources: sources, videoTrimRange: trim)

    #expect(composition.tracks(withMediaType: .audio).count == 2)
    #expect(VideoCompositor.buildAudioMix(for: composition, sources: sources) == nil)
  }

  @Test func mixIsNilWhenCompositionHasNoAudioTracks() {
    let composition = AVMutableComposition()
    let sources = [source(URL(fileURLWithPath: "/dev/null/system.wav"), volume: 0.5)]

    #expect(VideoCompositor.buildAudioMix(for: composition, sources: sources) == nil)
  }

  @Test func inputParametersPairTracksAndSourcesByIndex() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let system = try AudioFixtures.sineWave(frequency: 440, in: dir, name: "system")
    let mic = try AudioFixtures.sineWave(frequency: 880, in: dir, name: "mic")
    let composition = AVMutableComposition()
    let sources = [source(system, volume: 0.5), source(mic, volume: 0.25)]
    try await VideoCompositor.addAudioTracks(to: composition, sources: sources, videoTrimRange: trim)

    let mix = try #require(VideoCompositor.buildAudioMix(for: composition, sources: sources))
    let tracks = composition.tracks(withMediaType: .audio)

    #expect(mix.inputParameters.count == 2)
    #expect(mix.inputParameters.map(\.trackID) == tracks.map(\.trackID))
    #expect(mix.inputParameters.map(volume(of:)) == [0.5, 0.25])
    #expect(sourceURL(of: tracks[0]) == system)
    #expect(sourceURL(of: tracks[1]) == mic)
  }

  @Test func clickTrackShiftsVolumePairingByIndex() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let system = try AudioFixtures.sineWave(frequency: 440, in: dir, name: "system")
    let mic = try AudioFixtures.sineWave(frequency: 880, in: dir, name: "mic")
    let click = try AudioFixtures.sineWave(frequency: 1000, in: dir, name: "click")
    let composition = AVMutableComposition()
    let sources = [source(system, volume: 0.5), source(mic, volume: 0.25)]
    try await insertClickTrack(click, into: composition)
    try await VideoCompositor.addAudioTracks(to: composition, sources: sources, videoTrimRange: trim)

    let mix = try #require(VideoCompositor.buildAudioMix(for: composition, sources: sources))
    let tracks = composition.tracks(withMediaType: .audio)

    #expect(tracks.count == 3)
    #expect(sourceURL(of: tracks[0]) == click)
    #expect(sourceURL(of: tracks[1]) == system)
    #expect(sourceURL(of: tracks[2]) == mic)
    #expect(mix.inputParameters.count == 2)
    #expect(mix.inputParameters.map(\.trackID) == [tracks[0].trackID, tracks[1].trackID])
    #expect(mix.inputParameters.map(volume(of:)) == [0.5, 0.25])
    #expect(!mix.inputParameters.contains { $0.trackID == tracks[2].trackID })
  }

  @Test func addAudioTracksInsertsOnlyRegionOverlapWithSegments() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let music = try AudioFixtures.sineWave(frequency: 440, in: dir, name: "music")
    let composition = AVMutableComposition()
    let region = CMTimeRange(start: seconds(0.5), end: seconds(2))
    let sources = [VideoCompositor.AudioSource(url: music, regions: [region], volume: 1)]
    let segments = [
      VideoCompositor.VideoSegmentInfo(sourceRange: CMTimeRange(start: .zero, end: seconds(1)), compositionStart: .zero),
      VideoCompositor.VideoSegmentInfo(sourceRange: CMTimeRange(start: seconds(1.5), end: seconds(2)), compositionStart: seconds(1)),
    ]
    try await VideoCompositor.addAudioTracks(to: composition, sources: sources, videoTrimRange: trim, videoSegments: segments)

    let track = try #require(composition.tracks(withMediaType: .audio).first)
    let inserted = track.segments.filter { !$0.isEmpty }.map(\.timeMapping)
    #expect(inserted.count == 2)
    #expect(inserted.map { $0.source.start.seconds } == [0.5, 1.5])
    #expect(inserted.map { $0.source.end.seconds } == [1.0, 2.0])
    #expect(inserted.map { $0.target.start.seconds } == [0.5, 1.0])
    #expect(inserted.map { $0.target.end.seconds } == [1.0, 1.5])
  }
}
