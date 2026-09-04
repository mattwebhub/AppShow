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
}
