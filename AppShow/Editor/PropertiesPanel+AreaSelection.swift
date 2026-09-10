import SwiftUI

extension PropertiesPanel {
  var areaPicker: some View {
    SourceAreaPicker(
      title: selectingBlurArea ? "Blur Area" : "Zoom Area",
      videoURL: editorState.result.screenVideoURL,
      at: editorState.currentTime.seconds,
      duration: editorState.duration.seconds
    ) { rect, start, end in
      guard !editorState.isExporting else { throw AgentToolError.invalidArguments("Wait for the export to finish.") }
      editorState.pendingUndoTask?.cancel()
      editorState.history.pushSnapshot(editorState.createSnapshot())
      if selectingBlurArea {
        try editorState.addTimedBlur(rect: rect, start: start, end: end)
      } else {
        try editorState.addAreaZoom(rect: rect, start: start, end: end)
      }
      editorState.pendingUndoTask?.cancel()
      editorState.history.pushSnapshot(editorState.createSnapshot(), label: selectingBlurArea ? "Blur area added" : "Zoom area added")
      editorState.scheduleSave()
    }
  }
}
