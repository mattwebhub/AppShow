import Foundation
import Testing

@testable import AppShow

struct CursorSmoothingTests {
  private func sample(_ t: Double, x: Double, y: Double, p: Bool = false, c: Int? = nil) -> CursorSample {
    CursorSample(t: t, x: x, y: y, p: p, c: c)
  }

  private func distance(_ sample: CursorSample, to x: Double, _ y: Double) -> Double {
    ((sample.x - x) * (sample.x - x) + (sample.y - y) * (sample.y - y)).squareRoot()
  }

  private var stepInput: [CursorSample] {
    [sample(0, x: 0, y: 0), sample(0.1, x: 1, y: 1)]
  }

  private var walkInput: [CursorSample] {
    (0..<30).map { i in
      let t = Double(i) * 0.01
      return sample(t, x: Double(i) / 30, y: 1 - Double(i) / 30, p: i % 7 == 0, c: i % 3 == 0 ? i : nil)
    }
  }

  @Test func outputCountAndTimestampsMatchInput() {
    let input = walkInput
    let output = CursorSmoothing.smooth(samples: input, speed: .medium)
    #expect(output.count == input.count)
    #expect(output.map(\.t) == input.map(\.t))
  }

  @Test func pressedStateAndCursorTypeArePassedThrough() {
    let input = walkInput
    let output = CursorSmoothing.smooth(samples: input, speed: .fast)
    #expect(output.map(\.p) == input.map(\.p))
    #expect(output.map(\.c) == input.map(\.c))
  }

  @Test func firstSampleIsUntouched() {
    let input = [sample(0.5, x: 0.3, y: 0.7, p: true, c: 4), sample(0.6, x: 0.9, y: 0.1)]
    let output = CursorSmoothing.smooth(samples: input, speed: .slow)
    #expect(output[0].t == 0.5)
    #expect(output[0].x == 0.3)
    #expect(output[0].y == 0.7)
    #expect(output[0].p == true)
    #expect(output[0].c == 4)
  }

  @Test func fewerThanTwoSamplesAreReturnedVerbatim() {
    #expect(CursorSmoothing.smooth(samples: [], speed: .medium).isEmpty)
    let single = [sample(1, x: 0.2, y: 0.4, p: true, c: 2)]
    let output = CursorSmoothing.smooth(samples: single, speed: .rapid, clicks: [CursorClickEvent(t: 1, x: 0.9, y: 0.9, button: 0)])
    #expect(output.count == 1)
    #expect(output[0].x == 0.2)
    #expect(output[0].y == 0.4)
    #expect(output[0].c == 2)
  }

  @Test func smoothedPositionLagsBehindTheTarget() {
    let output = CursorSmoothing.smooth(samples: stepInput, speed: .slow)
    #expect(output[1].x > 0)
    #expect(output[1].x < 1)
    #expect(output[1].y > 0)
    #expect(output[1].y < 1)
  }

  @Test func clickBetweenSamplesSnapsTheNextOutputSampleToTheClickPosition() {
    let input = [sample(0, x: 0, y: 0), sample(0.1, x: 1, y: 1), sample(0.2, x: 1, y: 1)]
    let click = CursorClickEvent(t: 0.05, x: 0.7, y: 0.3, button: 0)
    let output = CursorSmoothing.smooth(samples: input, speed: .slow, clicks: [click])
    #expect(output[1].x == 0.7)
    #expect(output[1].y == 0.3)
    #expect(output[2].x > 0.7)
    #expect(output[2].y > 0.3)
  }

  @Test func clickExactlyOnASampleTimestampSnapsThatSample() {
    let input = [sample(0, x: 0, y: 0), sample(0.1, x: 1, y: 1), sample(0.2, x: 1, y: 1)]
    let click = CursorClickEvent(t: 0.1, x: 0.25, y: 0.75, button: 0)
    let output = CursorSmoothing.smooth(samples: input, speed: .medium, clicks: [click])
    #expect(output[1].x == 0.25)
    #expect(output[1].y == 0.75)
  }

  @Test func clickAtTheFirstSampleTimestampIsNeverApplied() {
    let input = [sample(0, x: 0, y: 0), sample(0.1, x: 0, y: 0)]
    let click = CursorClickEvent(t: 0, x: 0.5, y: 0.5, button: 0)
    let output = CursorSmoothing.smooth(samples: input, speed: .medium, clicks: [click])
    #expect(output[1].x == 0)
    #expect(output[1].y == 0)
  }

  @Test func cursorEasesTowardAnUpcomingClickWithinTheConvergenceWindow() {
    let input = (0..<4).map { sample(Double($0) * 0.1, x: 0, y: 0) }
    let click = CursorClickEvent(t: 0.25, x: 1, y: 1, button: 0)
    let output = CursorSmoothing.smooth(samples: input, speed: .rapid, clicks: [click])
    #expect(output[1].x == 0)
    #expect(abs(output[2].x - 0.5) < 1e-9)
    #expect(abs(output[2].y - 0.5) < 1e-9)
    #expect(output[3].x == 1)
    #expect(output[3].y == 1)
  }

  @Test func unsortedClicksAreAppliedInTimeOrder() {
    let input = (0..<4).map { sample(Double($0) * 0.1, x: 0, y: 0) }
    let clicks = [
      CursorClickEvent(t: 0.25, x: 0.9, y: 0.9, button: 0),
      CursorClickEvent(t: 0.05, x: 0.1, y: 0.1, button: 0),
    ]
    let output = CursorSmoothing.smooth(samples: input, speed: .slow, clicks: clicks)
    #expect(output[1].x == 0.1)
    #expect(output[3].x == 0.9)
  }

  @Test func gapOfOneSecondOrMoreResetsToTheTarget() {
    let input = [sample(0, x: 0, y: 0), sample(0.5, x: 1, y: 1), sample(1.5, x: 0.2, y: 0.8), sample(3, x: 0.6, y: 0.4)]
    let output = CursorSmoothing.smooth(samples: input, speed: .slow)
    #expect(output[1].x < 1)
    #expect(output[2].x == 0.2)
    #expect(output[2].y == 0.8)
    #expect(output[3].x == 0.6)
    #expect(output[3].y == 0.4)
  }

  @Test func nonIncreasingTimestampsResetToTheTarget() {
    let input = [sample(0, x: 0, y: 0), sample(0, x: 1, y: 1), sample(-0.5, x: 0.3, y: 0.3)]
    let output = CursorSmoothing.smooth(samples: input, speed: .fast)
    #expect(output[1].x == 1)
    #expect(output[1].y == 1)
    #expect(output[2].x == 0.3)
    #expect(output[2].y == 0.3)
  }

  @Test func resetAfterGapClearsVelocity() {
    let withGap = [sample(0, x: 0, y: 0), sample(0.5, x: 1, y: 1), sample(1.5, x: 0, y: 0), sample(1.6, x: 0, y: 0)]
    let output = CursorSmoothing.smooth(samples: withGap, speed: .medium)
    #expect(output[3].x == 0)
    #expect(output[3].y == 0)
  }

  @Test func rapidConvergesCloserThanSlowAfterOneHundredMilliseconds() {
    let rapid = CursorSmoothing.smooth(samples: stepInput, speed: .rapid)[1]
    let slow = CursorSmoothing.smooth(samples: stepInput, speed: .slow)[1]
    #expect(distance(rapid, to: 1, 1) < distance(slow, to: 1, 1))
  }

  @Test func presetsConvergeInOrderFromSlowToRapid() {
    let distances = CursorMovementSpeed.allCases.map { speed in
      distance(CursorSmoothing.smooth(samples: stepInput, speed: speed)[1], to: 1, 1)
    }
    #expect(distances == distances.sorted(by: >))
  }

  @Test func zoomedInCursorConvergesFasterThanUnzoomed() {
    let zoomed = ZoomTimeline(keyframes: [ZoomKeyframe(t: 0, zoomLevel: 2, centerX: 0.5, centerY: 0.5, isAuto: false)])
    let withZoom = CursorSmoothing.smooth(samples: stepInput, speed: .medium, zoomTimeline: zoomed)[1]
    let without = CursorSmoothing.smooth(samples: stepInput, speed: .medium)[1]
    #expect(distance(withZoom, to: 1, 1) < distance(without, to: 1, 1))
  }

  @Test func typingBurstMakesTheCursorConvergeFaster() {
    let keystrokes = [0.0, 0.05, 0.1, 0.15].map { KeystrokeEvent(t: $0, keyCode: 0, modifiers: 0, isDown: true) }
    let typing = CursorSmoothing.smooth(samples: stepInput, speed: .medium, keystrokes: keystrokes)[1]
    let idle = CursorSmoothing.smooth(samples: stepInput, speed: .medium)[1]
    #expect(distance(typing, to: 1, 1) < distance(idle, to: 1, 1))
  }

  @Test func fewerThanThreeKeyDownsDoNotFormATypingBurst() {
    let keystrokes = [0.0, 0.05].map { KeystrokeEvent(t: $0, keyCode: 0, modifiers: 0, isDown: true) }
    let typing = CursorSmoothing.smooth(samples: stepInput, speed: .medium, keystrokes: keystrokes)[1]
    let idle = CursorSmoothing.smooth(samples: stepInput, speed: .medium)[1]
    #expect(typing.x == idle.x)
    #expect(typing.y == idle.y)
  }

  @Test(arguments: CursorMovementSpeed.allCases)
  func outputIsFiniteForEverySpeedPreset(speed: CursorMovementSpeed) {
    let input = [
      sample(0, x: 0, y: 0),
      sample(0.0001, x: 1, y: 1),
      sample(0.0002, x: 0, y: 1),
      sample(0.9, x: 1, y: 0),
      sample(0.95, x: 0.5, y: 0.5),
      sample(2, x: 0.25, y: 0.25),
      sample(2, x: 0.75, y: 0.75),
      sample(2.5, x: 0, y: 0),
    ]
    let zoomed = ZoomTimeline(keyframes: [ZoomKeyframe(t: 0, zoomLevel: 8, centerX: 0.5, centerY: 0.5, isAuto: false)])
    let clicks = [CursorClickEvent(t: 0.92, x: 0.1, y: 0.1, button: 0)]
    let keystrokes = [0.0, 0.1, 0.2, 0.3].map { KeystrokeEvent(t: $0, keyCode: 0, modifiers: 0, isDown: true) }
    let output = CursorSmoothing.smooth(samples: input, speed: speed, clicks: clicks, zoomTimeline: zoomed, keystrokes: keystrokes)
    #expect(output.count == input.count)
    #expect(output.allSatisfy { $0.x.isFinite && $0.y.isFinite })
    #expect(output.allSatisfy { $0.x >= -0.5 && $0.x <= 1.5 && $0.y >= -0.5 && $0.y <= 1.5 })
  }
}
