import Foundation

enum SpeedPreset: Double, CaseIterable, Identifiable, Sendable {
  case oneAndHalf = 1.5
  case two = 2
  case four = 4
  case eight = 8
  case sixteen = 16
  case thirtyTwo = 32
  var id: Double { rawValue }
  var label: String { "\(rawValue.formatted(.number.precision(.fractionLength(0...1))))×" }
}

struct SpeedRegionData: Codable, Sendable, Equatable, Identifiable {
  var id: UUID = UUID()
  var startSeconds: Double
  var endSeconds: Double
  var rate: Double

  var label: String { SpeedPreset(rawValue: rate)?.label ?? "1×" }

  func isValid(duration: Double) -> Bool {
    startSeconds.isFinite && endSeconds.isFinite && startSeconds >= 0 && endSeconds <= duration
      && endSeconds - startSeconds >= 0.05 && SpeedPreset(rawValue: rate) != nil
  }
}
