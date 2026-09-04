import SwiftUI

extension TextOverlayEditPopover {
  var backgroundControls: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "rectangle.fill", title: "Background")

      ToggleRow(label: "Show Background", isOn: $local.showBackground)

      if local.showBackground {
        HStack(spacing: 8) {
          Text("Color")
            .font(.system(size: FontSize.xs))
            .foregroundStyle(ReframedColors.secondaryText)
            .frame(width: labelWidth, alignment: .leading)
          TailwindColorPicker(
            color: local.backgroundColor,
            onSelect: { local.backgroundColor = $0 }
          )
        }

        SliderRow(
          label: "Opacity",
          labelWidth: labelWidth,
          value: $local.backgroundOpacity,
          range: 0.1...1.0,
          step: 0.05,
          formattedValue: "\(Int((local.backgroundOpacity * 100).rounded()))%",
          valueWidth: valueWidth
        )

        SliderRow(
          label: "Corners",
          labelWidth: labelWidth,
          value: $local.cornerRadius,
          range: 0...0.5,
          step: 0.05,
          formattedValue: "\(Int((local.cornerRadius * 200).rounded()))%",
          valueWidth: valueWidth
        )
      }
    }
  }

  var positionControls: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "arrow.up.left.and.down.right", title: "Position")

      VStack(spacing: Layout.compactSpacing) {
        SegmentPicker(
          items: [TextOverlayPosition.topLeft, .top, .topRight],
          label: { $0.label },
          selection: $local.position
        )
        SegmentPicker(
          items: [TextOverlayPosition.center],
          label: { $0.label },
          selection: $local.position
        )
        SegmentPicker(
          items: [TextOverlayPosition.bottomLeft, .bottom, .bottomRight],
          label: { $0.label },
          selection: $local.position
        )
      }

      SliderRow(
        label: "Offset X",
        labelWidth: labelWidth,
        value: $local.offsetX,
        range: -0.5...0.5,
        step: 0.01,
        formattedValue: "\(Int((local.offsetX * 100).rounded()))%",
        valueWidth: valueWidth
      )

      SliderRow(
        label: "Offset Y",
        labelWidth: labelWidth,
        value: $local.offsetY,
        range: -0.5...0.5,
        step: 0.01,
        formattedValue: "\(Int((local.offsetY * 100).rounded()))%",
        valueWidth: valueWidth
      )
    }
  }
}
