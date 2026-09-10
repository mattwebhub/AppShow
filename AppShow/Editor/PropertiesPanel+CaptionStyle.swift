import SwiftUI

extension PropertiesPanel {
  var styleSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "textformat", title: "Style")

      ToggleRow(label: "Enabled", isOn: $editorState.captionsEnabled)

      HStack(spacing: 8) {
        Text("Font")
          .font(.system(size: FontSize.xs))
          .foregroundStyle(AppShowColors.secondaryText)
          .frame(width: captionLabelWidth, alignment: .leading)
        FontFamilyPicker(selection: $editorState.captionFontFamily)
      }
      .disabled(!editorState.captionsEnabled)

      SliderRow(
        label: "Size",
        labelWidth: captionLabelWidth,
        value: $editorState.captionFontSize,
        range: 16...96,
        step: 2,
        formattedValue: "\(Int(editorState.captionFontSize))px",
        valueWidth: 40
      )
      .disabled(!editorState.captionsEnabled)

      VStack(alignment: .leading, spacing: Layout.compactSpacing) {
        Text("Weight")
          .font(.system(size: FontSize.xs))
          .foregroundStyle(AppShowColors.secondaryText)
        SegmentPicker(
          items: CaptionFontWeight.allCases,
          label: { $0.label },
          selection: $editorState.captionFontWeight
        )
      }
      .disabled(!editorState.captionsEnabled)

      VStack(alignment: .leading, spacing: Layout.compactSpacing) {
        Text("Position")
          .font(.system(size: FontSize.xs))
          .foregroundStyle(AppShowColors.secondaryText)
        HStack(spacing: 4) {
          ForEach(Array(CaptionPosition.presets.enumerated()), id: \.offset) { _, preset in
            Button(preset.label) {
              editorState.captionPosition = preset.position
            }
            .buttonStyle(OutlineButtonStyle(size: .small, fullWidth: true))
          }
        }
        Text("Drag captions in preview to reposition")
          .font(.system(size: FontSize.xxs))
          .foregroundStyle(AppShowColors.tertiaryText)
      }
      .disabled(!editorState.captionsEnabled)

      ToggleRow(label: "Background", isOn: $editorState.captionShowBackground)
        .disabled(!editorState.captionsEnabled)

      HStack(spacing: 8) {
        Text("Font color")
          .font(.system(size: FontSize.xs))
          .foregroundStyle(AppShowColors.secondaryText)
          .frame(width: captionLabelWidth, alignment: .leading)
        captionTextColorPicker
      }
      .disabled(!editorState.captionsEnabled)

      if editorState.captionShowBackground {
        HStack(spacing: 8) {
          Text("Background")
            .font(.system(size: FontSize.xs))
            .foregroundStyle(AppShowColors.secondaryText)
            .frame(width: captionLabelWidth, alignment: .leading)
          captionBgColorPicker
        }
        .disabled(!editorState.captionsEnabled)

        SliderRow(
          label: "Opacity",
          labelWidth: captionLabelWidth,
          value: $editorState.captionBackgroundOpacity,
          range: 0.1...1.0,
          step: 0.05,
          formattedValue: "\(Int(editorState.captionBackgroundOpacity * 100))%",
          valueWidth: 40
        )
        .disabled(!editorState.captionsEnabled)
      }

      SliderRow(
        label: "Words",
        labelWidth: captionLabelWidth,
        value: Binding(
          get: { CGFloat(editorState.captionMaxWordsPerLine) },
          set: { editorState.captionMaxWordsPerLine = Int($0) }
        ),
        range: 2...12,
        step: 1,
        formattedValue: "\(editorState.captionMaxWordsPerLine)",
        valueWidth: 40
      )
      .disabled(!editorState.captionsEnabled)
    }
  }

  private var captionTextColorPicker: some View {
    TailwindColorPicker(
      color: editorState.captionTextColor,
      onSelect: { editorState.captionTextColor = $0 }
    )
  }

  private var captionBgColorPicker: some View {
    TailwindColorPicker(
      color: editorState.captionBackgroundColor,
      onSelect: { editorState.captionBackgroundColor = $0 }
    )
  }

}
