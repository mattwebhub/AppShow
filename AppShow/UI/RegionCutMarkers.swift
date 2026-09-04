import SwiftUI

struct RegionCutMarkers: View {
  let geometry: TimelineGeometry
  let start: Double
  let end: Double
  let originX: CGFloat
  let height: CGFloat
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    let pieces = geometry.pieces(forRegion: start, end: end)
    ForEach(Array(pieces.dropFirst().enumerated()), id: \.offset) { _, piece in
      Rectangle()
        .fill(Track.borderColor)
        .frame(width: Track.borderWidth, height: height)
        .position(x: geometry.x(forDisplay: piece.start) - originX, y: height / 2)
        .allowsHitTesting(false)
    }
  }
}
