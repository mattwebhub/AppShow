import SwiftUI

struct BlurRegionEditPopover: View {
  let onUpdate: (BlurRegionData) -> Void
  let onRemove: () -> Void

  @State private var local: BlurRegionData
  @Environment(\.colorScheme) private var colorScheme

  private let labelWidth: CGFloat = 52
  private let valueWidth: CGFloat = 42

  init(
    region: BlurRegionData,
    onUpdate: @escaping (BlurRegionData) -> Void,
    onRemove: @escaping () -> Void
  ) {
    self.onUpdate = onUpdate
    self.onRemove = onRemove
    _local = State(initialValue: region)
  }

  var body: some View {
    let _ = colorScheme
    VStack(alignment: .leading, spacing: Layout.regionPopoverSpacing) {
      SectionHeader(icon: "drop.halffull", title: "Blur Region")

      VStack(alignment: .leading, spacing: Layout.itemSpacing) {
        slider("Left", value: $local.x, range: 0...0.99, percent: local.x)
        slider("Top", value: $local.y, range: 0...0.99, percent: local.y)
        slider("Width", value: $local.width, range: 0.01...max(0.01, 1 - local.x), percent: local.width)
        slider("Height", value: $local.height, range: 0.01...max(0.01, 1 - local.y), percent: local.height)
        SliderRow(
          label: "Blur",
          labelWidth: labelWidth,
          value: $local.radius,
          range: 0...100,
          step: 1,
          formattedValue: "\(Int(local.radius.rounded()))",
          valueWidth: valueWidth
        )
      }
      .padding(.horizontal, 12)

      Divider()
        .padding(.horizontal, 12)

      Button {
        onRemove()
      } label: {
        Label("Remove", systemImage: "trash")
      }
      .buttonStyle(OutlineButtonStyle(size: .medium, fullWidth: true))
      .padding(.horizontal, 12)
    }
    .padding(.vertical, 8)
    .frame(width: Layout.regionPopoverWidth)
    .popoverContainerStyle()
    .onChange(of: local) { _, value in
      let normalized = value.normalized()
      if normalized != local {
        local = normalized
      } else {
        onUpdate(normalized)
      }
    }
  }

  private func slider(
    _ label: String,
    value: Binding<CGFloat>,
    range: ClosedRange<CGFloat>,
    percent: CGFloat
  ) -> some View {
    SliderRow(
      label: label,
      labelWidth: labelWidth,
      value: value,
      range: range,
      step: 0.01,
      formattedValue: "\(Int((percent * 100).rounded()))%",
      valueWidth: valueWidth
    )
  }
}
