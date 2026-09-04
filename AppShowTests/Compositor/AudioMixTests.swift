import AVFoundation
import Testing

@testable import AppShow

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
    track.segments.first { !$0.isEmpty }?.sourceURL
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

  private func externalTrack(
    _ url: URL,
    start: Double,
    end: Double,
    fileIn: Double = 0,
    volume: Float = 1,
    fadeIn: Double = 0,
    fadeOut: Double = 0
  ) -> ExternalAudioExportTrack {
    ExternalAudioExportTrack(
      url: url,
      timelineRange: CMTimeRange(start: seconds(start), end: seconds(end)),
      fileStart: seconds(fileIn),
      volume: volume,
      fadeIn: seconds(fadeIn),
      fadeOut: seconds(fadeOut)
    )
  }

  @Test func addExternalAudioTracksCreatesOneCompositionTrackPerTrack() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let bed = try AudioFixtures.sineWave(frequency: 440, in: dir, name: "bed")
    let sting = try AudioFixtures.sineWave(frequency: 880, in: dir, name: "sting")
    let composition = AVMutableComposition()
    let tracks = [
      externalTrack(bed, start: 0.5, end: 1.5, fileIn: 0.25),
      externalTrack(sting, start: 1, end: 2),
    ]

    let added = try await VideoCompositor.addExternalAudioTracks(to: composition, tracks: tracks, trim: trim, segments: nil)

    let compTracks = composition.tracks(withMediaType: .audio)
    #expect(compTracks.count == 2)
    #expect(added.count == 2)
    #expect(Set(added.map(\.trackID)).count == 2)
    #expect(added.map(\.trackID) == compTracks.map(\.trackID))
    let bedSegments = compTracks[0].segments.filter { !$0.isEmpty }.map(\.timeMapping)
    #expect(bedSegments.count == 1)
    #expect(abs(bedSegments[0].target.start.seconds - 0.5) < 0.001)
    #expect(abs(bedSegments[0].target.end.seconds - 1.5) < 0.001)
    #expect(abs(bedSegments[0].source.start.seconds - 0.25) < 0.001)
    #expect(abs(bedSegments[0].source.end.seconds - 1.25) < 0.001)
    #expect(sourceURL(of: compTracks[0]) == bed)
    #expect(sourceURL(of: compTracks[1]) == sting)
  }

  @Test func mixParametersUseTrackIDsAndRamps() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let bed = try AudioFixtures.sineWave(frequency: 440, in: dir, name: "bed")
    let system = try AudioFixtures.sineWave(frequency: 880, in: dir, name: "system")
    let composition = AVMutableComposition()
    let sources = [source(system, volume: 1)]
    try await VideoCompositor.addAudioTracks(to: composition, sources: sources, videoTrimRange: trim)
    let tracks = [externalTrack(bed, start: 0, end: 2, volume: 0.5, fadeIn: 1)]
    let added = try await VideoCompositor.addExternalAudioTracks(to: composition, tracks: tracks, trim: trim, segments: nil)

    let params = VideoCompositor.externalMixParameters(for: added)
    let mix = try #require(
      VideoCompositor.audioMix(base: VideoCompositor.buildAudioMix(for: composition, sources: sources), adding: params)
    )

    #expect(params.count == 1)
    #expect(mix.inputParameters.count == 1)
    #expect(mix.inputParameters[0].trackID == added[0].trackID)
    #expect(added[0].trackID == composition.tracks(withMediaType: .audio)[1].trackID)
    var start: Float = -1
    var end: Float = -1
    var range = CMTimeRange.invalid
    #expect(mix.inputParameters[0].getVolumeRamp(for: .zero, startVolume: &start, endVolume: &end, timeRange: &range))
    #expect(abs(start - 0) < 0.001)
    #expect(abs(end - 0.5) < 0.001)
    #expect(abs(range.start.seconds - 0) < 0.001)
    #expect(abs(range.end.seconds - 1) < 0.001)
  }

  @Test func audioMixKeepsRecordedParametersAndAppendsExternalOnes() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let bed = try AudioFixtures.sineWave(frequency: 440, in: dir, name: "bed")
    let system = try AudioFixtures.sineWave(frequency: 880, in: dir, name: "system")
    let composition = AVMutableComposition()
    let sources = [source(system, volume: 0.5)]
    try await VideoCompositor.addAudioTracks(to: composition, sources: sources, videoTrimRange: trim)
    let added = try await VideoCompositor.addExternalAudioTracks(
      to: composition,
      tracks: [externalTrack(bed, start: 0.5, end: 1.5, volume: 0.25)],
      trim: trim,
      segments: nil
    )

    let base = VideoCompositor.buildAudioMix(for: composition, sources: sources)
    let mix = try #require(VideoCompositor.audioMix(base: base, adding: VideoCompositor.externalMixParameters(for: added)))
    let tracks = composition.tracks(withMediaType: .audio)

    #expect(mix.inputParameters.map(\.trackID) == tracks.map(\.trackID))
    #expect(mix.inputParameters.map(volume(of:)) == [0.5, 0.25])
    #expect(VideoCompositor.audioMix(base: nil, adding: []) == nil)
    #expect(VideoCompositor.audioMix(base: base, adding: []) === base)
  }
}
