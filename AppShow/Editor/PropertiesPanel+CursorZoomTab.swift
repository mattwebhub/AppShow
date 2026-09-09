import SwiftUI

extension PropertiesPanel {
  var cursorStyleGrid: some View {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 4) {
      ForEach(CursorStyle.allCases, id: \.rawValue) { style in
        let isSelected = editorState.cursorStyle == style
        Button {
          editorState.cursorStyle = style
        } label: {
          VStack(spacing: 3) {
            Image(
              nsImage: CursorRenderer.previewImage(
                for: style,
                size: 42,
                fillColor: editorState.cursorFillColor,
                strokeColor: editorState.cursorStrokeColor
              )
            )
            .frame(width: 42, height: 42)
            .background(AppShowColors.muted)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .overlay(
              RoundedRectangle(cornerRadius: Radius.md)
                .stroke(isSelected ? AppShowColors.ring : Color.clear, lineWidth: 2)
            )
            Text(style.label)
              .font(.system(size: FontSize.xs, weight: isSelected ? .semibold : .regular))
              .foregroundStyle(isSelected ? AppShowColors.primaryText : AppShowColors.secondaryText)
              .lineLimit(1)
          }
        }
        .buttonStyle(PlainCustomButtonStyle())
      }
    }
  }

  var cursorSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "cursorarrow", title: "Cursor")

      ToggleRow(label: "Show Cursor", isOn: $editorState.showCursor)

      if editorState.showCursor {
        ToggleRow(label: "System Cursor", isOn: $editorState.useSystemCursor)

        if !editorState.useSystemCursor {
          cursorStyleGrid
        }

        SliderRow(
          label: "Size",
          labelWidth: Layout.labelWidth,
          value: $editorState.cursorSize,
          range: 16...128,
          step: 2,
          formattedValue: "\(Int(editorState.cursorSize))px",
          valueWidth: Layout.labelWidth
        )

        if !editorState.useSystemCursor {
          HStack(spacing: 8) {
            Text("Fill")
              .font(.system(size: FontSize.xs))
              .foregroundStyle(AppShowColors.secondaryText)
              .frame(width: Layout.labelWidth, alignment: .leading)
            cursorFillColorPicker
          }

          HStack(spacing: 8) {
            Text("Stroke")
              .font(.system(size: FontSize.xs))
              .foregroundStyle(AppShowColors.secondaryText)
              .frame(width: Layout.labelWidth, alignment: .leading)
            cursorStrokeColorPicker
          }
        }
      }
    }
  }

  var cursorFillColorPicker: some View {
    TailwindColorPicker(
      color: editorState.cursorFillColor,
      fallbackName: "White",
      onSelect: { editorState.cursorFillColor = $0 }
    )
  }

  var cursorStrokeColorPicker: some View {
    TailwindColorPicker(
      color: editorState.cursorStrokeColor,
      fallbackName: "Black",
      onSelect: { editorState.cursorStrokeColor = $0 }
    )
  }

  var clickHighlightsSubsection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "cursorarrow.click.2", title: "Click Highlights")

      ToggleRow(label: "Show Highlights", isOn: $editorState.showClickHighlights)

      if editorState.showClickHighlights {
        HStack(spacing: 8) {
          Text("Color")
            .font(.system(size: FontSize.xs))
            .foregroundStyle(AppShowColors.secondaryText)
            .frame(width: Layout.labelWidth, alignment: .leading)
          clickColorPickerButton
        }

        SliderRow(
          label: "Size",
          labelWidth: Layout.labelWidth,
          value: $editorState.clickHighlightSize,
          range: 16...80,
          step: 2,
          formattedValue: "\(Int(editorState.clickHighlightSize))px"
        )
      }
    }
  }

  var clickColorPickerButton: some View {
    TailwindColorPicker(
      color: editorState.clickHighlightColor,
      fallbackName: "Black",
      onSelect: { editorState.clickHighlightColor = $0 }
    )
  }

  var cursorEffectsSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "sparkles", title: "Cursor Effects")

      SliderRow(
        label: "Click Bounce",
        labelWidth: 82,
        value: $editorState.clickBounce,
        range: 0...10,
        step: 0.5,
        formattedValue: String(format: "%.1f", editorState.clickBounce),
        valueWidth: 36
      )

      SliderRow(
        label: "Sway",
        labelWidth: 82,
        value: $editorState.cursorSway,
        range: 0...2,
        step: 0.05,
        formattedValue: String(format: "%.2f", editorState.cursorSway),
        valueWidth: 36
      )

      SliderRow(
        label: "Motion Blur",
        labelWidth: 82,
        value: $editorState.cursorMotionBlur,
        range: 0...5,
        step: 0.1,
        formattedValue: String(format: "%.1f", editorState.cursorMotionBlur),
        valueWidth: 36
      )
    }
  }

}
