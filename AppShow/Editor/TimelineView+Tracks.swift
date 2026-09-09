import SwiftUI

private struct ScaleHeight: ViewModifier {
  let scale: CGFloat
  func body(content: Content) -> some View {
    content.scaleEffect(x: 1.0, y: scale, anchor: .top)
  }
}

private extension AnyTransition {
  nonisolated(unsafe) static let trackTransition: AnyTransition = .opacity.combined(
    with: .modifier(
      active: ScaleHeight(scale: 0.01),
      identity: ScaleHeight(scale: 1.0)
    )
  )
}

extension TimelineView {
  var trackLabels: some View {
    VStack(spacing: 8) {
      Color.clear.frame(height: rulerHeight)
      VStack(spacing: 10) {
        trackSidebar(label: "Screen", icon: "display")
          .frame(height: trackHeight)

        if editorState.showCutTrack {
          trackSidebar(label: "Cuts", icon: "hand.point.up.left")
            .frame(height: trackHeight)
            .transition(.trackTransition)
        }

        if editorState.hasWebcam && editorState.webcamEnabled {
          trackSidebar(label: "Webcam", icon: "web.camera")
            .frame(height: trackHeight)
            .transition(.trackTransition)
        }

        if showSystemAudioTrack {
          trackSidebar(label: "System", icon: "speaker.wave.2")
            .frame(height: trackHeight)
            .transition(.trackTransition)
        }

        if showMicAudioTrack {
          trackSidebar(label: "Mic", icon: "mic")
            .contentShape(Rectangle())
            .contextMenu {
              Button("Remove Microphone", role: .destructive) { editorState.removeMicrophone() }
                .disabled(editorState.isExporting)
            }
            .frame(height: trackHeight)
            .transition(.trackTransition)
        }

        ForEach(editorState.externalAudioTracks) { _ in
          trackSidebar(label: "Audio", icon: "music.note")
            .frame(height: trackHeight)
            .transition(.trackTransition)
        }

        if editorState.zoomEnabled {
          trackSidebar(label: "Zoom", icon: "plus.magnifyingglass")
            .frame(height: trackHeight)
            .transition(.trackTransition)
        }

        if showSpotlightTrack {
          trackSidebar(label: "Spotlight", icon: "light.max")
            .frame(height: trackHeight)
            .transition(.trackTransition)
        }

        if editorState.showOverlayTrack {
          trackSidebar(label: "Overlays", icon: "square.on.square")
            .frame(height: trackHeight)
            .transition(.trackTransition)
        }
      }
    }
    .frame(width: sidebarWidth)
  }

  func trackContent(width: CGFloat, inset: CGFloat) -> some View {
    VStack(spacing: 8) {
      timeRuler(width: width)

      VStack(spacing: 10) {
        screenTrackContent(width: width)

        if editorState.showCutTrack {
          cutTrackContent(width: width)
            .transition(.trackTransition)
        }

        if editorState.hasWebcam && editorState.webcamEnabled {
          cameraTrackContent(width: width)
            .transition(.trackTransition)
        }

        if showSystemAudioTrack {
          Group {
            if !systemAudioSamples.isEmpty {
              audioTrackContent(
                trackType: .system,
                samples: systemAudioSamples,
                width: width
              )
            } else {
              audioLoadingContent(
                progress: systemAudioProgress ?? 0,
                width: width
              )
            }
          }
          .transition(.trackTransition)
        }

        if showMicAudioTrack {
          Group {
            if !micAudioSamples.isEmpty && !editorState.isMicProcessing {
              audioTrackContent(
                trackType: .mic,
                samples: micAudioSamples,
                width: width
              )
            } else {
              audioLoadingContent(
                progress: micAudioProgress ?? 0,
                message: micAudioMessage,
                width: width
              )
            }
          }
          .contextMenu {
            Button("Remove Microphone", role: .destructive) { editorState.removeMicrophone() }
              .disabled(editorState.isExporting)
          }
          .transition(.trackTransition)
        }

        ForEach(editorState.externalAudioTracks) { track in
          externalAudioTrackContent(track: track, width: width)
            .transition(.trackTransition)
        }

        if editorState.zoomEnabled {
          zoomTrackContent(width: width, keyframes: editorState.zoomTimeline?.allKeyframes ?? [])
            .transition(.trackTransition)
        }

        if showSpotlightTrack {
          spotlightTrackContent(width: width)
            .transition(.trackTransition)
        }

        if editorState.showOverlayTrack {
          overlayTrackContent(width: width)
            .transition(.trackTransition)
        }
      }
    }
    .padding(.horizontal, inset)
    .padding(.bottom, timelineZoom > 1 ? 10 : 0)
  }
}
