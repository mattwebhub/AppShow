import CoreMedia
import SwiftUI

extension PropertiesPanel {
  var captionLabelWidth: CGFloat { 72 }

  var captionsSection: some View {
    VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
      generateSection
      if !editorState.captionSegments.isEmpty {
        styleSection
        segmentsSection
      }
    }
  }

  var generateSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "waveform", title: "Generate")

      VStack(alignment: .leading, spacing: Layout.compactSpacing) {
        Text("Model")
          .font(.system(size: FontSize.xs))
          .foregroundStyle(AppShowColors.secondaryText)
        SegmentPicker(
          items: WhisperModel.allCases,
          label: { $0.shortLabel },
          selection: Binding(
            get: { WhisperModel(rawValue: editorState.captionModel) ?? .base },
            set: { editorState.captionModel = $0.rawValue }
          )
        )
      }

      if let model = WhisperModel(rawValue: editorState.captionModel) {
        Text(model.description)
          .font(.system(size: FontSize.xs))
          .foregroundStyle(AppShowColors.secondaryText)
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)
          .frame(minHeight: Layout.compactSpacing, alignment: .top)
      }

      HStack(spacing: 8) {
        Text("Language")
          .font(.system(size: FontSize.xs))
          .foregroundStyle(AppShowColors.secondaryText)
          .frame(width: captionLabelWidth, alignment: .leading)
        SelectButton(label: editorState.captionLanguage.label) { dismiss in
          LanguagePicker(
            selection: $editorState.captionLanguage,
            onSelect: dismiss
          )
        }
      }

      if editorState.hasMicAudio && editorState.hasSystemAudio {
        HStack(spacing: 8) {
          Text("Source")
            .font(.system(size: FontSize.xs))
            .foregroundStyle(AppShowColors.secondaryText)
            .frame(width: captionLabelWidth, alignment: .leading)
          SegmentPicker(
            items: CaptionAudioSource.allCases,
            label: { $0.label },
            selection: $editorState.captionAudioSource
          )
        }
      }

      if let error = editorState.transcriptionError {
        Text(error)
          .font(.system(size: FontSize.xs))
          .foregroundStyle(AppShowColors.secondaryText)
          .fixedSize(horizontal: false, vertical: true)
      }

      if WhisperModelManager.shared.isDownloading {
        VStack(spacing: 4) {
          HStack(spacing: 8) {
            ProgressView(value: WhisperModelManager.shared.downloadProgress)
              .tint(AppShowColors.primaryText)
            Text("\(Int(WhisperModelManager.shared.downloadProgress * 100))%")
              .font(.system(size: FontSize.xs).monospacedDigit())
              .foregroundStyle(AppShowColors.secondaryText)
              .frame(width: 32, alignment: .trailing)
          }
          HStack {
            Text("Downloading model…")
              .font(.system(size: FontSize.xs))
              .foregroundStyle(AppShowColors.secondaryText)
            Spacer()
            Button("Cancel") {
              WhisperModelManager.shared.cancelDownload()
            }
            .buttonStyle(OutlineButtonStyle(size: .small))
          }
        }
      }

      if editorState.isTranscribing {
        VStack(spacing: 4) {
          HStack(spacing: 8) {
            ProgressView(value: editorState.transcriptionProgress)
              .tint(AppShowColors.primaryText)
            Text("\(Int(editorState.transcriptionProgress * 100))%")
              .font(.system(size: FontSize.xs).monospacedDigit())
              .foregroundStyle(AppShowColors.secondaryText)
              .frame(width: 32, alignment: .trailing)
          }
          HStack {
            Text(transcriptionStatusText)
              .font(.system(size: FontSize.xs))
              .foregroundStyle(AppShowColors.secondaryText)
            Spacer()
            Button("Cancel") {
              editorState.cancelTranscription()
            }
            .buttonStyle(OutlineButtonStyle(size: .small))
          }
        }
      } else {
        HStack(spacing: 8) {
          Button(
            WhisperModel(rawValue: editorState.captionModel).map { !WhisperModelManager.shared.isDownloaded($0) } == true
              ? "Download model & generate" : editorState.captionSegments.isEmpty ? "Generate Captions" : "Regenerate"
          ) {
            handleGenerateAction()
          }
          .buttonStyle(PrimaryButtonStyle(size: .small, fullWidth: true))

          if !editorState.captionSegments.isEmpty {
            Button("Clear") {
              editorState.clearCaptions()
            }
            .buttonStyle(OutlineButtonStyle(size: .small, fullWidth: true))
          }
        }

        if editorState.transcriptionDidFinishEmpty {
          HStack(spacing: 6) {
            Image(systemName: "text.badge.xmark")
              .font(.system(size: FontSize.xs))
              .foregroundStyle(AppShowColors.secondaryText)
            Text("No speech detected in the audio.")
              .font(.system(size: FontSize.xs))
              .foregroundStyle(AppShowColors.secondaryText)
          }
        }
      }
    }
  }

  private var transcriptionStatusText: String {
    let pct = Int(editorState.transcriptionProgress * 100)
    if editorState.transcriptionProgress < 0.15 {
      return "Loading model… \(pct)%"
    }
    return "Transcribing… \(pct)%"
  }

  private func handleGenerateAction() {
    guard let model = WhisperModel(rawValue: editorState.captionModel) else { return }
    if WhisperModelManager.shared.isDownloaded(model) {
      editorState.generateCaptions()
    } else {
      Task {
        do {
          try await WhisperModelManager.shared.downloadModel(model)
          editorState.generateCaptions()
        } catch is CancellationError {
        } catch {
          editorState.transcriptionError = "Model download failed: \(error.localizedDescription)"
        }
      }
    }
  }

}
