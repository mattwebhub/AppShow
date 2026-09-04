import SwiftUI

extension TimelineView {
  func overlayTrackContent(width: CGFloat) -> some View {
    let h = trackHeight
    let overlays = editorState.textOverlays

    return ZStack(alignment: .leading) {
      ForEach(overlays) { overlay in
        textOverlayChipView(overlay: overlay, width: width, height: h)
      }
    }
    .frame(width: width, height: h)
    .clipped()
    .coordinateSpace(name: "overlayRegion")
    .contentShape(Rectangle())
    .onTapGesture(count: 2) { location in
      guard isTrackEditable else { return }
      let time = sourceTime(forX: location.x, width: width)
      let hit = overlays.contains { overlay in
        let eff = effectiveTextOverlay(overlay, width: width)
        let startX = xPosition(forSource: eff.start, width: width)
        let endX = xPosition(forSource: eff.end, width: width)
        return location.x >= startX && location.x <= endX
      }
      if !hit {
        editorState.addTextOverlay(atTime: time)
      }
    }
  }

  @ViewBuilder
  func textOverlayChipView(overlay: TextOverlayData, width: CGFloat, height: CGFloat) -> some View {
    let effective = effectiveTextOverlay(overlay, width: width)
    let startX = max(0, xPosition(forSource: effective.start, width: width))
    let endX = min(width, xPosition(forSource: effective.end, width: width))
    let regionWidth = max(4, endX - startX)
    let edgeThreshold = min(8.0, regionWidth * 0.2)
    let isPopoverShown = popoverOverlayId == overlay.id
    let chipText = overlay.text.replacingOccurrences(of: "\n", with: " ")

    ZStack {
      RoundedRectangle(cornerRadius: Track.borderRadius)
        .fill(Track.background)

      HStack(spacing: 3) {
        Image(systemName: "textformat")
          .font(.system(size: Track.fontSize))
        if regionWidth > 40 {
          Text(chipText)
            .font(.system(size: Track.fontSize, weight: Track.fontWeight))
            .lineLimit(1)
            .truncationMode(.tail)
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
        RightClickOverlay {
          popoverOverlayId = overlay.id
        }
      }
    }
    .popover(
      isPresented: Binding(
        get: { isPopoverShown },
        set: { if !$0 { popoverOverlayId = nil } }
      ),
      arrowEdge: .top
    ) {
      TextOverlayEditPopover(
        overlay: overlay,
        onUpdate: { updated in
          editorState.updateTextOverlay(id: overlay.id) { $0 = updated }
        },
        onRemove: {
          popoverOverlayId = nil
          editorState.removeTextOverlay(id: overlay.id)
        }
      )
      .presentationBackground(ReframedColors.backgroundPopover)
    }
    .gesture(
      DragGesture(minimumDistance: 3, coordinateSpace: .named("overlayRegion"))
        .onChanged { value in
          guard isTrackEditable else { return }
          if overlayDragType == nil {
            let origStartX = xPosition(forSource: overlay.startSeconds, width: width)
            let origEndX = xPosition(forSource: overlay.endSeconds, width: width)
            let origWidth = origEndX - origStartX
            let relX = value.startLocation.x - origStartX
            let effectiveEdge = min(8.0, origWidth * 0.2)
            if relX <= effectiveEdge {
              overlayDragType = .resizeLeft
            } else if relX >= origWidth - effectiveEdge {
              overlayDragType = .resizeRight
            } else {
              overlayDragType = .move
            }
            overlayDragRegionId = overlay.id
          }
          overlayDragOffset = value.translation.width
        }
        .onEnded { _ in
          guard overlayDragType != nil else { return }
          commitOverlayDrag(overlay: overlay, width: width)
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

  func effectiveTextOverlay(_ overlay: TextOverlayData, width: CGFloat) -> (start: Double, end: Double) {
    guard overlayDragRegionId == overlay.id, let dt = overlayDragType else {
      return (overlay.startSeconds, overlay.endSeconds)
    }
    let timeDelta = (overlayDragOffset / width) * visibleSeconds
    let dur = totalSeconds
    let minDuration = max(TextOverlayData.minimumLength, (24.0 / width) * dur)

    switch dt {
    case .move:
      let length = overlay.endSeconds - overlay.startSeconds
      let clampedStart = max(0, min(dur - length, overlay.startSeconds + timeDelta))
      return (clampedStart, clampedStart + length)
    case .resizeLeft:
      let newStart = max(0, min(overlay.endSeconds - minDuration, overlay.startSeconds + timeDelta))
      return (newStart, overlay.endSeconds)
    case .resizeRight:
      let newEnd = max(overlay.startSeconds + minDuration, min(dur, overlay.endSeconds + timeDelta))
      return (overlay.startSeconds, newEnd)
    }
  }

  func commitOverlayDrag(overlay: TextOverlayData, width: CGFloat) {
    let timeDelta = (overlayDragOffset / width) * visibleSeconds

    switch overlayDragType {
    case .move:
      editorState.moveTextOverlay(id: overlay.id, newStart: overlay.startSeconds + timeDelta)
    case .resizeLeft:
      editorState.updateTextOverlayStart(id: overlay.id, newStart: overlay.startSeconds + timeDelta)
    case .resizeRight:
      editorState.updateTextOverlayEnd(id: overlay.id, newEnd: overlay.endSeconds + timeDelta)
    case nil:
      break
    }
  }
}
