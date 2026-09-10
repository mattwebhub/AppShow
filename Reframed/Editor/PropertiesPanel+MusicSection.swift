import SwiftUI

extension PropertiesPanel {
  var musicSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "music.note", title: "Music")

      ForEach(editorState.externalAudioTracks) { track in
        musicTrackRow(track)
      }

      Button {
        pickExternalAudioFiles()
      } label: {
        Label("Add Audio File…", systemImage: "plus")
      }
      .buttonStyle(OutlineButtonStyle(size: .medium, fullWidth: true))
    }
  }

  private func musicTrackRow(_ track: ExternalAudioTrackData) -> some View {
    VStack(alignment: .leading, spacing: Layout.compactSpacing) {
      HStack(spacing: Layout.compactSpacing) {
        Image(systemName: "music.note")
          .font(.system(size: FontSize.xs))
          .foregroundStyle(ReframedColors.secondaryText)
        Text(track.displayName)
          .font(.system(size: FontSize.xs, weight: .semibold))
          .foregroundStyle(ReframedColors.primaryText)
          .lineLimit(1)
          .truncationMode(.middle)
        Spacer()
        IconButton(systemName: "trash") {
          editorState.removeExternalAudioTrack(id: track.id)
        }
      }

      ToggleRow(
        label: "Mute",
        isOn: Binding(
          get: { currentTrack(track).muted },
          set: { editorState.setExternalAudioTrackMuted(id: track.id, muted: $0) }
        )
      )

      SliderRow(
        label: "Volume",
        labelWidth: Layout.sliderLabelWidth,
        value: Binding(
          get: { currentTrack(track).volume },
          set: { editorState.setExternalAudioTrackVolume(id: track.id, volume: $0) }
        ),
        range: 0...2,
        step: 0.01,
        formattedValue: "\(Int((currentTrack(track).volume * 100).rounded()))%",
        valueWidth: 40
      )
      .disabled(track.muted)

      SliderRow(
        label: "Fade In",
        labelWidth: Layout.sliderLabelWidth,
        value: Binding(
          get: { currentTrack(track).fadeInSeconds },
          set: { editorState.setExternalAudioTrackFadeIn(id: track.id, seconds: $0) }
        ),
        range: 0...5,
        step: 0.1,
        formattedValue: fadeLabel(currentTrack(track).fadeInSeconds),
        valueWidth: 40
      )

      SliderRow(
        label: "Fade Out",
        labelWidth: Layout.sliderLabelWidth,
        value: Binding(
          get: { currentTrack(track).fadeOutSeconds },
          set: { editorState.setExternalAudioTrackFadeOut(id: track.id, seconds: $0) }
        ),
        range: 0...5,
        step: 0.1,
        formattedValue: fadeLabel(currentTrack(track).fadeOutSeconds),
        valueWidth: 40
      )
    }
  }

  private func currentTrack(_ track: ExternalAudioTrackData) -> ExternalAudioTrackData {
    editorState.externalAudioTracks.first { $0.id == track.id } ?? track
  }

  private func fadeLabel(_ seconds: Double) -> String {
    seconds == 0 ? "Off" : String(format: "%.1fs", seconds)
  }

  func pickExternalAudioFiles() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = ExternalAudioImporter.contentTypes
    panel.allowsMultipleSelection = true
    panel.canChooseDirectories = false
    panel.begin { response in
      guard response == .OK else { return }
      let urls = panel.urls
      DispatchQueue.main.async {
        self.editorState.importExternalAudioFiles(urls)
      }
    }
  }
}
