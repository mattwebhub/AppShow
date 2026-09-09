import SwiftUI

extension PropertiesPanel {
  var zoomSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "plus.magnifyingglass", title: "Zoom")

      Button {
        editorState.pause()
        selectingBlurArea = false
        showingAreaPicker = true
      } label: {
        Label("Select Zoom Area…", systemImage: "viewfinder")
      }
      .buttonStyle(OutlineButtonStyle(size: .small, fullWidth: true))
      .disabled(editorState.isExporting)

      Text("Area zoom stays on your selection. Cursor-following zooms can be used elsewhere in the recording.")
        .font(.system(size: FontSize.xs))
        .foregroundStyle(AppShowColors.secondaryText)

      ToggleRow(label: "Enable Zoom", isOn: $editorState.zoomEnabled)
        .onChange(of: editorState.zoomEnabled) { _, enabled in
          if !enabled {
            editorState.autoZoomEnabled = false
            editorState.zoomTimeline = nil
          }
        }

      if editorState.zoomEnabled {
        ToggleRow(label: "Follow Cursor", isOn: $editorState.zoomFollowCursor)

        ToggleRow(label: "Auto Zoom", isOn: $editorState.autoZoomEnabled)
          .onChange(of: editorState.autoZoomEnabled) { _, enabled in
            if enabled {
              editorState.generateAutoZoom()
            } else {
              editorState.clearAutoZoom()
            }
          }

        if editorState.autoZoomEnabled {
          SliderRow(
            label: "Level",
            labelWidth: Layout.labelWidth,
            value: $editorState.zoomLevel,
            range: 1.5...5.0,
            step: 0.1,
            formattedValue: String(format: "%.1fx", editorState.zoomLevel),
            valueWidth: 40
          )
          .onChange(of: editorState.zoomLevel) { _, _ in
            editorState.generateAutoZoom()
          }

          SliderRow(
            label: "Speed",
            labelWidth: Layout.labelWidth,
            value: $editorState.zoomTransitionSpeed,
            range: 0.1...4.0,
            step: 0.05,
            formattedValue: String(format: "%.2fs", editorState.zoomTransitionSpeed),
            valueWidth: 40
          )
          .onChange(of: editorState.zoomTransitionSpeed) { _, _ in
            editorState.generateAutoZoom()
          }

          SliderRow(
            label: "Hold",
            labelWidth: Layout.labelWidth,
            value: $editorState.zoomDwellThreshold,
            range: 0.5...10.0,
            step: 0.1,
            formattedValue: String(format: "%.1fs", editorState.zoomDwellThreshold),
            valueWidth: 40
          )
          .onChange(of: editorState.zoomDwellThreshold) { _, _ in
            editorState.generateAutoZoom()
          }
        }
      }
    }
  }
}
