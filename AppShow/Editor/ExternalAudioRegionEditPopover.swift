import SwiftUI

struct ExternalAudioRegionEditPopover: View {
  let track: ExternalAudioTrackData
  let onSetMuted: (Bool) -> Void
  let onSetVolume: (Float) -> Void
  let onSetFadeIn: (Double) -> Void
  let onSetFadeOut: (Double) -> Void
  let onRemove: () -> Void

  @State private var localMuted = false
  @State private var localVolume: Float = 1
  @State private var localFadeIn: Double = 0
  @State private var localFadeOut: Double = 0
  @State private var didInit = false
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    VStack(alignment: .leading, spacing: Layout.regionPopoverSpacing) {
      SectionHeader(title: track.displayName)

      VStack(alignment: .leading, spacing: Layout.itemSpacing) {
        ToggleRow(label: "Mute", isOn: $localMuted)
          .onChange(of: localMuted) { _, newValue in
            onSetMuted(newValue)
          }

        SliderRow(
          label: "Volume",
          labelWidth: Layout.sliderLabelWidth,
          value: $localVolume,
          range: 0...2,
          step: 0.01,
          formattedValue: "\(Int((localVolume * 100).rounded()))%",
          valueWidth: 40
        )
        .onChange(of: localVolume) { _, newValue in
          onSetVolume(newValue)
        }
        .disabled(localMuted)

        SliderRow(
          label: "Fade In",
          labelWidth: Layout.sliderLabelWidth,
          value: $localFadeIn,
          range: 0...5,
          step: 0.1,
          formattedValue: fadeLabel(localFadeIn),
          valueWidth: 40
        )
        .onChange(of: localFadeIn) { _, newValue in
          onSetFadeIn(newValue)
        }

        SliderRow(
          label: "Fade Out",
          labelWidth: Layout.sliderLabelWidth,
          value: $localFadeOut,
          range: 0...5,
          step: 0.1,
          formattedValue: fadeLabel(localFadeOut),
          valueWidth: 40
        )
        .onChange(of: localFadeOut) { _, newValue in
          onSetFadeOut(newValue)
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 4)

      Button {
        onRemove()
      } label: {
        Label("Remove", systemImage: "trash")
      }
      .buttonStyle(OutlineButtonStyle(size: .medium, fullWidth: true))
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
    }
    .padding(.vertical, 8)
    .frame(width: Layout.regionPopoverWidth)
    .popoverContainerStyle()
    .onAppear {
      guard !didInit else { return }
      localMuted = track.muted
      localVolume = track.volume
      localFadeIn = track.fadeInSeconds
      localFadeOut = track.fadeOutSeconds
      didInit = true
    }
  }

  private func fadeLabel(_ seconds: Double) -> String {
    seconds == 0 ? "Off" : String(format: "%.1fs", seconds)
  }
}
