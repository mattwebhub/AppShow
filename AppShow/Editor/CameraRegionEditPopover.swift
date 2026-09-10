import SwiftUI

struct CameraRegionEditPopover: View {
  let region: CameraRegionData
  let onUpdateStart: (Double) -> Void
  let onUpdateEnd: (Double) -> Void
  let maxCameraRelativeWidth: CGFloat
  let onChangeType: (CameraRegionType) -> Void
  let onUpdateLayout: (CameraLayout) -> Void
  let onSetCorner: (CameraCorner) -> Void
  let onUpdateStyle:
    (
      CameraAspect?, CGFloat?, CGFloat?, CGFloat?, CodableColor?, Bool?
    ) -> Void
  let onUpdateTransition: (RegionTransitionType?, Double?, RegionTransitionType?, Double?) -> Void
  let onRemove: () -> Void

  @State var localLayout: CameraLayout = CameraLayout()
  @State var localAspect: CameraAspect = .original
  @State var localCornerRadius: CGFloat = 8
  @State var localShadow: CGFloat = 0
  @State var localBorderWidth: CGFloat = 0
  @State var localBorderColor: CodableColor = CodableColor(r: 0, g: 0, b: 0, a: 1)
  @State var localMirrored: Bool = false
  @State var localEntryTransition: RegionTransitionType = .none
  @State var localEntryDuration: Double = 0.3
  @State var localExitTransition: RegionTransitionType = .none
  @State var localExitDuration: Double = 0.3
  @State var didInit = false
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    VStack(alignment: .leading, spacing: Layout.regionPopoverSpacing) {
      SectionHeader(title: "Webcam section")
      TimeRangeControls(
        start: Binding(get: { region.startSeconds }, set: { onUpdateStart($0) }),
        end: Binding(get: { region.endSeconds }, set: { onUpdateEnd($0) })
      )
      .padding(.horizontal, 12)

      SelectButton(label: region.type.label) { dismiss in
        VStack(alignment: .leading, spacing: 0) {
          ForEach(CameraRegionType.allCases) { type in
            CheckmarkRow(title: type.label, isSelected: region.type == type) {
              onChangeType(type)
              dismiss()
            }
          }
        }
        .padding(.vertical, 8)
        .frame(width: 200)
      }
      .padding(.horizontal, 12)

      if region.type == .custom {
        Divider()
          .padding(.horizontal, 12)

        customControls
      }

      Divider()
        .padding(.horizontal, 12)

      transitionControls

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
      if !didInit {
        localLayout = region.customLayout ?? CameraLayout()
        localAspect = region.customCameraAspect ?? .original
        localCornerRadius = region.customCornerRadius ?? 8
        localShadow = region.customShadow ?? 0
        localBorderWidth = region.customBorderWidth ?? 0
        localBorderColor = region.customBorderColor ?? CodableColor(r: 0, g: 0, b: 0, a: 1)
        localMirrored = region.customMirrored ?? false
        localEntryTransition = region.entryTransition ?? .none
        localEntryDuration = region.entryTransitionDuration ?? 0.3
        localExitTransition = region.exitTransition ?? .none
        localExitDuration = region.exitTransitionDuration ?? 0.3
        didInit = true
      }
    }
    .onChange(of: region.customLayout) { _, newValue in
      if let newValue { localLayout = newValue }
    }
    .onChange(of: localLayout) { _, newValue in
      onUpdateLayout(newValue)
    }
    .onChange(of: localAspect) { _, newValue in
      onUpdateStyle(newValue, nil, nil, nil, nil, nil)
    }
    .onChange(of: localCornerRadius) { _, newValue in
      onUpdateStyle(nil, newValue, nil, nil, nil, nil)
    }
    .onChange(of: localShadow) { _, newValue in
      onUpdateStyle(nil, nil, newValue, nil, nil, nil)
    }
    .onChange(of: localBorderWidth) { _, newValue in
      onUpdateStyle(nil, nil, nil, newValue, nil, nil)
    }
    .onChange(of: localBorderColor) { _, newValue in
      onUpdateStyle(nil, nil, nil, nil, newValue, nil)
    }
    .onChange(of: localMirrored) { _, newValue in
      onUpdateStyle(nil, nil, nil, nil, nil, newValue)
    }
    .onChange(of: localEntryTransition) { _, newValue in
      onUpdateTransition(newValue, nil, nil, nil)
    }
    .onChange(of: localEntryDuration) { _, newValue in
      onUpdateTransition(nil, newValue, nil, nil)
    }
    .onChange(of: localExitTransition) { _, newValue in
      onUpdateTransition(nil, nil, newValue, nil)
    }
    .onChange(of: localExitDuration) { _, newValue in
      onUpdateTransition(nil, nil, nil, newValue)
    }
  }

}
