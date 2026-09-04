import SwiftUI

struct ImageOverlayEditPopover: View {
  let imageURL: URL?
  let onUpdate: (ImageOverlayData) -> Void
  let onRemove: () -> Void

  @State private var local: ImageOverlayData
  @Environment(\.colorScheme) private var colorScheme

  private let labelWidth: CGFloat = 58
  private let valueWidth: CGFloat = 40

  init(
    overlay: ImageOverlayData,
    imageURL: URL?,
    onUpdate: @escaping (ImageOverlayData) -> Void,
    onRemove: @escaping () -> Void
  ) {
    self.imageURL = imageURL
    self.onUpdate = onUpdate
    self.onRemove = onRemove
    _local = State(initialValue: overlay)
  }

  var body: some View {
    let _ = colorScheme
    ScrollView {
      VStack(alignment: .leading, spacing: Layout.regionPopoverSpacing) {
        SectionHeader(title: "Image Overlay")

        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
          imageSummary

          Divider()

          appearanceControls

          Divider()

          OverlayPositionControls(
            position: $local.position,
            offsetX: $local.offsetX,
            offsetY: $local.offsetY,
            labelWidth: labelWidth,
            valueWidth: valueWidth
          )
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

  private var imageSummary: some View {
    VStack(alignment: .leading, spacing: Layout.compactSpacing) {
      if let imageURL, let image = NSImage(contentsOf: imageURL) {
        Image(nsImage: image)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(maxWidth: .infinity, maxHeight: 96)
          .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
      }

      Label(local.displayName, systemImage: "photo")
        .font(.system(size: FontSize.xs))
        .foregroundStyle(ReframedColors.primaryText)
        .lineLimit(1)
        .truncationMode(.middle)
    }
  }

  private var appearanceControls: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "slider.horizontal.3", title: "Appearance")

      SliderRow(
        label: "Width",
        labelWidth: labelWidth,
        value: $local.width,
        range: 0.05...1,
        step: 0.01,
        formattedValue: "\(Int((local.width * 100).rounded()))%",
        valueWidth: valueWidth
      )

      SliderRow(
        label: "Corners",
        labelWidth: labelWidth,
        value: $local.cornerRadius,
        range: 0...0.5,
        step: 0.01,
        formattedValue: "\(Int((local.cornerRadius * 200).rounded()))%",
        valueWidth: valueWidth
      )

      SliderRow(
        label: "Opacity",
        labelWidth: labelWidth,
        value: $local.opacity,
        range: 0...1,
        step: 0.05,
        formattedValue: "\(Int((local.opacity * 100).rounded()))%",
        valueWidth: valueWidth
      )

      SliderRow(
        label: "Shadow",
        labelWidth: labelWidth,
        value: $local.shadow,
        range: 0...100,
        step: 1,
        formattedValue: "\(Int(local.shadow.rounded()))",
        valueWidth: valueWidth
      )
    }
  }
}
