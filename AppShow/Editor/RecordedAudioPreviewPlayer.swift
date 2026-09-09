import AVFoundation

@MainActor
final class RecordedAudioPreviewPlayer {
  private let engine = AVAudioEngine()
  private let node = AVAudioPlayerNode()
  private let pitch = AVAudioUnitTimePitch()
  private let drift = AVAudioUnitVarispeed()
  private let file: AVAudioFile
  var volume: Float = 1 { didSet { applyVolume() } }
  var muted = false { didSet { applyVolume() } }
  var driftRatio: Double = 1
  private(set) var rate: Double = 1
  var duration: Double { Double(file.length) / file.processingFormat.sampleRate }

  init(url: URL) throws {
    file = try AVAudioFile(forReading: url)
    engine.attach(node)
    engine.attach(pitch)
    engine.attach(drift)
    engine.connect(node, to: pitch, format: file.processingFormat)
    engine.connect(pitch, to: drift, format: file.processingFormat)
    engine.connect(drift, to: engine.mainMixerNode, format: file.processingFormat)
  }

  func play(from sourceTime: Double, rate: Double) {
    stop()
    setRate(rate)
    let start = max(0, AVAudioFramePosition(sourceTime * driftRatio * file.processingFormat.sampleRate))
    guard start < file.length else { return }
    if !engine.isRunning { try? engine.start() }
    node.scheduleSegment(file, startingFrame: start, frameCount: AVAudioFrameCount(min(Int64(UInt32.max), file.length - start)), at: nil)
    applyVolume()
    node.play()
  }

  func setRate(_ value: Double) {
    rate = value
    pitch.rate = Float(value)
    drift.rate = Float(driftRatio)
  }

  func stop() { node.stop() }

  func teardown() {
    stop()
    engine.stop()
    engine.reset()
  }

  private func applyVolume() { node.volume = muted ? 0 : volume }
}
