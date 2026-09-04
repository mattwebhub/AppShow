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
            .foregroundStyle(AppShowColors.secondaryText)
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
    OverlayPositionControls(
      position: $local.position,
      offsetX: $local.offsetX,
      offsetY: $local.offsetY,
      labelWidth: labelWidth,
      valueWidth: valueWidth
    )
  }
}
