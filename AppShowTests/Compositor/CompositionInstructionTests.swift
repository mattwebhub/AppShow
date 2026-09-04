import CoreMedia
import Testing

@testable import AppShow

struct CompositionInstructionTests {
  private func seconds(_ value: Double) -> CMTime {
    CMTime(seconds: value, preferredTimescale: 600)
  }

  private var cutMappings: [VideoSegmentMapping] {
    [
      VideoSegmentMapping(compositionStart: 0, sourceStart: 0, duration: 2),
      VideoSegmentMapping(compositionStart: 2, sourceStart: 5, duration: 2),
    ]
  }

  private func instruction(
    trimStartSeconds: Double = 0,
    mappings: [VideoSegmentMapping] = [],
    zoomTimeline: ZoomTimeline? = nil,
    zoomFollowCursor: Bool = true,
    cursorSnapshot: CursorMetadataSnapshot? = nil,
    spotlightRegions: [SpotlightRegionData] = []
  ) -> CompositionInstruction {
    CompositionInstruction(
      timeRange: CMTimeRange(start: .zero, duration: seconds(10)),
      screenTrackID: 1,
      webcamTrackID: nil,
      cameraRect: nil,
      cameraCornerRadius: 0,
      outputSize: CGSize(width: 640, height: 360),
      cursorSnapshot: cursorSnapshot,
      zoomFollowCursor: zoomFollowCursor,
      zoomTimeline: zoomTimeline,
      trimStartSeconds: trimStartSeconds,
      videoSegmentMappings: mappings,
      spotlightRegions: spotlightRegions
    )
  }

  private func snapshot(_ samples: [(t: Double, x: Double, y: Double)]) -> CursorMetadataSnapshot {
    CursorMetadataSnapshot(
      samples: samples.map { CursorSample(t: $0.t, x: $0.x, y: $0.y, p: false) },
      clicks: [],
      captureAreaWidth: 1920,
      captureAreaHeight: 1080
    )
  }

  @Test func sourceTimeInsideSecondMappingOffsetsIntoThatSegment() {
    let sut = instruction(mappings: cutMappings)

    #expect(sut.sourceTime(for: seconds(2.5)) == 5.5)
  }

  @Test func sourceTimeInsideFirstMappingIsIdentity() {
    let sut = instruction(mappings: cutMappings)

    #expect(sut.sourceTime(for: seconds(1.0)) == 1.0)
  }

  @Test func sourceTimeAtSegmentBoundaryBelongsToTheLaterSegment() {
    let sut = instruction(mappings: cutMappings)

    #expect(sut.sourceTime(for: seconds(2.0)) == 5.0)
  }

  @Test func sourceTimeOutsideAllMappingsAddsTrimStart() {
    let sut = instruction(trimStartSeconds: 3, mappings: cutMappings)

    #expect(sut.sourceTime(for: seconds(4.5)) == 7.5)
  }

  @Test func sourceTimeWithoutMappingsAddsTrimStart() {
    let sut = instruction(trimStartSeconds: 3)

    #expect(sut.sourceTime(for: seconds(2.5)) == 5.5)
  }

  @Test func spotlightIsInactiveWithoutRegions() {
    let sut = instruction()

    #expect(!sut.isSpotlightActive(at: 1))
  }

  @Test func spotlightIsActiveInsideRegionInclusive() {
    let sut = instruction(spotlightRegions: [SpotlightRegionData(startSeconds: 1, endSeconds: 3)])

    #expect(sut.isSpotlightActive(at: 1))
    #expect(sut.isSpotlightActive(at: 2))
    #expect(sut.isSpotlightActive(at: 3))
    #expect(!sut.isSpotlightActive(at: 0.99))
    #expect(!sut.isSpotlightActive(at: 3.01))
  }

  @Test func spotlightSettingsFallBackToInstructionDefaultsOutsideRegions() {
    let sut = instruction(spotlightRegions: [SpotlightRegionData(startSeconds: 1, endSeconds: 3)])

    let settings = sut.effectiveSpotlightSettings(at: 5)

    #expect(settings.radius == 200)
    #expect(settings.dimOpacity == 0.6)
    #expect(settings.edgeSoftness == 50)
    #expect(settings.fadeFactor == 1)
  }

  @Test func spotlightSettingsUseRegionOverridesAndFadeInOut() {
    let region = SpotlightRegionData(
      startSeconds: 1,
      endSeconds: 4,
      customRadius: 120,
      customDimOpacity: 0.3,
      fadeDuration: 1
    )
    let sut = instruction(spotlightRegions: [region])

    let fadingIn = sut.effectiveSpotlightSettings(at: 1.5)
    let steady = sut.effectiveSpotlightSettings(at: 2.5)
    let fadingOut = sut.effectiveSpotlightSettings(at: 3.75)

    #expect(fadingIn.radius == 120)
    #expect(fadingIn.dimOpacity == 0.3)
    #expect(fadingIn.edgeSoftness == 50)
    #expect(fadingIn.fadeFactor == 0.5)
    #expect(steady.fadeFactor == 1)
    #expect(fadingOut.fadeFactor == 0.25)
  }

  @Test func spotlightFadeFactorIsOneWithoutFadeDuration() {
    let sut = instruction(spotlightRegions: [SpotlightRegionData(startSeconds: 1, endSeconds: 4)])

    #expect(sut.effectiveSpotlightSettings(at: 1.01).fadeFactor == 1)
  }

  @Test func resolveZoomRectIsNilWithoutTimeline() {
    let sut = instruction()

    #expect(FrameRenderer.resolveZoomRect(compositionTime: seconds(1), instruction: sut) == nil)
  }

  @Test func resolveZoomRectSamplesTimelineAtSourceTime() throws {
    let timeline = ZoomTimeline(keyframes: [
      ZoomKeyframe(t: 0, zoomLevel: 1, centerX: 0.5, centerY: 0.5, isAuto: false),
      ZoomKeyframe(t: 5, zoomLevel: 2, centerX: 0.5, centerY: 0.5, isAuto: false),
    ])
    let mapped = instruction(mappings: cutMappings, zoomTimeline: timeline)
    let unmapped = instruction(zoomTimeline: timeline)

    let mappedRect = try #require(FrameRenderer.resolveZoomRect(compositionTime: seconds(2.5), instruction: mapped))
    let unmappedRect = try #require(FrameRenderer.resolveZoomRect(compositionTime: seconds(2.5), instruction: unmapped))

    #expect(abs(mappedRect.width - 0.5) < 1e-9)
    #expect(abs(unmappedRect.width - 0.75) < 1e-9)
  }

  @Test func resolveZoomRectDoesNotFollowCursorWhenUnzoomed() throws {
    let timeline = ZoomTimeline(keyframes: [
      ZoomKeyframe(t: 0, zoomLevel: 1, centerX: 0.5, centerY: 0.5, isAuto: false)
    ])
    let sut = instruction(zoomTimeline: timeline, cursorSnapshot: snapshot([(t: 0, x: 0.2, y: 0.2)]))

    let rect = try #require(FrameRenderer.resolveZoomRect(compositionTime: seconds(1), instruction: sut))

    #expect(rect == CGRect(x: 0, y: 0, width: 1, height: 1))
  }

  @Test func resolveZoomRectFollowsCursorSampledAtSourceTimeWhenZoomed() throws {
    let timeline = ZoomTimeline(keyframes: [
      ZoomKeyframe(t: 0, zoomLevel: 2, centerX: 0.5, centerY: 0.5, isAuto: false)
    ])
    let cursor = snapshot([
      (t: 0, x: 0.5, y: 0.5), (t: 3, x: 0.5, y: 0.5), (t: 5, x: 0.2, y: 0.2), (t: 8, x: 0.2, y: 0.2),
    ])
    let sut = instruction(mappings: cutMappings, zoomTimeline: timeline, cursorSnapshot: cursor)
    let base = CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
    let expected = ZoomTimeline.followCursor(base, cursorPosition: CGPoint(x: 0.2, y: 0.2))

    let rect = try #require(FrameRenderer.resolveZoomRect(compositionTime: seconds(2.5), instruction: sut))

    #expect(expected != base)
    #expect(abs(rect.origin.x - expected.origin.x) < 1e-9)
    #expect(abs(rect.origin.y - expected.origin.y) < 1e-9)
    #expect(rect.size == base.size)
  }

  @Test func resolveZoomRectIgnoresCursorWhenFollowIsDisabled() throws {
    let timeline = ZoomTimeline(keyframes: [
      ZoomKeyframe(t: 0, zoomLevel: 2, centerX: 0.5, centerY: 0.5, isAuto: false)
    ])
    let sut = instruction(
      zoomTimeline: timeline,
      zoomFollowCursor: false,
      cursorSnapshot: snapshot([(t: 0, x: 0.2, y: 0.2)])
    )

    let rect = try #require(FrameRenderer.resolveZoomRect(compositionTime: seconds(1), instruction: sut))

    #expect(rect == CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5))
  }
}
