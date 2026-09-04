import SwiftUI

extension PropertiesPanel {
  var silencesSection: some View {
    SilenceRemovalSection(editorState: editorState)
  }
}

struct SilenceRemovalSection: View {
  let editorState: EditorState

  @State private var source: SilenceSource = .microphone
  @State private var thresholdDb: Double = SilenceDetectorConfig().thresholdDb
  @State private var minimumSilence: Double = SilenceDetectorConfig().minimumSilence
  @State private var padding: Double = SilenceDetectorConfig().padding
  @State private var preview: SilenceRemovalPreview?
  @State private var analysisTask: Task<Void, Never>?
  @Environment(\.colorScheme) private var colorScheme

  private var sources: [SilenceSource] { editorState.availableSilenceSources }
  private var hasAudio: Bool { !sources.isEmpty }
  private var isAnalyzing: Bool { analysisTask != nil }

  private var config: SilenceDetectorConfig {
    SilenceDetectorConfig(thresholdDb: thresholdDb, minimumSilence: minimumSilence, padding: padding)
  }

  private var statusText: String {
    guard hasAudio else { return "No audio to analyze" }
    if isAnalyzing { return "Analyzing…" }
    guard let preview else { return "Preview to find silences" }
    if preview.errorDescription != nil { return "Analysis failed" }
    if preview.count == 0 { return "No silences found" }
    let noun = preview.count == 1 ? "silence" : "silences"
    return "\(preview.count) \(noun), \(formatCompactTime(seconds: preview.totalRemoved)) removed"
  }

  var body: some View {
    let _ = colorScheme
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "waveform.badge.minus", title: "Silences")

      if sources.count > 1 {
        SegmentPicker(items: sources, label: { $0.label }, selection: $source)
      }

      SliderRow(
        label: "Threshold",
        labelWidth: 82,
        value: $thresholdDb,
        range: -60...(-20),
        step: 1,
        formattedValue: "\(Int(thresholdDb)) dB",
        valueWidth: 48
      )

      SliderRow(
        label: "Min length",
        labelWidth: 82,
        value: $minimumSilence,
        range: 0.2...3,
        step: 0.1,
        formattedValue: String(format: "%.1fs", minimumSilence),
        valueWidth: 48
      )

      SliderRow(
        label: "Padding",
        labelWidth: 82,
        value: $padding,
        range: 0...0.5,
        step: 0.05,
        formattedValue: String(format: "%.2fs", padding),
        valueWidth: 48
      )

      HStack(spacing: 8) {
        Text(statusText)
          .font(.system(size: FontSize.xs))
          .foregroundStyle(AppShowColors.secondaryText)
          .lineLimit(1)
        Spacer()
        Button("Preview") {
          runPreview()
        }
        .buttonStyle(OutlineButtonStyle(size: .small))
        .disabled(isAnalyzing)
        Button("Apply") {
          apply()
        }
        .buttonStyle(PrimaryButtonStyle(size: .small))
        .disabled(!(preview?.canApply ?? false))
      }
    }
    .disabled(!hasAudio)
    .opacity(hasAudio ? 1 : 0.4)
    .onChange(of: source) { _, _ in clearPreview() }
    .onChange(of: thresholdDb) { _, _ in clearPreview() }
    .onChange(of: minimumSilence) { _, _ in clearPreview() }
    .onChange(of: padding) { _, _ in clearPreview() }
    .onChange(of: editorState.videoRegions) { _, _ in clearPreview() }
    .onAppear {
      if !sources.contains(source), let first = sources.first {
        source = first
      }
    }
    .onDisappear {
      analysisTask?.cancel()
      analysisTask = nil
    }
  }

  private func runPreview() {
    analysisTask?.cancel()
    let config = config
    let source = source
    analysisTask = Task { @MainActor in
      let result = await editorState.previewSilenceRemoval(config: config, source: source)
      guard !Task.isCancelled else { return }
      preview = result
      analysisTask = nil
    }
  }

  private func apply() {
    guard let preview else { return }
    editorState.applySilenceRemoval(preview)
    self.preview = nil
  }

  private func clearPreview() {
    analysisTask?.cancel()
    analysisTask = nil
    preview = nil
  }
}
