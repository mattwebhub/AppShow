import SwiftUI

struct TimeRangeControls: View {
  @Binding var start: Double
  @Binding var end: Double

  var body: some View {
    HStack(spacing: 12) {
      field("Start", value: $start)
      field("End", value: $end)
    }
  }

  private func field(_ label: String, value: Binding<Double>) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("\(label) (s)")
        .font(.system(size: FontSize.xs))
        .foregroundStyle(AppShowColors.secondaryText)
      TextField(label, value: value, format: .number.precision(.fractionLength(0...3)))
        .textFieldStyle(.plain)
        .font(.system(size: FontSize.xs, design: .monospaced))
        .foregroundStyle(AppShowColors.primaryText)
        .padding(8)
        .background(AppShowColors.fieldBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
        .overlay(RoundedRectangle(cornerRadius: Radius.sm).strokeBorder(AppShowColors.border))
        .accessibilityLabel("\(label) in source seconds")
    }
  }
}
