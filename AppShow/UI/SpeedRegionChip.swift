import SwiftUI

struct SpeedRegionChip: View {
  let region: SpeedRegionData
  let geometry: TimelineGeometry
  let height: CGFloat
  let bounds: ClosedRange<Double>
  let isEditable: Bool
  let duration: Double
  let onUpdate: (SpeedRegionData) throws -> Void
  let onRemove: () -> Void
  @State private var edited: SpeedRegionData?
  @State private var drag: RegionDragType?
  @State private var showingEditor = false

  var body: some View {
    let effective = edited ?? region
    let start = geometry.x(forSource: effective.startSeconds)
    let end = geometry.x(forSource: effective.endSeconds)
    let width = max(4, end - start)
    ZStack {
      RoundedRectangle(cornerRadius: Track.borderRadius).fill(Track.background)
      HStack(spacing: 4) {
        Image(systemName: "speedometer")
        if width > 45 { Text(region.label).lineLimit(1) }
      }
      .font(.system(size: Track.fontSize, weight: Track.fontWeight))
      .foregroundStyle(Track.regionTextColor)
      HStack {
        Capsule().frame(width: 2, height: 12)
        Spacer(minLength: 0)
        Capsule().frame(width: 2, height: 12)
      }
      .padding(.horizontal, 4)
      .foregroundStyle(Track.regionTextColor.opacity(0.5))
      RoundedRectangle(cornerRadius: Track.borderRadius).strokeBorder(Track.borderColor, lineWidth: Track.borderWidth)
      RegionCutMarkers(geometry: geometry, start: effective.startSeconds, end: effective.endSeconds, originX: start, height: height)
    }
    .frame(width: width, height: height)
    .contentShape(Rectangle())
    .overlay {
      if isEditable { RightClickOverlay { showingEditor = true } }
    }
    .onTapGesture { if isEditable { showingEditor = true } }
    .popover(isPresented: $showingEditor) {
      SpeedRegionEditor(region: region, duration: duration, onApply: onUpdate, onRemove: onRemove)
    }
    .gesture(
      DragGesture(minimumDistance: 3, coordinateSpace: .named("speedTrack"))
        .onChanged { value in
          guard isEditable else { return }
          showingEditor = false
          if drag == nil {
            let left = geometry.x(forSource: region.startSeconds)
            let right = geometry.x(forSource: region.endSeconds)
            let edge = min(8, (right - left) * 0.2)
            drag = value.startLocation.x - left <= edge ? .resizeLeft : right - value.startLocation.x <= edge ? .resizeRight : .move
          }
          let delta = geometry.sourceTime(forX: value.location.x) - geometry.sourceTime(forX: value.startLocation.x)
          var changed = region
          switch drag {
          case .move:
            let length = region.endSeconds - region.startSeconds
            changed.startSeconds = max(bounds.lowerBound, min(bounds.upperBound - length, region.startSeconds + delta))
            changed.endSeconds = changed.startSeconds + length
          case .resizeLeft:
            changed.startSeconds = max(bounds.lowerBound, min(region.endSeconds - 0.05, region.startSeconds + delta))
          case .resizeRight:
            changed.endSeconds = min(bounds.upperBound, max(region.startSeconds + 0.05, region.endSeconds + delta))
          case nil: break
          }
          edited = changed
        }
        .onEnded { _ in
          if let edited { try? onUpdate(edited) }
          edited = nil
          drag = nil
        }
    )
    .onContinuousHover { phase in
      switch phase {
      case .active(let point):
        if !isEditable {
          NSCursor.arrow.set()
        } else if point.x < 8 || point.x > width - 8 {
          NSCursor.resizeLeftRight.set()
        } else {
          NSCursor.openHand.set()
        }
      case .ended: NSCursor.arrow.set()
      @unknown default: break
      }
    }
    .position(x: start + width / 2, y: height / 2)
    .help("Drag to move; drag an edge to resize; right-click to edit speed")
  }
}
