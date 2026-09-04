import SwiftUI
import UniformTypeIdentifiers

struct FileDropModifier: ViewModifier {
  let contentTypes: [UTType]
  let onDrop: ([URL]) -> Void

  @State private var isTargeted = false

  func body(content: Content) -> some View {
    content
      .overlay {
        if isTargeted {
          RoundedRectangle(cornerRadius: Radius.xxl)
            .strokeBorder(AppShowColors.accent, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
            .allowsHitTesting(false)
        }
      }
      .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
        let types = contentTypes
        var accepted = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
          accepted = true
          _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
            guard let data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            guard let type = UTType(filenameExtension: url.pathExtension), types.contains(where: { type.conforms(to: $0) })
            else { return }
            DispatchQueue.main.async {
              onDrop([url])
            }
          }
        }
        return accepted
      }
  }
}

extension View {
  func fileDrop(of contentTypes: [UTType], perform onDrop: @escaping ([URL]) -> Void) -> some View {
    modifier(FileDropModifier(contentTypes: contentTypes, onDrop: onDrop))
  }
}
