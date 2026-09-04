import SwiftUI

struct OverlayPositionControls: View {
  @Binding var position: TextOverlayPosition
  @Binding var offsetX: CGFloat
  @Binding var offsetY: CGFloat
  let labelWidth: CGFloat
  let valueWidth: CGFloat

  var body: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "arrow.up.left.and.down.right", title: "Position")

      VStack(spacing: Layout.compactSpacing) {
        SegmentPicker(
          items: [TextOverlayPosition.topLeft, .top, .topRight],
          label: { $0.label },
          selection: $position
        )
        SegmentPicker(
          items: [TextOverlayPosition.center],
          label: { $0.label },
          selection: $position
        )
        SegmentPicker(
          items: [TextOverlayPosition.bottomLeft, .bottom, .bottomRight],
          label: { $0.label },
          selection: $position
        )
      }

      SliderRow(
        label: "Offset X",
        labelWidth: labelWidth,
        value: $offsetX,
        range: -0.5...0.5,
        step: 0.01,
        formattedValue: "\(Int((offsetX * 100).rounded()))%",
        valueWidth: valueWidth
      )

      SliderRow(
        label: "Offset Y",
        labelWidth: labelWidth,
        value: $offsetY,
        range: -0.5...0.5,
        step: 0.01,
        formattedValue: "\(Int((offsetY * 100).rounded()))%",
        valueWidth: valueWidth
      )
    }
  }
}
