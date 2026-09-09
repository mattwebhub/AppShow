import SwiftUI

extension PropertiesPanel {
  var speedSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "speedometer", title: "Speed")
      Button {
        editorState.pause()
        let start = min(editorState.currentTime.seconds, max(0, editorState.duration.seconds - 0.05))
        speedEditorRegion = SpeedRegionData(startSeconds: start, endSeconds: min(editorState.duration.seconds, start + 5), rate: 2)
      } label: {
        Label("Add Speed Region", systemImage: "plus")
      }
      .buttonStyle(OutlineButtonStyle(size: .small, fullWidth: true))
      .disabled(editorState.isExporting)
      Text(
        "Speed up the screen and system audio. Webcam, microphone, and music stay at 1×. Drag the region edges; right-click to edit or remove."
      )
      .font(.system(size: FontSize.xs)).foregroundStyle(AppShowColors.secondaryText)
      ForEach(editorState.speedRegions) { region in
        Button {
          editorState.pause()
          speedEditorRegion = region
        } label: {
          HStack {
            Text("\(formatCompactTime(seconds: region.startSeconds))–\(formatCompactTime(seconds: region.endSeconds))")
            Spacer()
            Text(region.label)
          }
        }
        .buttonStyle(OutlineButtonStyle(size: .small, fullWidth: true))
        .disabled(editorState.isExporting)
      }
    }
    .sheet(item: $speedEditorRegion) { region in
      let existing = editorState.speedRegions.contains { $0.id == region.id }
      SpeedRegionEditor(
        region: region,
        duration: editorState.duration.seconds,
        onApply: { updated in
          if existing {
            try editorState.updateSpeedRegion(updated)
          } else {
            try editorState.addSpeedRegion(start: updated.startSeconds, end: updated.endSeconds, rate: updated.rate)
          }
        },
        onRemove: existing ? { editorState.removeSpeedRegion(id: region.id) } : nil
      )
    }
  }
}
