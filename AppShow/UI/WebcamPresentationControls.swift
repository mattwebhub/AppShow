import SwiftUI

struct WebcamPresentationControls: View {
  @Binding var presentation: WebcamPresentation

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      HStack {
        Text("Position")
          .font(.system(size: FontSize.xs))
          .foregroundStyle(AppShowColors.secondaryText)
        Spacer()
        SelectButton(label: presentation.corner.label) {
          VStack(alignment: .leading, spacing: 0) {
            ForEach(CameraCorner.allCases) { corner in
              CheckmarkRow(title: corner.label, isSelected: presentation.corner == corner) {
                presentation.corner = corner
              }
            }
          }
          .padding(.vertical, 8)
          .frame(width: 180)
        }
      }
      SliderRow(
        label: "Size",
        value: $presentation.relativeWidth,
        range: 0.1...0.5,
        step: 0.01,
        formattedValue: "\(Int(presentation.relativeWidth * 100))%"
      )
      Text("Circular webcam · size relative to the video width")
        .font(.system(size: FontSize.xxs))
        .foregroundStyle(AppShowColors.secondaryText)
    }
  }
}

struct WebcamRecordingControls: View {
  let session: SessionState

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      ToggleRow(label: "Include webcam", isOn: Binding(get: { session.isCameraOn }, set: { session.setWebcamIncluded($0) }))
        .disabled(session.options.availableCameras.isEmpty)
      if session.options.availableCameras.isEmpty {
        Text("Connect a camera to include your webcam.")
          .font(.system(size: FontSize.xs))
          .foregroundStyle(AppShowColors.secondaryText)
      } else {
        SelectButton(label: session.options.selectedCamera?.name ?? "Select webcam") {
          VStack(alignment: .leading, spacing: 0) {
            ForEach(session.options.availableCameras) { camera in
              CheckmarkRow(title: camera.name, isSelected: session.options.selectedCamera?.id == camera.id) {
                session.options.selectedCamera = camera
              }
            }
          }
          .padding(.vertical, 8)
          .frame(width: 260)
        }
      }
      WebcamVoiceControls(session: session)
      WebcamPresentationControls(
        presentation: Binding(get: { session.options.webcamPresentation }, set: { session.options.webcamPresentation = $0 })
      )
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
  }
}
