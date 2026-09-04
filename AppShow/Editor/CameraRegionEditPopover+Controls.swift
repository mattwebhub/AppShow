import SwiftUI

extension CameraRegionEditPopover {
  var customControls: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "arrow.up.and.down.and.arrow.left.and.right", title: "Position")

      HStack(spacing: 4) {
        ForEach(
          Array(
            zip(
              [CameraCorner.topLeft, .topRight, .bottomLeft, .bottomRight],
              ["arrow.up.left", "arrow.up.right", "arrow.down.left", "arrow.down.right"]
            )
          ),
          id: \.1
        ) { corner, icon in
          Button {
            onSetCorner(corner)
          } label: {
            Image(systemName: icon)
              .font(.system(size: FontSize.xs))
              .frame(width: 28, height: 28)
              .background(AppShowColors.fieldBackground)
              .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
              .overlay(RoundedRectangle(cornerRadius: Radius.sm).strokeBorder(AppShowColors.border))
          }
          .buttonStyle(PlainCustomButtonStyle())
          .foregroundStyle(AppShowColors.primaryText)
        }
      }

      SectionHeader(icon: "aspectratio", title: "Aspect Ratio")

      SegmentPicker(
        items: CameraAspect.allCases,
        label: { $0.label },
        selection: $localAspect
      )

      SectionHeader(icon: "paintbrush", title: "Style")

      SliderRow(
        label: "Size",
        value: $localLayout.relativeWidth,
        range: 0.1...maxCameraRelativeWidth,
        step: 0.01
      )

      SliderRow(
        label: "Radius",
        value: $localCornerRadius,
        range: 0...50,
        formattedValue: "\(Int(localCornerRadius))%"
      )

      SliderRow(
        label: "Shadow",
        value: $localShadow,
        range: 0...100,
        formattedValue: "\(Int(localShadow))"
      )

      SliderRow(
        label: "Border",
        value: $localBorderWidth,
        range: 0...30,
        step: 0.5,
        formattedValue: String(format: "%.1f", localBorderWidth)
      )

      borderColorPickerButton

      ToggleRow(label: "Mirror", isOn: $localMirrored)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 4)
  }

  var transitionControls: some View {
    TransitionControlsSection(
      entryTransition: $localEntryTransition,
      entryDuration: $localEntryDuration,
      exitTransition: $localExitTransition,
      exitDuration: $localExitDuration
    )
  }

  private var borderColorPickerButton: some View {
    TailwindColorPicker(
      color: localBorderColor,
      onSelect: { localBorderColor = $0 }
    )
  }
}
