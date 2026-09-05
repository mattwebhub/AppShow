import SwiftUI

struct WebcamVoiceControls: View {
  let session: SessionState
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      ToggleRow(
        label: "Capture voice",
        isOn: Binding(
          get: { session.isCameraOn ? session.isMicrophoneOn : session.options.webcamVoice.captureVoice },
          set: { session.setWebcamVoiceEnabled($0) }
        )
      )
      if session.options.webcamVoice.captureVoice {
        SelectButton(label: session.options.selectedMicrophone?.name ?? "Select microphone") {
          VStack(alignment: .leading, spacing: 0) {
            ForEach(session.options.availableMicrophones) { mic in
              CheckmarkRow(title: mic.name, isSelected: session.options.selectedMicrophone == mic) {
                session.options.selectedMicrophone = mic
                session.setWebcamVoiceEnabled(true)
              }
            }
          }
          .padding(.vertical, 8)
          .frame(width: 260)
        }
        if session.options.availableMicrophones.isEmpty {
          Text("Connect a microphone to record your voice.")
            .font(.system(size: FontSize.xs))
            .foregroundStyle(AppShowColors.secondaryText)
        }
        ToggleRow(
          label: "Reduce background noise",
          isOn: Binding(
            get: { session.options.webcamVoice.cleanVoice },
            set: { session.options.webcamVoice.cleanVoice = $0 }
          )
        )
        ToggleRow(
          label: "Generate captions after recording",
          isOn: Binding(
            get: { session.options.webcamVoice.automaticCaptions },
            set: { session.options.webcamVoice.automaticCaptions = $0 }
          )
        )
        Text(
          "Voice is recorded separately and transcribed on this Mac for assistant context. Captions are optional. The Captions panel offers the required model download."
        )
        .font(.system(size: FontSize.xxs))
        .foregroundStyle(AppShowColors.secondaryText)
      }
    }
  }
}
