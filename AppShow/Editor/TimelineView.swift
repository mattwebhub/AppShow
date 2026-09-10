import AVFoundation
import SwiftUI

struct TimelineView: View {
  @Bindable var editorState: EditorState
  let systemAudioSamples: [Float]
  let micAudioSamples: [Float]
  var externalAudioSamples: [UUID: [Float]] = [:]
  var systemAudioProgress: Double?
  var micAudioProgress: Double?
  var micAudioMessage: String?
  let onScrub: (CMTime) -> Void
  @Binding var timelineZoom: CGFloat
  @Binding var baseZoom: CGFloat
  @Binding var displayMode: TimelineDisplayMode
  @Environment(\.colorScheme) private var colorScheme

  let sidebarWidth: CGFloat = 70
  let rulerHeight: CGFloat = Layout.rulerHeight
  private let playheadInset: CGFloat = 7
  let trackHeight: CGFloat = Track.height

  @State var scrollOffset: CGFloat = 0
  @State private var scrollPosition = ScrollPosition(edge: .leading)

  var totalSeconds: Double {
    max(CMTimeGetSeconds(editorState.duration), 0.001)
  }

  private var playheadFraction: Double {
    CMTimeGetSeconds(editorState.currentTime) / totalSeconds
  }

  private var videoTrimStart: Double {
    CMTimeGetSeconds(editorState.trimStart) / totalSeconds
  }

  private var videoTrimEnd: Double {
    CMTimeGetSeconds(editorState.trimEnd) / totalSeconds
  }

  @State var audioDragOffset: CGFloat = 0
  @State var audioDragType: RegionDragType?
  @State var audioDragRegionId: UUID?

  @State var cameraDragOffset: CGFloat = 0
  @State var cameraDragAnchorTime: Double = 0
  @State var cameraDragType: RegionDragType?
  @State var cameraDragRegionId: UUID?
  @State var popoverCameraRegionId: UUID?

  @State var videoDragOriginalTimeline: CutTimeline?
  @State var videoDragSecondsPerPoint: Double = 0
  @State var videoDragOffset: CGFloat = 0
  @State var videoDragType: RegionDragType?
  @State var videoDragRegionId: UUID?
  @State var popoverVideoRegionId: UUID?

  @State var spotlightDragOffset: CGFloat = 0
  @State var spotlightDragType: RegionDragType?
  @State var spotlightDragRegionId: UUID?
  @State var popoverSpotlightRegionId: UUID?

  @State var externalDragOffset: CGFloat = 0
  @State var externalDragType: RegionDragType?
  @State var externalDragTrackId: UUID?
  @State var popoverExternalTrackId: UUID?
  @State var overlayDragOffset: CGFloat = 0
  @State var overlayDragType: RegionDragType?
  @State var overlayDragRegionId: UUID?
  @State var popoverOverlayId: UUID?

  var showSystemAudioTrack: Bool {
    !editorState.systemAudioMuted
      && (!systemAudioSamples.isEmpty || editorState.hasSystemAudio)
  }

  var showMicAudioTrack: Bool {
    !editorState.micAudioMuted
      && ((!micAudioSamples.isEmpty && !editorState.isMicProcessing) || editorState.hasMicAudio)
  }

  var showSpotlightTrack: Bool {
    editorState.spotlightEnabled && editorState.cursorMetadataProvider != nil
  }

  private var visibleTrackCount: Int {
    var count = 1
    if editorState.showCutTrack { count += 1 }
    if editorState.hasWebcam && editorState.webcamEnabled { count += 1 }
    if showSystemAudioTrack { count += 1 }
    if showMicAudioTrack { count += 1 }
    count += editorState.externalAudioTracks.count
    if !editorState.speedRegions.isEmpty { count += 1 }
    if editorState.zoomEnabled { count += 1 }
    if showSpotlightTrack { count += 1 }
    if editorState.showOverlayTrack { count += 1 }
    return count
  }

  var timelineHeight: CGFloat {
    let n = CGFloat(visibleTrackCount)
    return rulerHeight + 8 + n * trackHeight + max(0, n - 1) * 10
  }

  var body: some View {
    let _ = colorScheme
    HStack(spacing: 0) {
      trackLabels

      GeometryReader { geo in
        let availableWidth = geo.size.width - playheadInset * 2
        let cw = availableWidth * timelineZoom
        let frameWidth = cw + playheadInset * 2

        ScrollView(.horizontal, showsIndicators: false) {
          ZStack(alignment: .top) {
            trackContent(width: cw, inset: playheadInset)

            agentChangeOverlay(contentWidth: cw, inset: playheadInset)
            playheadOverlay(contentWidth: cw, inset: playheadInset)
          }
          .frame(width: frameWidth)
        }
        .scrollPosition($scrollPosition)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
          geometry.contentOffset.x
        } action: { _, newValue in
          scrollOffset = newValue
        }
        .scrollIndicators(timelineZoom > 1 ? .visible : .hidden)
        .overlay {
          CmdScrollZoomOverlay { delta, cursorX in
            let oldZoom = timelineZoom
            let factor = 1.0 + delta * 0.03
            let newZoom = max(1.0, min(30.0, oldZoom * factor))
            guard newZoom != oldZoom else { return }

            let oldCw = availableWidth * oldZoom
            let cursorInContent = scrollOffset + cursorX
            let trackFraction = (cursorInContent - playheadInset) / oldCw

            let newCw = availableWidth * newZoom
            let newCursorInContent = playheadInset + trackFraction * newCw
            let newOffset = max(0, newCursorInContent - cursorX)

            timelineZoom = newZoom
            baseZoom = newZoom
            scrollPosition.scrollTo(point: CGPoint(x: newOffset, y: 0))
          }
        }
        .gesture(
          MagnifyGesture()
            .onChanged { value in
              timelineZoom = max(1.0, min(30.0, baseZoom * value.magnification))
            }
            .onEnded { _ in
              baseZoom = timelineZoom
            }
        )
      }
      .padding(.trailing, 8)
    }
    .frame(height: timelineHeight)
    .animation(.easeInOut(duration: 0.2), value: visibleTrackCount)
    .fileDrop(of: ExternalAudioImporter.contentTypes) { urls in
      editorState.importExternalAudioFiles(urls)
    }
    .background(AppShowColors.backgroundCard)
    .padding(.vertical, 8)
    .onChange(of: editorState.videoRegions.count) { oldCount, newCount in
      if newCount < oldCount { displayMode = .compressed }
    }
  }

}
