import SwiftUI

extension ZoomKeyframeEditor {
  @ViewBuilder
  func regionView(for region: ZoomRegion) -> some View {
    let times = effectiveTimes(for: region)
    let startX = max(0, geometry.x(forSource: times.start))
    let endX = min(width, geometry.x(forSource: times.end))
    let regionWidth = max(4, endX - startX)
    let totalDur = times.end - times.start
    let easeIn = times.zoomStart - times.start
    let easeOut = times.end - times.zoomEnd

    let edgeThreshold = min(8.0, regionWidth * 0.2)

    ZStack {
      RoundedRectangle(cornerRadius: Track.borderRadius)
        .fill(Track.background)

      HStack(spacing: 3) {
        Image(systemName: region.isAuto ? "sparkle.magnifyingglass" : "plus.magnifyingglass")
          .font(.system(size: Track.fontSize))
        if regionWidth > 50 {
          Text(String(format: "%.1fx", region.peakZoom))
            .font(.system(size: Track.fontSize, weight: Track.fontWeight))
            .lineLimit(1)
        }
        if regionWidth > 90 {
          Text(String(format: "%.1fs", totalDur))
            .font(.system(size: Track.fontSize))
            .lineLimit(1)
        }
        if regionWidth > 160, easeIn > 0.01 || easeOut > 0.01 {
          Text(String(format: "↗%.1fs ↘%.1fs", easeIn, easeOut))
            .font(.system(size: Track.fontSize - 1))
            .lineLimit(1)
        }
      }
      .foregroundStyle(Track.regionTextColor)
      .padding(.horizontal, 10)

      RoundedRectangle(cornerRadius: Track.borderRadius)
        .strokeBorder(Track.borderColor, lineWidth: Track.borderWidth)

      HStack {
        Capsule().frame(width: 2, height: 12)
        Spacer(minLength: 0)
        Capsule().frame(width: 2, height: 12)
      }
      .foregroundStyle(Track.regionTextColor.opacity(0.5))
      .padding(.horizontal, 4)
      .allowsHitTesting(false)

      RegionCutMarkers(
        geometry: geometry,
        start: times.start,
        end: times.end,
        originX: startX,
        height: height
      )
    }
    .frame(width: regionWidth, height: height)
    .contentShape(Rectangle())
    .overlay {
      if isEditable {
        RightClickOverlay {
          popoverRegionIndex = region.startIndex
        }
      }
    }
    .gesture(
      DragGesture(minimumDistance: 3, coordinateSpace: .named("zoomEditor"))
        .onChanged { value in
          guard isEditable else { return }
          popoverRegionIndex = nil
          if dragType == nil {
            let origStartX = geometry.x(forSource: region.startTime)
            let origEndX = geometry.x(forSource: region.endTime)
            let origWidth = origEndX - origStartX
            let relX = value.startLocation.x - origStartX
            let effectiveEdge = min(8.0, origWidth * 0.2)
            if relX <= effectiveEdge {
              dragType = .resizeLeft
            } else if relX >= origWidth - effectiveEdge {
              dragType = .resizeRight
            } else {
              dragType = .move
            }
            dragRegionStartIndex = region.startIndex
          }
          let anchorX: CGFloat
          let anchorTime: Double
          switch dragType {
          case .resizeLeft:
            anchorX = geometry.x(forSource: region.startTime)
            anchorTime = region.startTime
          case .resizeRight:
            anchorX = geometry.x(forSource: region.endTime)
            anchorTime = region.endTime
          default:
            anchorX = value.startLocation.x
            anchorTime = geometry.sourceTime(forX: anchorX)
          }
          dragSourceDelta = geometry.sourceTime(forX: anchorX + value.translation.width) - anchorTime
        }
        .onEnded { _ in
          guard dragType != nil else { return }
          commitDrag(for: region)
          dragSourceDelta = 0
          dragType = nil
          dragRegionStartIndex = nil
        }
    )
    .popover(
      isPresented: Binding(
        get: { popoverRegionIndex == region.startIndex },
        set: { if !$0 { popoverRegionIndex = nil } }
      )
    ) {
      RegionEditPopover(
        region: region,
        originalKeyframes: Array(keyframes[region.startIndex..<(region.startIndex + region.count)]),
        duration: duration,
        onUpdate: onUpdateRegion,
        onRemove: {
          popoverRegionIndex = nil
          onRemoveRegion(region.startIndex, region.count)
        }
      )
      .presentationBackground(AppShowColors.backgroundPopover)
    }
    .help("Drag to move · Drag either edge to change duration · Right-click for settings")
    .onContinuousHover { phase in
      guard isEditable else { return }
      switch phase {
      case .active(let location):
        if location.x <= edgeThreshold || location.x >= regionWidth - edgeThreshold {
          NSCursor.resizeLeftRight.set()
        } else {
          NSCursor.openHand.set()
        }
      case .ended:
        NSCursor.arrow.set()
      @unknown default:
        break
      }
    }
    .position(x: startX + regionWidth / 2, y: height / 2)
  }
}
