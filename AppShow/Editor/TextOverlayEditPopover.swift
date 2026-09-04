import SwiftUI

struct TextOverlayEditPopover: View {
  let onUpdate: (TextOverlayData) -> Void
  let onRemove: () -> Void

  @State var local: TextOverlayData
  @Environment(\.colorScheme) private var colorScheme

  let labelWidth: CGFloat = 58
  let valueWidth: CGFloat = 40

  init(
    overlay: TextOverlayData,
    onUpdate: @escaping (TextOverlayData) -> Void,
    onRemove: @escaping () -> Void
  ) {
    self.onUpdate = onUpdate
    self.onRemove = onRemove
    _local = State(initialValue: overlay)
  }

  var body: some View {
    let _ = colorScheme
    ScrollView {
      VStack(alignment: .leading, spacing: Layout.regionPopoverSpacing) {
        SectionHeader(title: "Text Overlay")

        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
          textControls

          Divider()

          backgroundControls

          Divider()

          positionControls
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)

        Divider()
          .padding(.horizontal, 12)

        TransitionControlsSection(
          entryTransition: $local.entryTransition,
          entryDuration: $local.entryTransitionDuration,
          exitTransition: $local.exitTransition,
          exitDuration: $local.exitTransitionDuration
        )

        Button {
          onRemove()
        } label: {
          Label("Remove", systemImage: "trash")
        }
        .buttonStyle(OutlineButtonStyle(size: .medium, fullWidth: true))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
      }
      .padding(.vertical, 8)
    }
    .frame(width: Layout.regionPopoverWidth)
    .frame(maxHeight: 640)
    .popoverContainerStyle()
    .onChange(of: local) { _, newValue in
      onUpdate(newValue)
    }
  }

  private var textControls: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      TextField("Text", text: $local.text, axis: .vertical)
        .lineLimit(1...4)
        .font(.system(size: FontSize.xs))
        .foregroundStyle(AppShowColors.primaryText)
        .textFieldStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(AppShowColors.fieldBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(AppShowColors.border))

      SliderRow(
        label: "Size",
        labelWidth: labelWidth,
        value: $local.fontSize,
        range: 0.02...0.2,
        step: 0.005,
        formattedValue: "\(Int((local.fontSize * 100).rounded()))%",
        valueWidth: valueWidth
      )

      VStack(alignment: .leading, spacing: Layout.compactSpacing) {
        Text("Weight")
          .font(.system(size: FontSize.xs))
          .foregroundStyle(AppShowColors.secondaryText)
        SegmentPicker(
          items: CaptionFontWeight.allCases,
          label: { $0.label },
          selection: $local.fontWeight
        )
      }

      HStack(spacing: 8) {
        Text("Color")
          .font(.system(size: FontSize.xs))
          .foregroundStyle(AppShowColors.secondaryText)
          .frame(width: labelWidth, alignment: .leading)
        TailwindColorPicker(
          color: local.textColor,
          onSelect: { local.textColor = $0 }
        )
      }
    }
  }
}
