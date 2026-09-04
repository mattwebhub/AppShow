import CoreMedia
import Foundation

enum SilenceSource: String, CaseIterable, Identifiable, Sendable {
  case microphone
  case system
  case both

  var id: String { rawValue }

  var label: String {
    switch self {
    case .microphone: "Microphone"
    case .system: "System"
    case .both: "Both"
    }
  }
}

struct SilenceRemovalPreview: Sendable, Equatable {
  static let historyLabel = "Silences removed"

  var silences: [ClosedRange<Double>] = []
  var slices: [VideoRegionData] = []
  var totalRemoved: Double = 0
  var errorDescription: String? = nil

  var count: Int { silences.count }

  var canApply: Bool {
    count > 0 && !slices.isEmpty && totalRemoved > CutTimeline.cutTolerance
  }
}

extension EditorState {
  var availableSilenceSources: [SilenceSource] {
    switch (hasMicAudio, hasSystemAudio) {
    case (true, true): [.microphone, .system, .both]
    case (true, false): [.microphone]
    case (false, true): [.system]
    case (false, false): []
    }
  }

  func silenceSourceURLs(for source: SilenceSource) -> [URL] {
    let mic = processedMicAudioURL ?? result.microphoneAudioURL
    let system = result.systemAudioURL
    switch source {
    case .microphone: return [mic].compactMap { $0 }
    case .system: return [system].compactMap { $0 }
    case .both: return [mic, system].compactMap { $0 }
    }
  }

  func previewSilenceRemoval(config: SilenceDetectorConfig, source: SilenceSource? = nil) async -> SilenceRemovalPreview {
    guard let chosen = source ?? availableSilenceSources.first else { return SilenceRemovalPreview() }
    let urls = silenceSourceURLs(for: chosen)
    guard !urls.isEmpty else { return SilenceRemovalPreview() }
    let silences: [ClosedRange<Double>]
    do {
      silences = try await Task.detached(priority: .userInitiated) {
        try await SilenceAnalysis.analyze(urls: urls, config: config)
      }.value
    } catch {
      logger.error("Silence analysis failed: \(error)")
      return SilenceRemovalPreview(errorDescription: error.localizedDescription)
    }
    let existing = cutTimeline
    let keep = SilenceDetector.keepSlices(duration: existing.duration, silences: silences, config: config)
    let result = SilenceDetector.intersect(existing: existing, keep: keep)
    return SilenceRemovalPreview(
      silences: silences,
      slices: result.slices,
      totalRemoved: max(0, existing.totalDuration - result.totalDuration)
    )
  }

  func applySilenceRemoval(_ preview: SilenceRemovalPreview) {
    guard preview.canApply else { return }
    isRestoringState = true
    pendingUndoTask?.cancel()
    videoRegions = preview.slices
    scheduleSave()
    history.pushSnapshot(createSnapshot(), label: SilenceRemovalPreview.historyLabel)
    Task { @MainActor [weak self] in
      self?.isRestoringState = false
    }
  }
}
