import AVFoundation
import SwiftUI

extension TimelineView {
  func timeRuler(width: CGFloat) -> some View {
    let geometry = geometry(width: width)
    let duration = geometry.visibleDuration
    let interval = geometry.rulerInterval(zoom: timelineZoom)
    let minorInterval = interval / 5

    return Canvas { context, size in
      var t: Double = 0
      while t <= duration {
        let x = geometry.x(forDisplay: t)
        let isMajor = isApproximatelyMultiple(t, of: interval)

        if isMajor {
          let tickPath = Path { p in
            p.move(to: CGPoint(x: x, y: size.height - 10))
            p.addLine(to: CGPoint(x: x, y: size.height))
          }
          context.stroke(tickPath, with: .color(ReframedColors.primaryText), lineWidth: 1)

          let label = formatRulerTime(t, totalDuration: duration)
          let text = Text(label)
            .font(.system(size: FontSize.xs, design: .monospaced))
            .foregroundStyle(ReframedColors.primaryText)
          context.draw(context.resolve(text), at: CGPoint(x: x, y: size.height - 16), anchor: .bottom)
        } else {
          let tickPath = Path { p in
            p.move(to: CGPoint(x: x, y: size.height - 5))
            p.addLine(to: CGPoint(x: x, y: size.height))
          }
          context.stroke(tickPath, with: .color(ReframedColors.primaryText.opacity(0.5)), lineWidth: 0.5)
        }
        t += minorInterval
      }
    }
    .frame(width: width, height: 32)
    .background(ReframedColors.backgroundCard)
    .contentShape(Rectangle())
    .gesture(rulerScrubGesture(width: width))
  }

  private func isApproximatelyMultiple(_ value: Double, of interval: Double) -> Bool {
    let remainder = value.truncatingRemainder(dividingBy: interval)
    return remainder < 0.001 || (interval - remainder) < 0.001
  }

  private func formatRulerTime(_ seconds: Double, totalDuration: Double) -> String {
    let mins = Int(seconds) / 60
    let secs = Int(seconds) % 60
    if totalDuration >= 60 {
      return String(format: "%d:%02d", mins, secs)
    }
    return String(format: "0:%02d", secs)
  }

  private func rulerScrubGesture(width: CGFloat) -> some Gesture {
    DragGesture(minimumDistance: 0)
      .onChanged { value in
        let time = CMTime(seconds: sourceTime(forX: value.location.x, width: width), preferredTimescale: 600)
        onScrub(time)
      }
  }
}
