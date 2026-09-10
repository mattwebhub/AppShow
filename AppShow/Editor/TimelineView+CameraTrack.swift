import SwiftUI

extension TimelineView {
  func cameraTrackContent(width: CGFloat) -> some View {
    let h = trackHeight
    let regions = editorState.cameraRegions

    return ZStack(alignment: .leading) {
      ForEach(regions) { region in
        cameraRegionView(
          region: region,
          width: width,
          height: h
        )
      }

      if regions.isEmpty {
        let viewportWidth = width / timelineZoom
        let visibleCenterX = scrollOffset + viewportWidth / 2
        Text("Double-click to focus webcam")
          .font(.system(size: FontSize.xs))
          .foregroundStyle(AppShowColors.secondaryText)
          .fixedSize()
          .position(x: visibleCenterX, y: h / 2)
          .allowsHitTesting(false)
      }
    }
    .frame(width: width, height: h)
    .clipped()
    .coordinateSpace(name: "cameraRegion")
    .contentShape(Rectangle())
    .onTapGesture(count: 2) { location in
      guard isCameraTrackEditable else { return }
      let time = sourceTime(forX: location.x, width: width)
      let hitRegion = regions.first { r in
        let eff = effectiveCameraRegion(r, width: width)
        let startX = xPosition(forSource: eff.start, width: width)
        let endX = xPosition(forSource: eff.end, width: width)
        return location.x >= startX && location.x <= endX
      }
      if hitRegion == nil {
        editorState.focusWebcam(atTime: time)
      }
    }
  }

}
