import AVFoundation
import SwiftUI

extension TimelineView {
  func cutTrackContent(width: CGFloat) -> some View {
    let h = trackHeight
    let geometry = geometry(width: width)

    return ZStack(alignment: .leading) {
      if geometry.mode == .source {
        ForEach(Array(geometry.timeline.gaps.enumerated()), id: \.offset) { _, gap in
          let startX = max(0, geometry.x(forSource: gap.lowerBound))
          let endX = min(width, geometry.x(forSource: gap.upperBound))
          RoundedRectangle(cornerRadius: Track.borderRadius)
            .fill(Track.background.opacity(0.35))
            .frame(width: max(0, endX - startX), height: h)
            .position(x: startX + (endX - startX) / 2, y: h / 2)
            .allowsHitTesting(false)
        }
      }

      ForEach(editorState.cutTimeline.slices) { region in
        videoRegionView(
          region: region,
          width: width,
          height: h
        )
      }
    }
    .frame(width: width, height: h)
    .clipped()
    .coordinateSpace(name: "videoRegion")
    .contentShape(Rectangle())
    .onTapGesture(count: 2) { location in
      let time = sourceTime(forX: location.x, width: width)
      editorState.addVideoRegion(atTime: time)
    }
  }

  @ViewBuilder
  func videoRegionView(
    region: VideoRegionData,
    width: CGFloat,
    height: CGFloat
  ) -> some View {
    let effective = effectiveVideoRegion(region, width: width)
    let startX = max(0, xPosition(forSource: effective.start, width: width))
    let endX = min(width, xPosition(forSource: effective.end, width: width))
    let regionWidth = max(4, endX - startX)
    let edgeThreshold = min(8.0, regionWidth * 0.2)
    let isPopoverShown = popoverVideoRegionId == region.id
    let isSelected = editorState.selectedVideoRegionID == region.id

    ZStack {
      RoundedRectangle(cornerRadius: Track.borderRadius)
        .fill(isSelected ? AppShowColors.selectedBackground : Track.background)

      HStack(spacing: 3) {
        Image(systemName: "film")
          .font(.system(size: Track.fontSize))
        if regionWidth > 50 {
          Text(formatTimeRange(start: effective.start, end: effective.end))
            .font(.system(size: Track.fontSize, weight: Track.fontWeight))
            .lineLimit(1)
        }
      }
      .foregroundStyle(Track.regionTextColor)
      .padding(.horizontal, 10)

      RoundedRectangle(cornerRadius: Track.borderRadius)
        .strokeBorder(isSelected ? AppShowColors.primaryText : Track.borderColor, lineWidth: isSelected ? 2 : Track.borderWidth)

      HStack {
        Capsule().frame(width: 2, height: 12)
        Spacer(minLength: 0)
        Capsule().frame(width: 2, height: 12)
      }
      .foregroundStyle(isSelected ? AppShowColors.primaryText : Track.regionTextColor.opacity(0.5))
      .padding(.horizontal, 4)
      .allowsHitTesting(false)
    }
    .frame(width: regionWidth, height: height)
    .clipShape(RoundedRectangle(cornerRadius: Track.borderRadius))
    .contentShape(Rectangle())
    .overlay {
      RightClickOverlay {
        editorState.selectedVideoRegionID = region.id
        popoverVideoRegionId = region.id
      }
    }
    .popover(
      isPresented: Binding(
        get: { isPopoverShown },
        set: { if !$0 { popoverVideoRegionId = nil } }
      ),
      arrowEdge: .top
    ) {
      VideoRegionEditPopover(
        region: region,
        canRemove: editorState.videoRegions.count > 1,
        onUpdateTransition: { entryType, entryDur, exitType, exitDur in
          editorState.updateVideoRegionTransition(
            regionId: region.id,
            entryTransition: entryType,
            entryDuration: entryDur,
            exitTransition: exitType,
            exitDuration: exitDur
          )
        },
        onRemove: {
          popoverVideoRegionId = nil
          editorState.removeVideoRegion(regionId: region.id)
        }
      )
      .presentationBackground(AppShowColors.backgroundPopover)
    }
    .onTapGesture {
      NSApp.keyWindow?.makeFirstResponder(nil)
      editorState.selectVideoRegion(region.id)
    }
    .gesture(videoRegionDrag(region: region, width: width))
    .help("Click to select · Delete to remove · Drag an edge to adjust the cut")
    .onContinuousHover { phase in
      switch phase {
      case .active(let location):
        if location.x <= edgeThreshold || location.x >= regionWidth - edgeThreshold {
          NSCursor.resizeLeftRight.set()
        } else if isTrackEditable {
          NSCursor.openHand.set()
        } else {
          NSCursor.arrow.set()
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
