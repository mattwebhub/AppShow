import SwiftUI

extension TimelineView {
  func blurRegionChipView(region: BlurRegionData, width: CGFloat, height: CGFloat) -> some View {
    let effective = effectiveBlurRegion(region, width: width)
    let startX = max(0, xPosition(forSource: effective.start, width: width))
    let endX = min(width, xPosition(forSource: effective.end, width: width))
    let regionWidth = max(4, endX - startX)
    let edgeThreshold = min(8.0, regionWidth * 0.2)
    let isPopoverShown = popoverOverlayId == region.id

    return ZStack {
      RoundedRectangle(cornerRadius: Track.borderRadius)
        .fill(Track.background)

      HStack(spacing: 3) {
        Image(systemName: "drop.halffull")
          .font(.system(size: Track.fontSize))
        if regionWidth > 40 {
          Text("Blur")
            .font(.system(size: Track.fontSize, weight: Track.fontWeight))
            .lineLimit(1)
        }
      }
      .padding(.horizontal, 6)
      .foregroundStyle(Track.regionTextColor)

      RoundedRectangle(cornerRadius: Track.borderRadius)
        .strokeBorder(Track.borderColor, lineWidth: Track.borderWidth)

      RegionCutMarkers(
        geometry: geometry(width: width),
        start: effective.start,
        end: effective.end,
        originX: startX,
        height: height
      )
    }
    .frame(width: regionWidth, height: height)
    .clipShape(RoundedRectangle(cornerRadius: Track.borderRadius))
    .contentShape(Rectangle())
    .overlay {
      if isTrackEditable {
        RightClickOverlay { popoverOverlayId = region.id }
      }
    }
    .popover(
      isPresented: Binding(
        get: { isPopoverShown },
        set: { if !$0 { popoverOverlayId = nil } }
      ),
      arrowEdge: .top
    ) {
      BlurRegionEditPopover(
        region: region,
        onUpdate: { updated in
          editorState.updateBlurRegion(id: region.id) { $0 = updated }
        },
        onRemove: {
          popoverOverlayId = nil
          editorState.removeBlurRegion(id: region.id)
        }
      )
      .presentationBackground(AppShowColors.backgroundPopover)
    }
    .gesture(
      DragGesture(minimumDistance: 3, coordinateSpace: .named("overlayRegion"))
        .onChanged { value in
          guard isTrackEditable else { return }
          if overlayDragType == nil {
            let originalStart = xPosition(forSource: region.startSeconds, width: width)
            let originalEnd = xPosition(forSource: region.endSeconds, width: width)
            let originalWidth = originalEnd - originalStart
            let relativeX = value.startLocation.x - originalStart
            let effectiveEdge = min(8.0, originalWidth * 0.2)
            if relativeX <= effectiveEdge {
              overlayDragType = .resizeLeft
            } else if relativeX >= originalWidth - effectiveEdge {
              overlayDragType = .resizeRight
            } else {
              overlayDragType = .move
            }
            overlayDragRegionId = region.id
          }
          overlayDragOffset = value.translation.width
        }
        .onEnded { _ in
          guard overlayDragType != nil else { return }
          commitBlurRegionDrag(region: region, width: width)
          overlayDragOffset = 0
          overlayDragType = nil
          overlayDragRegionId = nil
        }
    )
    .onContinuousHover { phase in
      switch phase {
      case .active(let location):
        if !isTrackEditable {
          NSCursor.arrow.set()
        } else if location.x <= edgeThreshold || location.x >= regionWidth - edgeThreshold {
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

  func effectiveBlurRegion(_ region: BlurRegionData, width: CGFloat) -> (start: Double, end: Double) {
    guard overlayDragRegionId == region.id, let dragType = overlayDragType else {
      return (region.startSeconds, region.endSeconds)
    }
    let timeDelta = (overlayDragOffset / width) * visibleSeconds
    let duration = totalSeconds
    let minimumDuration = max(BlurRegionData.minimumLength, (24.0 / width) * duration)

    switch dragType {
    case .move:
      let length = region.endSeconds - region.startSeconds
      let start = max(0, min(duration - length, region.startSeconds + timeDelta))
      return (start, start + length)
    case .resizeLeft:
      return (max(0, min(region.endSeconds - minimumDuration, region.startSeconds + timeDelta)), region.endSeconds)
    case .resizeRight:
      return (region.startSeconds, max(region.startSeconds + minimumDuration, min(duration, region.endSeconds + timeDelta)))
    }
  }

  func commitBlurRegionDrag(region: BlurRegionData, width: CGFloat) {
    let timeDelta = (overlayDragOffset / width) * visibleSeconds
    switch overlayDragType {
    case .move:
      editorState.moveBlurRegion(id: region.id, newStart: region.startSeconds + timeDelta)
    case .resizeLeft:
      editorState.updateBlurRegionStart(id: region.id, newStart: region.startSeconds + timeDelta)
    case .resizeRight:
      editorState.updateBlurRegionEnd(id: region.id, newEnd: region.endSeconds + timeDelta)
    case nil:
      break
    }
  }
}
