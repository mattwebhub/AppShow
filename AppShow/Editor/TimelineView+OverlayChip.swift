import SwiftUI

enum OverlayChip: Identifiable {
  enum ID: Hashable {
    case text(UUID)
    case image(UUID)
    case blur(UUID)
  }

  case text(TextOverlayData)
  case image(ImageOverlayData)
  case blur(BlurRegionData)

  var id: ID {
    switch self {
    case .text(let overlay): .text(overlay.id)
    case .image(let overlay): .image(overlay.id)
    case .blur(let region): .blur(region.id)
    }
  }

  var startSeconds: Double {
    switch self {
    case .text(let overlay): overlay.startSeconds
    case .image(let overlay): overlay.startSeconds
    case .blur(let region): region.startSeconds
    }
  }

  var endSeconds: Double {
    switch self {
    case .text(let overlay): overlay.endSeconds
    case .image(let overlay): overlay.endSeconds
    case .blur(let region): region.endSeconds
    }
  }

  static func timeline(
    text: [TextOverlayData],
    images: [ImageOverlayData],
    blurs: [BlurRegionData] = []
  ) -> [OverlayChip] {
    let chips = text.map(OverlayChip.text) + images.map(OverlayChip.image) + blurs.map(OverlayChip.blur)
    return chips.enumerated().sorted {
      if $0.element.startSeconds != $1.element.startSeconds {
        return $0.element.startSeconds < $1.element.startSeconds
      }
      return $0.offset < $1.offset
    }.map(\.element)
  }
}

extension TimelineView {
  @ViewBuilder
  func overlayChipView(chip: OverlayChip, width: CGFloat, height: CGFloat) -> some View {
    switch chip {
    case .text(let overlay):
      textOverlayChipView(overlay: overlay, width: width, height: height)
    case .image(let overlay):
      imageOverlayChipView(overlay: overlay, width: width, height: height)
    case .blur(let region):
      blurRegionChipView(region: region, width: width, height: height)
    }
  }

  func imageOverlayChipView(overlay: ImageOverlayData, width: CGFloat, height: CGFloat) -> some View {
    let effective = effectiveImageOverlay(overlay, width: width)
    let startX = max(0, xPosition(forSource: effective.start, width: width))
    let endX = min(width, xPosition(forSource: effective.end, width: width))
    let regionWidth = max(4, endX - startX)
    let edgeThreshold = min(8.0, regionWidth * 0.2)
    let isPopoverShown = popoverOverlayId == overlay.id

    return ZStack {
      RoundedRectangle(cornerRadius: Track.borderRadius)
        .fill(Track.background)

      HStack(spacing: 3) {
        Image(systemName: "photo")
          .font(.system(size: Track.fontSize))
        if regionWidth > 40 {
          Text(overlay.displayName)
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
      ImageOverlayEditPopover(
        overlay: overlay,
        imageURL: editorState.imageOverlayURL(overlay),
        onUpdate: { updated in
          editorState.updateImageOverlay(id: overlay.id) { $0 = updated }
        },
        onRemove: {
          popoverOverlayId = nil
          editorState.removeImageOverlay(id: overlay.id)
        }
      )
      .presentationBackground(AppShowColors.backgroundPopover)
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
          commitImageOverlayDrag(overlay: overlay, width: width)
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

  func effectiveImageOverlay(_ overlay: ImageOverlayData, width: CGFloat) -> (start: Double, end: Double) {
    guard overlayDragRegionId == overlay.id, let dragType = overlayDragType else {
      return (overlay.startSeconds, overlay.endSeconds)
    }
    let timeDelta = (overlayDragOffset / width) * visibleSeconds
    let duration = totalSeconds
    let minimumDuration = max(ImageOverlayData.minimumLength, (24.0 / width) * duration)

    switch dragType {
    case .move:
      let length = overlay.endSeconds - overlay.startSeconds
      let start = max(0, min(duration - length, overlay.startSeconds + timeDelta))
      return (start, start + length)
    case .resizeLeft:
      let start = max(0, min(overlay.endSeconds - minimumDuration, overlay.startSeconds + timeDelta))
      return (start, overlay.endSeconds)
    case .resizeRight:
      let end = max(overlay.startSeconds + minimumDuration, min(duration, overlay.endSeconds + timeDelta))
      return (overlay.startSeconds, end)
    }
  }

  func commitImageOverlayDrag(overlay: ImageOverlayData, width: CGFloat) {
    let timeDelta = (overlayDragOffset / width) * visibleSeconds

    switch overlayDragType {
    case .move:
      editorState.moveImageOverlay(id: overlay.id, newStart: overlay.startSeconds + timeDelta)
    case .resizeLeft:
      editorState.updateImageOverlayStart(id: overlay.id, newStart: overlay.startSeconds + timeDelta)
    case .resizeRight:
      editorState.updateImageOverlayEnd(id: overlay.id, newEnd: overlay.endSeconds + timeDelta)
    case nil:
      break
    }
  }
}
