import SwiftUI

struct SpeedRegionEditor: View {
  let duration: Double
  let onApply: (SpeedRegionData) throws -> Void
  var onRemove: (() -> Void)?
  @State private var region: SpeedRegionData
  @State private var error: String?
  @Environment(\.dismiss) private var dismiss

  init(region: SpeedRegionData, duration: Double, onApply: @escaping (SpeedRegionData) throws -> Void, onRemove: (() -> Void)? = nil) {
    _region = State(initialValue: region)
    self.duration = duration
    self.onApply = onApply
    self.onRemove = onRemove
  }

  var body: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "speedometer", title: "Speed")
      TimeRangeControls(start: $region.startSeconds, end: $region.endSeconds)
      SegmentPicker(items: Array(SpeedPreset.allCases.prefix(3)), label: { $0.label }, selection: preset)
      SegmentPicker(items: Array(SpeedPreset.allCases.suffix(3)), label: { $0.label }, selection: preset)
      if region.isValid(duration: duration) {
        Text(
          "\(formatPreciseDuration(seconds: region.endSeconds - region.startSeconds)) → \(formatPreciseDuration(seconds: (region.endSeconds - region.startSeconds) / region.rate))"
        )
        .font(.system(size: FontSize.xs, design: .monospaced))
        .foregroundStyle(AppShowColors.secondaryText)
      }
      if let error {
        Text(error).font(.system(size: FontSize.xs)).foregroundStyle(AppShowColors.secondaryText)
      }
      HStack {
        if let onRemove {
          Button("Remove") {
            onRemove(); dismiss()
          }.buttonStyle(OutlineButtonStyle(size: .small))
        } else {
          Button("Cancel") { dismiss() }.buttonStyle(OutlineButtonStyle(size: .small))
        }
        Spacer()
        Button("Apply") {
          do { try onApply(region); dismiss() } catch { self.error = (error as? AgentToolError)?.message ?? error.localizedDescription }
        }
        .buttonStyle(PrimaryButtonStyle(size: .small))
        .disabled(!region.isValid(duration: duration))
      }
    }
    .padding(12)
    .frame(width: 310)
    .background(AppShowColors.backgroundPopover)
  }

  private var preset: Binding<SpeedPreset> {
    Binding(get: { SpeedPreset(rawValue: region.rate) ?? .two }, set: { region.rate = $0.rawValue })
  }
}
