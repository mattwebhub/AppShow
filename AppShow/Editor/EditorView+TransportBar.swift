import CoreMedia
import SwiftUI

extension EditorView {
  var transportBar: some View {
    let isPreview = editorState.isPreviewMode

    return VStack(spacing: 0) {
      HStack {
        IconButton(
          systemName: editorState.isPlaying ? "pause.fill" : "play.fill",
          action: { editorState.togglePlayPause() }
        )

        Spacer()

        HStack(spacing: 4) {
          if isPreview && editorState.hasVideoRegionCuts {
            Text(formatPreciseDuration(seconds: editorState.previewElapsedTime))
              .font(.system(size: FontSize.xs, design: .monospaced))
              .foregroundStyle(AppShowColors.primaryText)
            Text("/ \(formatPreciseDuration(seconds: editorState.videoRegionsTotalDuration))")
              .font(.system(size: FontSize.xs, design: .monospaced))
              .foregroundStyle(AppShowColors.secondaryText)
          } else {
            Text(
              "\(formatPreciseDuration(editorState.currentTime)) / \(formatPreciseDuration(editorState.duration))"
            )
            .font(.system(size: FontSize.xs, design: .monospaced))
            .foregroundStyle(AppShowColors.primaryText)

            if editorState.hasVideoRegionCuts {
              Text("(\(formatPreciseDuration(seconds: editorState.videoRegionsTotalDuration)))")
                .font(.system(size: FontSize.xs, design: .monospaced))
                .foregroundStyle(AppShowColors.secondaryText)
            }
          }
        }

        Spacer()

        if !isPreview {
          let canCut = editorState.cutTimeline.canCut(at: CMTimeGetSeconds(editorState.currentTime))
          IconButton(
            systemName: "hand.point.up.left",
            color: canCut ? AppShowColors.primaryText : AppShowColors.disabledText
          ) {
            editorState.splitVideoRegion(atTime: CMTimeGetSeconds(editorState.currentTime))
          }
          .disabled(!canCut)
          .help("Split at playhead")

          if editorState.showCutTrack {
            IconButton(
              systemName: "trash",
              color: editorState.canDeleteSelectedVideoRegion ? AppShowColors.primaryText : AppShowColors.disabledText
            ) {
              editorState.deleteSelectedVideoRegion()
            }
            .disabled(!editorState.canDeleteSelectedVideoRegion)
            .help("Delete selected slice (Delete)")
          }

          if editorState.showCutTrack {
            IconButton(
              systemName: "arrow.left.and.right.square",
              color: timelineDisplayMode == .compressed ? AppShowColors.primaryText : AppShowColors.secondaryText
            ) {
              timelineDisplayMode = timelineDisplayMode == .compressed ? .source : .compressed
            }
            .help(timelineDisplayMode == .compressed ? "Show source timeline with removed gaps" : "Close gaps in the timeline")
          }

          IconButton(
            systemName: "minus.magnifyingglass",
            color: timelineZoom > 1.0 ? AppShowColors.primaryText : AppShowColors.disabledText
          ) {
            timelineZoom = max(1.0, timelineZoom / 1.5)
            baseZoom = timelineZoom
          }
          .disabled(timelineZoom <= 1.0)

          IconButton(
            systemName: "plus.magnifyingglass",
            color: timelineZoom < 30.0 ? AppShowColors.primaryText : AppShowColors.disabledText
          ) {
            timelineZoom = min(30.0, timelineZoom * 1.5)
            baseZoom = timelineZoom
          }
          .disabled(timelineZoom >= 30.0)

          IconButton(
            systemName: "1.magnifyingglass",
            color: timelineZoom > 1.0 ? AppShowColors.primaryText : AppShowColors.disabledText
          ) {
            timelineZoom = 1.0
            baseZoom = 1.0
          }
          .disabled(timelineZoom <= 1.0)

          IconButton(systemName: "clock.arrow.circlepath") {
            showHistoryPopover.toggle()
          }
          .popover(isPresented: $showHistoryPopover, arrowEdge: .top) {
            HistoryPopover(editorState: editorState)
              .presentationBackground(AppShowColors.backgroundPopover)
          }

          IconButton(
            systemName: "arrow.uturn.backward",
            color: editorState.history.canUndo ? AppShowColors.primaryText : AppShowColors.disabledText,
            action: { editorState.undo() }
          )
          .disabled(!editorState.history.canUndo)

          IconButton(
            systemName: "arrow.uturn.forward",
            color: editorState.history.canRedo ? AppShowColors.primaryText : AppShowColors.disabledText,
            action: { editorState.redo() }
          )
          .disabled(!editorState.history.canRedo)
        }

        IconButton(
          systemName: isPreview ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
          action: { editorState.isPreviewMode.toggle() }
        )
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)

      if isPreview {
        previewProgressBar
          .padding(.horizontal, 12)
          .padding(.bottom, 8)
      }
    }
    .background(AppShowColors.backgroundCard)
    .clipShape(RoundedRectangle(cornerRadius: Radius.xxl))
    .overlay(RoundedRectangle(cornerRadius: Radius.xxl).strokeBorder(AppShowColors.border, lineWidth: 1))
  }

}
