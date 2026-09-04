import AppKit
import SwiftUI

extension PropertiesPanel {
  var cameraBackgroundSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "person.and.background.dotted", title: "Background")

      SegmentPicker(
        items: CameraBackgroundMode.allCases,
        label: { $0.label },
        selection: $cameraBackgroundMode
      )

      switch cameraBackgroundMode {
      case .none:
        EmptyView()
      case .blur:
        SliderRow(
          label: "Intensity",
          value: $cameraBlurIntensity,
          range: 0.1...1.0,
          step: 0.05,
          formattedValue: "\(Int(cameraBlurIntensity * 100))%"
        )
      case .color:
        cameraColorGrid
      case .gradient:
        cameraGradientGrid
      case .image:
        cameraImageSection
      }
    }
    .disabled(!editorState.webcamEnabled)
  }

  private var cameraColorGrid: some View {
    let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 8)
    return LazyVGrid(columns: columns, spacing: 6) {
      ForEach(TailwindColors.all) { preset in
        SwatchButton(
          fill: preset.swiftUIColor,
          isSelected: selectedCameraColorId == preset.id
        ) {
          selectedCameraColorId = preset.id
        }
      }
    }
  }

  private var cameraGradientGrid: some View {
    let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 8)
    return LazyVGrid(columns: columns, spacing: 6) {
      ForEach(GradientPresets.all) { preset in
        SwatchButton(
          fill: LinearGradient(
            colors: preset.colors,
            startPoint: preset.startPoint,
            endPoint: preset.endPoint
          ),
          isSelected: selectedCameraGradientId == preset.id
        ) {
          selectedCameraGradientId = preset.id
        }
      }
    }
  }

  private var cameraImageSection: some View {
    ImageDropSection(
      image: editorState.cameraBackgroundImage,
      onPick: { pickCameraBackgroundImage() },
      onDrop: { url in
        editorState.setCameraBackgroundImage(from: url)
        if case .image(let f) = editorState.cameraBackgroundStyle {
          cameraBackgroundImageFilename = f
        }
      }
    )
  }

  func syncCameraBackgroundMode() {
    switch editorState.cameraBackgroundStyle {
    case .none:
      cameraBackgroundMode = .none
    case .blur(let intensity):
      cameraBackgroundMode = .blur
      cameraBlurIntensity = intensity
    case .solidColor(let color):
      cameraBackgroundMode = .color
      if let preset = TailwindColors.all.first(where: { $0.color == color }) {
        selectedCameraColorId = preset.id
      }
    case .gradient(let id):
      cameraBackgroundMode = .gradient
      selectedCameraGradientId = id
    case .image(let filename):
      cameraBackgroundMode = .image
      cameraBackgroundImageFilename = filename
    }
  }

  func updateCameraBackgroundStyle(mode: CameraBackgroundMode) {
    switch mode {
    case .none:
      editorState.cameraBackgroundStyle = .none
    case .blur:
      editorState.cameraBackgroundStyle = .blur(cameraBlurIntensity)
    case .color:
      if let id = selectedCameraColorId, let preset = TailwindColors.all.first(where: { $0.id == id }) {
        editorState.cameraBackgroundStyle = .solidColor(preset.color)
      } else {
        let first = TailwindColors.all[0]
        selectedCameraColorId = first.id
        editorState.cameraBackgroundStyle = .solidColor(first.color)
      }
    case .gradient:
      editorState.cameraBackgroundStyle = .gradient(selectedCameraGradientId)
    case .image:
      if case .image = editorState.cameraBackgroundStyle {
        return
      }
      if let filename = cameraBackgroundImageFilename {
        editorState.cameraBackgroundStyle = .image(filename)
      }
    }
  }

  func pickCameraBackgroundImage() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.begin { response in
      guard response == .OK, let url = panel.url else { return }
      DispatchQueue.main.async {
        self.editorState.setCameraBackgroundImage(from: url)
        if case .image(let f) = self.editorState.cameraBackgroundStyle {
          self.cameraBackgroundImageFilename = f
        }
      }
    }
  }
}
