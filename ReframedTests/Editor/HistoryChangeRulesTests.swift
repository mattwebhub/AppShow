import Testing

@testable import Reframed

@MainActor
struct HistoryChangeRulesTests {
  private func data(_ regions: [VideoRegionData]) -> EditorStateData {
    EditorStateData(
      trimStartSeconds: 0,
      trimEndSeconds: 10,
      backgroundStyle: .none,
      padding: 0,
      videoCornerRadius: 0,
      cameraCornerRadius: 0,
      cameraBorderWidth: 0,
      cameraLayout: CameraLayout(),
      videoRegions: regions
    )
  }

  @Test func splitIsDescribedAsCutAdded() {
    let before = data([VideoRegionData(startSeconds: 0, endSeconds: 10)])
    let after = data(CutTimeline(slices: before.videoRegions!, duration: 10).split(at: 4).slices)
    #expect(History.describeChanges(from: before, to: after) == ["Cut added"])
  }

  @Test func sliceRemovalIsDescribedAsCutRemoved() {
    let split = CutTimeline(slices: [VideoRegionData(startSeconds: 0, endSeconds: 10)], duration: 10).split(at: 4)
    let before = data(split.slices)
    let after = data([split.slices[1]])
    #expect(History.describeChanges(from: before, to: after) == ["Cut removed"])
  }

  @Test func sliceResizeIsDescribedAsCutAdjusted() {
    let region = VideoRegionData(startSeconds: 0, endSeconds: 10)
    var resized = region
    resized.endSeconds = 8
    #expect(History.describeChanges(from: data([region]), to: data([resized])) == ["Cut adjusted"])
  }

  private func audioData(_ tracks: [ExternalAudioTrackData]?) -> EditorStateData {
    var state = data([])
    state.videoRegions = nil
    state.externalAudioTracks = tracks
    return state
  }

  private func audioTrack() -> ExternalAudioTrackData {
    ExternalAudioTrackData(
      id: ProjectFixtures.fixedUUID(1),
      fileName: "audio-0badf00d.wav",
      displayName: "Loop",
      sourceDurationSeconds: 12,
      timelineStartSeconds: 3,
      fileOutSeconds: 4
    )
  }

  @Test func describesExternalAudioTrackAddedRemovedAdjusted() {
    let track = audioTrack()
    #expect(History.describeChanges(from: audioData(nil), to: audioData([track])) == ["Audio track added"])
    #expect(History.describeChanges(from: audioData([track]), to: audioData(nil)) == ["Audio track removed"])
    var moved = track
    moved.timelineStartSeconds = 5
    #expect(History.describeChanges(from: audioData([track]), to: audioData([moved])) == ["Audio track adjusted"])
    var trimmed = track
    trimmed.fileInSeconds = 1
    trimmed.fileOutSeconds = 3
    #expect(History.describeChanges(from: audioData([track]), to: audioData([trimmed])) == ["Audio track adjusted"])
  }

  @Test func describesExternalAudioTrackVolumeMuteAndFades() {
    let track = audioTrack()
    var quieter = track
    quieter.volume = 0.8
    #expect(History.describeChanges(from: audioData([track]), to: audioData([quieter])) == ["Audio track volume set to 80%"])
    var muted = track
    muted.muted = true
    #expect(History.describeChanges(from: audioData([track]), to: audioData([muted])) == ["Audio track muted"])
    #expect(History.describeChanges(from: audioData([muted]), to: audioData([track])) == ["Audio track unmuted"])
    var fadeIn = track
    fadeIn.fadeInSeconds = 1
    #expect(History.describeChanges(from: audioData([track]), to: audioData([fadeIn])) == ["Audio track fade in set to 1.0s"])
    var fadeOut = track
    fadeOut.fadeOutSeconds = 2.5
    #expect(History.describeChanges(from: audioData([track]), to: audioData([fadeOut])) == ["Audio track fade out set to 2.5s"])
  }

  private func overlayData(_ overlays: [TextOverlayData]?) -> EditorStateData {
    EditorStateData(
      trimStartSeconds: 0,
      trimEndSeconds: 10,
      backgroundStyle: .none,
      padding: 0,
      videoCornerRadius: 0,
      cameraCornerRadius: 0,
      cameraBorderWidth: 0,
      cameraLayout: CameraLayout(),
      textOverlays: overlays
    )
  }

  @Test func overlayChangesAreDescribedAsAddedRemovedAdjusted() {
    let overlay = TextOverlayData(startSeconds: 1, endSeconds: 4)
    var edited = overlay
    edited.text = "Edited"
    #expect(History.describeChanges(from: overlayData(nil), to: overlayData([overlay])) == ["Text overlay added"])
    #expect(History.describeChanges(from: overlayData([overlay]), to: overlayData(nil)) == ["Text overlay removed"])
    #expect(History.describeChanges(from: overlayData([overlay]), to: overlayData([edited])) == ["Text overlay adjusted"])
  }

  private func imageOverlayData(_ overlays: [ImageOverlayData]?) -> EditorStateData {
    EditorStateData(
      trimStartSeconds: 0,
      trimEndSeconds: 10,
      backgroundStyle: .none,
      padding: 0,
      videoCornerRadius: 0,
      cameraCornerRadius: 0,
      cameraBorderWidth: 0,
      cameraLayout: CameraLayout(),
      imageOverlays: overlays
    )
  }

  @Test func imageOverlayChangesAreDescribedAsAddedRemovedAdjusted() {
    let overlay = ImageOverlayData(startSeconds: 1, endSeconds: 4, filename: "image-00000000.png")
    var edited = overlay
    edited.width = 0.5
    #expect(History.describeChanges(from: imageOverlayData(nil), to: imageOverlayData([overlay])) == ["Image overlay added"])
    #expect(History.describeChanges(from: imageOverlayData([overlay]), to: imageOverlayData(nil)) == ["Image overlay removed"])
    #expect(History.describeChanges(from: imageOverlayData([overlay]), to: imageOverlayData([edited])) == ["Image overlay adjusted"])
  }
}
