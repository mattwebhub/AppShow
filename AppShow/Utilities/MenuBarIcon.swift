import AppKit

enum MenuBarIcon {
  enum State {
    case idle
    case selecting
    case countdown
    case recording
    case paused
    case processing
    case processingPulse
    case editing
  }

  static var image: NSImage {
    makeImage(for: .idle)
  }

  static func makeImage(for state: State) -> NSImage {
    let mark = NSImage(resource: .menuBarMark)
    let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
      mark.draw(in: rect)
      NSColor.black.setStroke()
      NSColor.black.setFill()
      drawActivity(for: state)
      return true
    }
    image.isTemplate = true
    image.accessibilityDescription = "AppShow — \(label(for: state))"
    return image
  }

  private static func label(for state: State) -> String {
    switch state {
    case .idle: "Ready"
    case .selecting: "Selecting capture area"
    case .countdown: "Counting down"
    case .recording: "Recording"
    case .paused: "Recording paused"
    case .processing, .processingPulse: "Processing"
    case .editing: "Editing"
    }
  }

  private static func drawActivity(for state: State) {
    let center = NSPoint(x: 4.5, y: 4.5)
    switch state {
    case .idle, .processing:
      break
    case .selecting:
      let cross = NSBezierPath()
      cross.lineWidth = 1.2
      cross.lineCapStyle = .round
      cross.move(to: NSPoint(x: center.x - 2, y: center.y))
      cross.line(to: NSPoint(x: center.x + 2, y: center.y))
      cross.move(to: NSPoint(x: center.x, y: center.y - 2))
      cross.line(to: NSPoint(x: center.x, y: center.y + 2))
      cross.stroke()
    case .countdown:
      let ring = NSBezierPath(ovalIn: NSRect(x: 2.5, y: 2.5, width: 4, height: 4))
      ring.lineWidth = 1.2
      ring.stroke()
    case .recording:
      NSBezierPath(ovalIn: NSRect(x: 2, y: 2, width: 5, height: 5)).fill()
    case .paused:
      for x in [2.3, 5.1] {
        NSBezierPath(roundedRect: NSRect(x: x, y: 2, width: 1.6, height: 5), xRadius: 0.4, yRadius: 0.4).fill()
      }
    case .processingPulse:
      NSBezierPath(ovalIn: NSRect(x: 2.8, y: 2.8, width: 3.4, height: 3.4)).fill()
    case .editing:
      let triangle = NSBezierPath()
      triangle.move(to: NSPoint(x: 3, y: 2))
      triangle.line(to: NSPoint(x: 7, y: 4.5))
      triangle.line(to: NSPoint(x: 3, y: 7))
      triangle.close()
      triangle.fill()
    }
  }
}
