import SwiftUI

struct OptionsPopover: View {
  @Bindable var options: RecordingOptions
  let session: SessionState
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        SectionHeader(title: "Timer")

        ForEach(TimerDelay.allCases, id: \.self) { delay in
          CheckmarkRow(
            title: delay.label,
            isSelected: options.timerDelay == delay
          ) {
            options.timerDelay = delay
          }
        }

        Divider()
          .background(AppShowColors.divider)
          .padding(.vertical, 4)

        SectionHeader(title: "Audio")

        CheckmarkRow(
          title: "Capture System Audio",
          isSelected: options.captureSystemAudio
        ) {
          options.captureSystemAudio.toggle()
        }

        Divider()
          .background(AppShowColors.divider)
          .padding(.vertical, 4)

        SectionHeader(title: "Microphone")

        CheckmarkRow(
          title: "None",
          isSelected: options.selectedMicrophone == nil
        ) {
          options.selectedMicrophone = nil
        }

        ForEach(options.availableMicrophones) { mic in
          CheckmarkRow(
            title: mic.name,
            isSelected: options.selectedMicrophone?.id == mic.id
          ) {
            options.selectedMicrophone = mic
          }
        }

        Divider()
          .background(AppShowColors.divider)
          .padding(.vertical, 4)

        SectionHeader(title: "Webcam")
        WebcamRecordingControls(session: session)

        Divider()
          .background(AppShowColors.divider)
          .padding(.vertical, 4)

        SectionHeader(title: "Options")

        CheckmarkRow(
          title: "Remember Last Selection",
          isSelected: options.rememberLastSelection
        ) {
          options.rememberLastSelection.toggle()
        }

        CheckmarkRow(
          title: "Dim Outer Area While Recording",
          isSelected: options.dimOuterArea
        ) {
          options.dimOuterArea.toggle()
        }

        CheckmarkRow(
          title: "Hide Camera Preview While Recording",
          isSelected: options.hideCameraPreviewWhileRecording
        ) {
          options.hideCameraPreviewWhileRecording.toggle()
        }

        CheckmarkRow(
          title: "Show Recording Preview",
          isSelected: options.showRecordingPreview
        ) {
          options.showRecordingPreview.toggle()
        }

        CheckmarkRow(
          title: "Retina Capture (Supersample)",
          isSelected: options.retinaCapture
        ) {
          options.retinaCapture.toggle()
        }

        CheckmarkRow(
          title: "HDR Capture",
          isSelected: options.hdrCapture
        ) {
          options.hdrCapture.toggle()
        }
      }
      .padding(.vertical, 8)
    }
    .frame(width: 320)
    .frame(maxHeight: 720)
    .popoverContainerStyle()
  }
}
