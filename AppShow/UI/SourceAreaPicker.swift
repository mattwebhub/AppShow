import AVFoundation
import SwiftUI

struct SourceAreaPicker: View {
  let title: String
  let videoURL: URL
  let duration: Double
  let onApply: (CGRect, Double, Double) throws -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var start: Double
  @State private var end: Double
  @State private var selection: CGRect = CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
  @State private var image: NSImage?
  @State private var error: String?
  @State private var loading = true

  init(title: String, videoURL: URL, at time: Double, duration: Double, onApply: @escaping (CGRect, Double, Double) throws -> Void) {
    self.title = title
    self.videoURL = videoURL
    self.duration = duration
    self.onApply = onApply
    let start = max(0, min(time, duration - 0.05))
    _start = State(initialValue: start)
    _end = State(initialValue: min(duration, start + 5))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "viewfinder", title: title)
      Text("Drag over the area in the source recording. Set when the effect starts and ends.")
        .font(.system(size: FontSize.xs))
        .foregroundStyle(AppShowColors.secondaryText)
      GeometryReader { geometry in
        if let image, !loading {
          let frame = AVMakeRect(aspectRatio: image.size, insideRect: CGRect(origin: .zero, size: geometry.size))
          ZStack(alignment: .topLeading) {
            Image(nsImage: image).resizable().frame(width: frame.width, height: frame.height)
            Rectangle()
              .fill(Color.accentColor.opacity(0.15))
              .overlay(Rectangle().strokeBorder(Color.accentColor, lineWidth: 2))
              .frame(width: selection.width * frame.width, height: selection.height * frame.height)
              .offset(x: selection.minX * frame.width, y: selection.minY * frame.height)
              .allowsHitTesting(false)
          }
          .contentShape(Rectangle())
          .gesture(
            DragGesture(minimumDistance: 2).onChanged { value in
              let a = CGPoint(
                x: max(0, min(1, value.startLocation.x / frame.width)),
                y: max(0, min(1, value.startLocation.y / frame.height))
              )
              let b = CGPoint(x: max(0, min(1, value.location.x / frame.width)), y: max(0, min(1, value.location.y / frame.height)))
              selection = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
            }
          )
          .position(x: frame.midX, y: frame.midY)
        } else if loading {
          ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .frame(height: 340)
      .background(AppShowColors.fieldBackground)
      TimeRangeControls(start: $start, end: $end)
      if let error {
        Text(error).font(.system(size: FontSize.xs)).foregroundStyle(AppShowColors.secondaryText)
      }
      HStack {
        Button("Cancel") { dismiss() }.buttonStyle(OutlineButtonStyle(size: .small))
          .keyboardShortcut(.cancelAction)
        Spacer()
        Button("Add \(title)") {
          do {
            try onApply(selection, start, end)
            dismiss()
          } catch {
            self.error = (error as? AgentToolError)?.message ?? error.localizedDescription
          }
        }
        .buttonStyle(PrimaryButtonStyle(size: .small))
        .keyboardShortcut(.defaultAction)
        .disabled(loading || image == nil || !validSelection)
      }
    }
    .padding(20)
    .frame(width: 680)
    .background(AppShowColors.backgroundCard)
    .task(id: start) { await loadFrame() }
  }

  private var validSelection: Bool {
    start.isFinite && end.isFinite && start >= 0 && end <= duration && end - start >= 0.05
      && selection.width >= 0.01 && selection.height >= 0.01
  }

  private func loadFrame() async {
    guard start.isFinite, start >= 0, start < duration else { return }
    loading = true
    error = nil
    let generator = AVAssetImageGenerator(asset: AVURLAsset(url: videoURL))
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: 1280, height: 1280)
    do {
      let result = try await generator.image(at: CMTime(seconds: start, preferredTimescale: 600))
      guard !Task.isCancelled else { return }
      image = NSImage(cgImage: result.image, size: .zero)
      loading = false
    } catch {
      guard !Task.isCancelled else { return }
      image = nil
      loading = false
      self.error = "The source frame could not be loaded. Try another start time."
    }
  }
}
