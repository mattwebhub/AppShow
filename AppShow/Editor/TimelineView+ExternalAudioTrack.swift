import SwiftUI

extension TimelineView {
  func externalAudioTrackContent(track: ExternalAudioTrackData, width: CGFloat) -> some View {
    let h = trackHeight
    return ZStack(alignment: .leading) {
      externalAudioRegionView(track: track, width: width, height: h)
    }
    .frame(width: width, height: h)
    .clipped()
    .coordinateSpace(name: "externalAudio-\(track.id.uuidString)")
    .contentShape(Rectangle())
  }

  @ViewBuilder
  func externalAudioRegionView(track: ExternalAudioTrackData, width: CGFloat, height: CGFloat) -> some View {
    let effective = effectiveExternalTrack(track, width: width)
    let startX = max(0, xPosition(forSource: effective.timelineStartSeconds, width: width))
    let endX = min(width, xPosition(forSource: effective.timelineEndSeconds, width: width))
    let regionWidth = max(4, endX - startX)
    let edgeThreshold = min(8.0, regionWidth * 0.2)
    let isPopoverShown = popoverExternalTrackId == track.id

    ZStack {
      RoundedRectangle(cornerRadius: Track.borderRadius)
        .fill(Track.background)

      externalAudioWaveform(
        track: effective,
        samples: externalAudioSamples[track.id] ?? [],
        startX: startX,
        regionWidth: regionWidth,
        fullWidth: width,
        height: height
      )

      if regionWidth > 50 {
        HStack(spacing: 3) {
          Image(systemName: "music.note")
            .font(.system(size: Track.fontSize))
          Text(track.displayName)
            .font(.system(size: Track.fontSize, weight: Track.fontWeight))
            .lineLimit(1)
            .truncationMode(.middle)
        }
        .foregroundStyle(Track.regionTextColor)
        .padding(.horizontal, Layout.compactSpacing)
        .frame(width: regionWidth, alignment: .leading)
      }

      RoundedRectangle(cornerRadius: Track.borderRadius)
        .strokeBorder(Track.borderColor, lineWidth: Track.borderWidth)

      RegionCutMarkers(
        geometry: geometry(width: width),
        start: effective.timelineStartSeconds,
        end: effective.timelineEndSeconds,
        originX: startX,
        height: height
      )
    }
    .frame(width: regionWidth, height: height)
    .clipShape(RoundedRectangle(cornerRadius: Track.borderRadius))
    .contentShape(Rectangle())
    .opacity(track.muted ? 0.5 : 1)
    .overlay {
      if isTrackEditable {
        RightClickOverlay {
          popoverExternalTrackId = track.id
        }
      }
    }
    .popover(
      isPresented: Binding(
        get: { isPopoverShown },
        set: { if !$0 { popoverExternalTrackId = nil } }
      ),
      arrowEdge: .top
    ) {
      ExternalAudioRegionEditPopover(
        track: track,
        onSetMuted: { editorState.setExternalAudioTrackMuted(id: track.id, muted: $0) },
        onSetVolume: { editorState.setExternalAudioTrackVolume(id: track.id, volume: $0) },
        onSetFadeIn: { editorState.setExternalAudioTrackFadeIn(id: track.id, seconds: $0) },
        onSetFadeOut: { editorState.setExternalAudioTrackFadeOut(id: track.id, seconds: $0) },
        onRemove: {
          popoverExternalTrackId = nil
          editorState.removeExternalAudioTrack(id: track.id)
        }
      )
      .presentationBackground(AppShowColors.backgroundPopover)
    }
    .gesture(
      DragGesture(minimumDistance: 3, coordinateSpace: .named("externalAudio-\(track.id.uuidString)"))
        .onChanged { value in
          guard isTrackEditable else { return }
          if externalDragType == nil {
            let origStartX = xPosition(forSource: track.timelineStartSeconds, width: width)
            let origEndX = xPosition(forSource: track.timelineEndSeconds, width: width)
            let origWidth = origEndX - origStartX
            let relX = value.startLocation.x - origStartX
            let effectiveEdge = min(8.0, origWidth * 0.2)
            if relX <= effectiveEdge {
              externalDragType = .resizeLeft
            } else if relX >= origWidth - effectiveEdge {
              externalDragType = .resizeRight
            } else {
              externalDragType = .move
            }
            externalDragTrackId = track.id
          }
          externalDragOffset = value.translation.width
        }
        .onEnded { _ in
          guard externalDragType != nil else { return }
          commitExternalDrag(track: track, width: width)
          externalDragOffset = 0
          externalDragType = nil
          externalDragTrackId = nil
        }
    )
    .onContinuousHover { phase in
      switch phase {
      case .active(let location):
        if !isTrackEditable {
          NSCursor.arrow.set()
        } else if location.x <= edgeThreshold || location.x >= regionWidth - edgeThreshold {
          NSCursor.resizeLeftRight.set()
        } else {
          NSCursor.openHand.set()
        }
      case .ended:
        NSCursor.arrow.set()
      @unknown default:
        break
      }
    }
    .position(x: startX + regionWidth / 2, y: height / 2)
  }

  func externalAudioWaveform(
    track: ExternalAudioTrackData,
    samples: [Float],
    startX: CGFloat,
    regionWidth: CGFloat,
    fullWidth: CGFloat,
    height: CGFloat
  ) -> some View {
    let window = ExternalAudioWaveformWindow.slice(
      samples: samples,
      fileIn: track.fileInSeconds,
      fileOut: track.fileOutSeconds,
      sourceDuration: track.sourceDurationSeconds
    )
    let points = externalWaveformPoints(
      samples: window,
      start: track.timelineStartSeconds,
      end: track.timelineEndSeconds,
      startX: startX,
      fullWidth: fullWidth,
      height: height
    )
    return Canvas { context, size in
      guard points.top.count > 1 else { return }
      let path = buildWaveformPath(top: points.top, bottom: points.bottom, minX: 0, maxX: size.width)
      context.fill(path, with: .color(AppShowColors.primaryText.opacity(0.9)))
    }
    .frame(width: regionWidth, height: height)
    .allowsHitTesting(false)
  }

  private func externalWaveformPoints(
    samples: [Float],
    start: Double,
    end: Double,
    startX: CGFloat,
    fullWidth: CGFloat,
    height: CGFloat
  ) -> (top: [CGPoint], bottom: [CGPoint]) {
    let count = samples.count
    guard count > 1, end > start else { return ([], []) }
    let midY = height / 2
    let maxAmp = height * 0.4
    let sourceStep = (end - start) / Double(count - 1)
    let g = geometry(width: fullWidth)
    var top: [CGPoint] = []
    var bottom: [CGPoint] = []
    for i in 0..<count {
      let time = start + Double(i) * sourceStep
      if g.mode == .compressed, g.timeline.slice(containing: time) == nil { continue }
      let x = g.x(forSource: time) - startX
      let amp = CGFloat(samples[i]) * maxAmp
      top.append(CGPoint(x: x, y: midY - amp))
      bottom.append(CGPoint(x: x, y: midY + amp))
    }
    return (top, bottom)
  }

  func effectiveExternalTrack(_ track: ExternalAudioTrackData, width: CGFloat) -> ExternalAudioTrackData {
    guard externalDragTrackId == track.id, let dt = externalDragType else { return track }
    let timeDelta = (externalDragOffset / width) * visibleSeconds
    switch dt {
    case .move:
      return ExternalAudioTrackMath.move(track, to: track.timelineStartSeconds + timeDelta, recordingDuration: totalSeconds)
    case .resizeLeft:
      return ExternalAudioTrackMath.trimStart(track, to: track.timelineStartSeconds + timeDelta)
    case .resizeRight:
      return ExternalAudioTrackMath.trimEnd(track, to: track.timelineEndSeconds + timeDelta, recordingDuration: totalSeconds)
    }
  }

  func commitExternalDrag(track: ExternalAudioTrackData, width: CGFloat) {
    let timeDelta = (externalDragOffset / width) * visibleSeconds
    switch externalDragType {
    case .move:
      editorState.moveExternalAudioTrack(id: track.id, newStart: track.timelineStartSeconds + timeDelta)
    case .resizeLeft:
      editorState.trimExternalAudioTrackStart(id: track.id, newStart: track.timelineStartSeconds + timeDelta)
    case .resizeRight:
      editorState.trimExternalAudioTrackEnd(id: track.id, newEnd: track.timelineEndSeconds + timeDelta)
    case nil:
      break
    }
  }
}
