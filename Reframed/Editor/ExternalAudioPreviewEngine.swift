import AVFoundation
import Foundation
import Logging

@MainActor
final class ExternalAudioPreviewEngine {
  private struct Player {
    let node: AVAudioPlayerNode
    let file: AVAudioFile
    var track: ExternalAudioTrackData
    var anchorTime: Double?
  }

  private let logger = Logger(label: "eu.jankuri.reframed.external-audio-preview")
  private var engine: AVAudioEngine?
  private var players: [UUID: Player] = [:]
  private var order: [UUID] = []
  private var lastDriftCheck: TimeInterval = 0
  private(set) var isRunning = false
  private(set) var scheduleCount = 0

  var trackIDs: [UUID] { order }

  func setTracks(_ tracks: [ExternalAudioTrackData], urls: [UUID: URL], currentTime: Double) {
    let ids = Set(tracks.map(\.id))
    for id in order where !ids.contains(id) {
      removePlayer(id)
    }
    for track in tracks {
      if var existing = players[track.id], existing.track.fileName == track.fileName {
        let placementChanged =
          existing.track.timelineStartSeconds != track.timelineStartSeconds
          || existing.track.fileInSeconds != track.fileInSeconds
          || existing.track.fileOutSeconds != track.fileOutSeconds
        existing.track = track
        players[track.id] = existing
        if isRunning && placementChanged {
          schedule(id: track.id, at: currentTime)
        } else {
          applyGain(id: track.id, at: currentTime)
        }
        continue
      }
      if players[track.id] != nil {
        removePlayer(track.id)
      }
      guard let url = urls[track.id], let player = makePlayer(for: track, url: url) else { continue }
      players[track.id] = player
      if isRunning {
        schedule(id: track.id, at: currentTime)
      } else {
        applyGain(id: track.id, at: currentTime)
      }
    }
    order = tracks.map(\.id).filter { players[$0] != nil }
    if players.isEmpty {
      stopEngine()
    }
  }

  func start(at time: Double) {
    isRunning = true
    lastDriftCheck = ProcessInfo.processInfo.systemUptime
    for id in order {
      schedule(id: id, at: time)
    }
  }

  func stop() {
    isRunning = false
    for id in order {
      players[id]?.node.stop()
      players[id]?.anchorTime = nil
    }
  }

  func tick(at time: Double) {
    for id in order {
      applyGain(id: id, at: time)
    }
    guard isRunning else { return }
    let now = ProcessInfo.processInfo.systemUptime
    guard now - lastDriftCheck >= 1 else { return }
    lastDriftCheck = now
    for id in order {
      guard let player = players[id], let anchor = player.anchorTime, player.node.isPlaying,
        let nodeTime = player.node.lastRenderTime,
        let playerTime = player.node.playerTime(forNodeTime: nodeTime),
        playerTime.sampleRate > 0
      else { continue }
      let played = Double(playerTime.sampleTime) / playerTime.sampleRate
      if ExternalAudioSchedule.exceedsDriftTolerance(anchorTime: anchor, playedSeconds: played, timelineTime: time) {
        logger.info("External audio drifted \(String(format: "%.0f", abs(anchor + played - time) * 1000)) ms, rescheduling")
        start(at: time)
        return
      }
    }
  }

  func teardown() {
    stop()
    for id in order {
      removePlayer(id)
    }
    order = []
    stopEngine()
  }

  func nodeVolume(for id: UUID) -> Float? {
    players[id]?.node.volume
  }

  private func makePlayer(for track: ExternalAudioTrackData, url: URL) -> Player? {
    let file: AVAudioFile
    do {
      file = try AVAudioFile(forReading: url)
    } catch {
      logger.error("Failed to open audio track \(track.fileName): \(error)")
      return nil
    }
    let engine = self.engine ?? AVAudioEngine()
    self.engine = engine
    let node = AVAudioPlayerNode()
    engine.attach(node)
    engine.connect(node, to: engine.mainMixerNode, format: file.processingFormat)
    if !engine.isRunning {
      do {
        try engine.start()
      } catch {
        logger.error("Failed to start external audio engine: \(error)")
      }
    }
    return Player(node: node, file: file, track: track, anchorTime: nil)
  }

  private func removePlayer(_ id: UUID) {
    guard let player = players.removeValue(forKey: id) else { return }
    player.node.stop()
    if let engine {
      engine.disconnectNodeOutput(player.node)
      engine.detach(player.node)
    }
  }

  private func stopEngine() {
    guard let engine else { return }
    engine.stop()
    engine.reset()
    self.engine = nil
  }

  private func schedule(id: UUID, at time: Double) {
    guard var player = players[id] else { return }
    player.node.stop()
    let sampleRate = player.file.processingFormat.sampleRate
    guard let segment = ExternalAudioSchedule.upcomingSegment(track: player.track, at: time, sampleRate: sampleRate),
      segment.startFrame < player.file.length
    else {
      player.anchorTime = nil
      players[id] = player
      return
    }
    let frameCount = AVAudioFrameCount(min(segment.frameCount, player.file.length - segment.startFrame))
    let startTime = segment.delayFrames > 0 ? AVAudioTime(sampleTime: segment.delayFrames, atRate: sampleRate) : nil
    player.node.scheduleSegment(
      player.file,
      startingFrame: AVAudioFramePosition(segment.startFrame),
      frameCount: frameCount,
      at: startTime
    )
    player.node.volume = player.track.effectiveVolume * ExternalAudioSchedule.gain(at: time, track: player.track)
    if engine?.isRunning == true {
      player.node.play()
    }
    player.anchorTime = time
    players[id] = player
    scheduleCount += 1
  }

  private func applyGain(id: UUID, at time: Double) {
    guard let player = players[id] else { return }
    player.node.volume = player.track.effectiveVolume * ExternalAudioSchedule.gain(at: time, track: player.track)
  }
}
