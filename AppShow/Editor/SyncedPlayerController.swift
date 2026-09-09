import AVFoundation
import Combine
import Foundation
import Logging

enum GapSkipDecision: Equatable, Sendable {
  case none
  case seek(Double)
  case pause
}

@MainActor
@Observable
final class SyncedPlayerController {
  private let logger = Logger(label: "com.mattwebhub.appshow.synced-player")
  let screenPlayer: AVPlayer
  let webcamPlayer: AVPlayer?
  private let systemAudio: RecordedAudioPreviewPlayer?
  private var microphone: RecordedAudioPreviewPlayer?
  private(set) var currentTime: CMTime = .zero
  private(set) var duration: CMTime = .zero
  private(set) var isPlaying = false
  private(set) var playbackRate: Double = 1
  private var timeObserver: Any?
  private var boundaryObserver: Any?
  private var lastNormalSpeedTime: Double?
  var trimStart: CMTime = .zero
  var trimEnd: CMTime = .zero
  var systemAudioRegions: [(start: CMTime, end: CMTime)] = []
  var micAudioRegions: [(start: CMTime, end: CMTime)] = []
  var videoRegions: [(start: Double, end: Double)] = []
  var speedRegions: [SpeedRegionData] = []
  var previewMode = false
  var skipsGaps = false
  let externalAudio = ExternalAudioPreviewEngine()
  private(set) var systemAudioDriftRatio: Double = 1
  private var webcamDriftRatio: Double = 1
  private(set) var micAudioDriftRatio: Double = 1

  init(result: RecordingResult) {
    screenPlayer = AVPlayer(playerItem: AVPlayerItem(asset: AVURLAsset(url: result.screenVideoURL)))
    screenPlayer.actionAtItemEnd = .pause
    if let url = result.webcamVideoURL {
      webcamPlayer = AVPlayer(playerItem: AVPlayerItem(asset: AVURLAsset(url: url)))
      webcamPlayer?.actionAtItemEnd = .pause
      webcamPlayer?.isMuted = true
    } else {
      webcamPlayer = nil
    }
    systemAudio = result.systemAudioURL.flatMap { try? RecordedAudioPreviewPlayer(url: $0) }
    microphone = result.microphoneAudioURL.flatMap { try? RecordedAudioPreviewPlayer(url: $0) }
    if result.systemAudioURL != nil || result.microphoneAudioURL != nil { screenPlayer.isMuted = true }
  }

  func swapMicAudioFile(url: URL) {
    guard let replacement = try? RecordedAudioPreviewPlayer(url: url) else { return }
    replacement.volume = microphone?.volume ?? 1
    microphone?.teardown()
    microphone = replacement
    micAudioDriftRatio = ratio(audioDuration: replacement.duration)
    replacement.driftRatio = micAudioDriftRatio
    updateAudioMuting(at: currentTime)
    if isPlaying { replacement.play(from: webcamSourceTime(for: currentTime.seconds), rate: 1) }
  }

  func loadDuration() async {
    guard let item = screenPlayer.currentItem else { return }
    duration = (try? await item.asset.load(.duration)) ?? .zero
    trimEnd = duration
  }

  func computeDriftRatios() async {
    if let audio = systemAudio {
      systemAudioDriftRatio = ratio(audioDuration: audio.duration)
      audio.driftRatio = systemAudioDriftRatio
    }
    if let audio = microphone {
      micAudioDriftRatio = ratio(audioDuration: audio.duration)
      audio.driftRatio = micAudioDriftRatio
    }
    if let item = webcamPlayer?.currentItem, let length = try? await item.asset.load(.duration) {
      webcamDriftRatio = ratio(audioDuration: length.seconds)
    }
  }

  private func ratio(audioDuration: Double) -> Double {
    guard duration.seconds > 0, audioDuration > 0, abs(audioDuration - duration.seconds) > 0.01 else { return 1 }
    return audioDuration / duration.seconds
  }

  func setupTimeObserver() {
    timeObserver = screenPlayer.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 60), queue: .main) { [weak self] time in
      MainActor.assumeIsolated {
        guard let self else { return }
        self.currentTime = time
        if self.trimEnd.isValid && time >= self.trimEnd { self.pause() }
        if (self.previewMode || self.skipsGaps) && self.isPlaying { self.applyGapSkip(at: time.seconds) }
        self.updatePlaybackRate(at: self.currentTime.seconds)
        self.updateAudioMuting(at: self.currentTime)
        self.syncNormalSpeedPlayback()
        self.externalAudio.tick(at: self.webcamSourceTime(for: self.currentTime.seconds))
      }
    }
  }

  nonisolated static func gapSkipDecision(at time: Double, slices: [(start: Double, end: Double)]) -> GapSkipDecision {
    guard !slices.isEmpty else { return .none }
    if slices.contains(where: { time >= $0.start && time < $0.end }) { return .none }
    if let next = slices.first(where: { $0.start > time }) { return .seek(next.start) }
    return .pause
  }

  func installBoundaryObserver() {
    if let boundaryObserver { screenPlayer.removeTimeObserver(boundaryObserver) }
    boundaryObserver = nil
    let boundaries = Set(videoRegions.dropLast().map(\.end) + speedRegions.flatMap { [$0.startSeconds, $0.endSeconds] }).sorted()
    guard !boundaries.isEmpty else { return }
    let times = boundaries.map { NSValue(time: CMTime(seconds: $0, preferredTimescale: 60000)) }
    boundaryObserver = screenPlayer.addBoundaryTimeObserver(forTimes: times, queue: .main) { [weak self] in
      MainActor.assumeIsolated {
        guard let self, self.isPlaying else { return }
        self.currentTime = self.screenPlayer.currentTime()
        let time = self.currentTime.seconds
        if self.previewMode || self.skipsGaps { self.applyGapSkip(at: time) }
        self.updatePlaybackRate(at: self.currentTime.seconds)
      }
    }
  }

  func updatePlaybackRate(at time: Double) {
    let rate = speedRegions.first { time >= $0.startSeconds && time < $0.endSeconds }?.rate ?? 1
    let changed = rate != playbackRate
    playbackRate = rate
    guard isPlaying else { return }
    if screenPlayer.rate != Float(rate) { screenPlayer.rate = Float(rate) }
    if webcamPlayer?.rate != Float(webcamDriftRatio) { webcamPlayer?.rate = Float(webcamDriftRatio) }
    if changed {
      systemAudio?.play(from: time, rate: rate)
    }
  }

  private func applyGapSkip(at time: Double) {
    switch Self.gapSkipDecision(at: time, slices: videoRegions) {
    case .none: break
    case .seek(let target): seek(to: CMTime(seconds: target, preferredTimescale: 60000))
    case .pause: pause()
    }
  }

  private func updateAudioMuting(at time: CMTime) {
    systemAudio?.muted = !systemAudioRegions.contains { time >= $0.start && time < $0.end }
    let micTime = CMTime(seconds: webcamSourceTime(for: time.seconds), preferredTimescale: 60000)
    microphone?.muted = !micAudioRegions.contains { micTime >= $0.start && micTime < $0.end }
  }

  func play() {
    guard !isPlaying, !trimEnd.isValid || currentTime < trimEnd else { return }
    isPlaying = true
    updatePlaybackRate(at: currentTime.seconds)
    updateAudioMuting(at: currentTime)
    systemAudio?.play(from: currentTime.seconds, rate: playbackRate)
    microphone?.play(from: webcamSourceTime(for: currentTime.seconds), rate: 1)
    externalAudio.setPlaybackRate(1, at: webcamSourceTime(for: currentTime.seconds))
    externalAudio.start(at: webcamSourceTime(for: currentTime.seconds))
  }

  func pause() {
    screenPlayer.pause()
    webcamPlayer?.pause()
    systemAudio?.stop()
    microphone?.stop()
    externalAudio.stop()
    isPlaying = false
    syncAuxPlayers()
  }

  func seek(to time: CMTime) {
    let tolerance = CMTime(value: 1, timescale: 60000)
    screenPlayer.seek(to: time, toleranceBefore: tolerance, toleranceAfter: tolerance)
    webcamPlayer?.seek(
      to: CMTime(seconds: webcamSourceTime(for: time.seconds) * webcamDriftRatio, preferredTimescale: 60000),
      toleranceBefore: tolerance,
      toleranceAfter: tolerance
    )
    systemAudio?.stop()
    microphone?.stop()
    externalAudio.stop()
    currentTime = time
    lastNormalSpeedTime = webcamSourceTime(for: time.seconds)
    updatePlaybackRate(at: time.seconds)
    updateAudioMuting(at: time)
    if isPlaying {
      systemAudio?.play(from: time.seconds, rate: playbackRate)
      microphone?.play(from: webcamSourceTime(for: time.seconds), rate: 1)
      externalAudio.setPlaybackRate(1, at: webcamSourceTime(for: time.seconds))
      externalAudio.start(at: webcamSourceTime(for: time.seconds))
    }
  }

  func setExternalAudioTracks(_ tracks: [ExternalAudioTrackData], urls: [UUID: URL]) {
    externalAudio.setTracks(tracks, urls: urls, currentTime: webcamSourceTime(for: currentTime.seconds))
    if !tracks.isEmpty { screenPlayer.isMuted = true }
  }

  func setSystemAudioVolume(_ volume: Float) { systemAudio?.volume = volume }
  func setMicAudioVolume(_ volume: Float) { microphone?.volume = volume }

  func teardown() {
    if let timeObserver { screenPlayer.removeTimeObserver(timeObserver) }
    if let boundaryObserver { screenPlayer.removeTimeObserver(boundaryObserver) }
    timeObserver = nil
    boundaryObserver = nil
    pause()
    systemAudio?.teardown()
    microphone?.teardown()
    externalAudio.teardown()
  }

  func webcamSourceTime(for sourceTime: Double) -> Double {
    guard !speedRegions.isEmpty else { return sourceTime }
    let kept = videoRegions.isEmpty ? [(start: 0.0, end: duration.seconds)] : videoRegions
    let slices = kept.compactMap { region -> VideoRegionData? in
      let start = max(region.start, trimStart.seconds)
      let end = min(region.end, trimEnd.seconds)
      return end > start ? VideoRegionData(startSeconds: start, endSeconds: end) : nil
    }
    return SpeedTimeline(duration: duration.seconds, regions: speedRegions, slices: slices).normalSpeedSource(forSource: sourceTime)
  }

  private func syncNormalSpeedPlayback() {
    let normal = webcamSourceTime(for: currentTime.seconds)
    defer { lastNormalSpeedTime = normal }
    guard isPlaying, !speedRegions.isEmpty else { return }
    let crossedCut =
      lastNormalSpeedTime.map { previous in
        zip(videoRegions, videoRegions.dropFirst()).contains { before, after in
          before.end < after.start && previous < before.end && normal >= after.start
        }
      } ?? false
    if crossedCut {
      microphone?.play(from: normal, rate: 1)
      externalAudio.start(at: normal)
    }
    if let webcamPlayer, abs(webcamPlayer.currentTime().seconds - normal * webcamDriftRatio) > 0.12 {
      syncAuxPlayers()
    }
  }

  func syncAuxPlayers() {
    let time = CMTime(seconds: webcamSourceTime(for: currentTime.seconds) * webcamDriftRatio, preferredTimescale: 60000)
    let tolerance = CMTime(value: 1, timescale: 600)
    webcamPlayer?.seek(to: time, toleranceBefore: tolerance, toleranceAfter: tolerance)
  }
}
