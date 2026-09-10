import SwiftUI

extension TimelineView {
  @ViewBuilder
  func cameraRegionView(
    region: CameraRegionData,
    width: CGFloat,
    height: CGFloat
  ) -> some View {
    let effective = effectiveCameraRegion(region, width: width)
    let startX = max(0, xPosition(forSource: effective.start, width: width))
    let endX = min(width, xPosition(forSource: effective.end, width: width))
    let regionWidth = max(4, endX - startX)
    let edgeThreshold = min(8.0, regionWidth * 0.2)
    let isPopoverShown = popoverCameraRegionId == region.id

    ZStack {
      RoundedRectangle(cornerRadius: Track.borderRadius)
        .fill(Track.background)

      HStack(spacing: 3) {
        Image(systemName: region.type.icon)
          .font(.system(size: Track.fontSize))
        if regionWidth > 50 {
          Text(region.type.label)
            .font(.system(size: Track.fontSize, weight: Track.fontWeight))
            .lineLimit(1)
        }
      }
      .foregroundStyle(Track.regionTextColor)

      HStack {
        Capsule().frame(width: 3, height: 14)
        Spacer()
        Capsule().frame(width: 3, height: 14)
      }
      .padding(.horizontal, 4)
      .foregroundStyle(AppShowColors.secondaryText)
      .allowsHitTesting(false)

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
      if isCameraTrackEditable {
        RightClickOverlay {
          popoverCameraRegionId = region.id
        }
      }
    }
    .popover(
      isPresented: Binding(
        get: { isPopoverShown },
        set: { if !$0 { popoverCameraRegionId = nil } }
      ),
      arrowEdge: .top
    ) {
      CameraRegionEditPopover(
        region: region,
        onUpdateStart: { editorState.updateCameraRegionStart(regionId: region.id, newStart: $0) },
        onUpdateEnd: { editorState.updateCameraRegionEnd(regionId: region.id, newEnd: $0) },
        maxCameraRelativeWidth: editorState.maxCameraRelativeWidth(for: region.customCameraAspect ?? editorState.cameraAspect),
        onChangeType: { newType in
          editorState.updateCameraRegionType(regionId: region.id, type: newType)
        },
        onUpdateLayout: { layout in
          editorState.updateCameraRegionLayout(regionId: region.id, layout: layout)
          editorState.clampCameraRegionLayout(regionId: region.id)
        },
        onSetCorner: { corner in
          editorState.setCameraRegionCorner(regionId: region.id, corner: corner)
        },
        onUpdateStyle: { aspect, cornerRadius, shadow, borderWidth, borderColor, mirrored in
          editorState.updateCameraRegionStyle(
            regionId: region.id,
            aspect: aspect,
            cornerRadius: cornerRadius,
            shadow: shadow,
            borderWidth: borderWidth,
            borderColor: borderColor,
            mirrored: mirrored
          )
        },
        onUpdateTransition: { entryType, entryDur, exitType, exitDur in
          editorState.updateCameraRegionTransition(
            regionId: region.id,
            entryTransition: entryType,
            entryDuration: entryDur,
            exitTransition: exitType,
            exitDuration: exitDur
          )
        },
        onRemove: {
          popoverCameraRegionId = nil
          editorState.removeCameraRegion(regionId: region.id)
        }
      )
      .presentationBackground(AppShowColors.backgroundPopover)
    }
    .onTapGesture { popoverCameraRegionId = region.id }
    .help("Drag to move; drag an edge to resize; click to edit timing and animation")
    .gesture(
      DragGesture(minimumDistance: 3, coordinateSpace: .named("cameraRegion"))
        .onChanged { value in
          guard isCameraTrackEditable else { return }
          if cameraDragType == nil {
            let origStartX = xPosition(forSource: region.startSeconds, width: width)
            let origEndX = xPosition(forSource: region.endSeconds, width: width)
            let origWidth = origEndX - origStartX
            let relX = value.startLocation.x - origStartX
            let effectiveEdge = min(8.0, origWidth * 0.2)
            if relX <= effectiveEdge {
              cameraDragType = .resizeLeft
            } else if relX >= origWidth - effectiveEdge {
              cameraDragType = .resizeRight
            } else {
              cameraDragType = .move
            }
            cameraDragRegionId = region.id
            cameraDragAnchorTime = sourceTime(forX: value.startLocation.x, width: width)
          }
          cameraDragOffset = value.translation.width
        }
        .onEnded { _ in
          guard cameraDragType != nil else { return }
          commitCameraDrag(region: region, width: width)
          cameraDragOffset = 0
          cameraDragType = nil
          cameraDragRegionId = nil
        }
    )
    .onContinuousHover { phase in
      switch phase {
      case .active(let location):
        if !isCameraTrackEditable {
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

}
