import Foundation

enum AgentToolCursorActivity {
  static let defaultDwellSeconds = 0.5
  static let keystrokeGapSeconds = 1.0

  struct ClickCluster: Sendable, Equatable {
    var start: Double
    var end: Double
    var x: Double
    var y: Double
    var clicks: Int
  }

  struct KeystrokeBurst: Sendable, Equatable {
    var start: Double
    var end: Double
    var count: Int
  }

  static func clickClusters(clicks: [CursorClickEvent], dwellSeconds: Double, from: Double?, to: Double?) -> [ClickCluster] {
    var clusters: [ClickCluster] = []
    for click in clicks.filter({ inWindow($0.t, from: from, to: to) }).sorted(by: { $0.t < $1.t }) {
      if var last = clusters.last, click.t - last.end < dwellSeconds {
        let total = Double(last.clicks + 1)
        last.x = (last.x * Double(last.clicks) + click.x) / total
        last.y = (last.y * Double(last.clicks) + click.y) / total
        last.end = click.t
        last.clicks += 1
        clusters[clusters.count - 1] = last
      } else {
        clusters.append(ClickCluster(start: click.t, end: click.t, x: click.x, y: click.y, clicks: 1))
      }
    }
    return clusters
  }

  static func keystrokeBursts(
    keystrokes: [KeystrokeEvent],
    gapSeconds: Double = keystrokeGapSeconds,
    from: Double?,
    to: Double?
  ) -> [KeystrokeBurst] {
    var bursts: [KeystrokeBurst] = []
    for key in keystrokes.filter({ $0.isDown && inWindow($0.t, from: from, to: to) }).sorted(by: { $0.t < $1.t }) {
      if var last = bursts.last, key.t - last.end < gapSeconds {
        last.end = key.t
        last.count += 1
        bursts[bursts.count - 1] = last
      } else {
        bursts.append(KeystrokeBurst(start: key.t, end: key.t, count: 1))
      }
    }
    return bursts
  }

  static func summary(metadata: CursorMetadataFile?, dwellSeconds: Double, from: Double?, to: Double?) -> JSONValue {
    guard let metadata else {
      return ["available": false, "clickCount": 0, "clickClusters": [], "keystrokeBursts": []]
    }
    let clicks = metadata.clicks.filter { inWindow($0.t, from: from, to: to) }
    let clusters = clickClusters(clicks: metadata.clicks, dwellSeconds: dwellSeconds, from: from, to: to)
    let bursts = keystrokeBursts(keystrokes: metadata.keystrokes, from: from, to: to)
    return [
      "available": true,
      "sampleRateHz": JSONValue(metadata.sampleRateHz),
      "clickCount": JSONValue(clicks.count),
      "clickClusters": .array(
        clusters.map {
          [
            "start": AgentToolSummaries.seconds($0.start),
            "end": AgentToolSummaries.seconds($0.end),
            "x": .number(($0.x * 10000).rounded() / 10000),
            "y": .number(($0.y * 10000).rounded() / 10000),
            "clicks": JSONValue($0.clicks),
          ]
        }
      ),
      "keystrokeBursts": .array(
        bursts.map {
          ["start": AgentToolSummaries.seconds($0.start), "end": AgentToolSummaries.seconds($0.end), "count": JSONValue($0.count)]
        }
      ),
    ]
  }

  private static func inWindow(_ time: Double, from: Double?, to: Double?) -> Bool {
    time >= (from ?? -.infinity) && time <= (to ?? .infinity)
  }
}
