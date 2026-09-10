import CoreMedia
import Foundation
import Testing

@testable import AppShow

@MainActor
@Suite(.serialized)
struct EditorStateImageOverlaysTests {
  private func makeProject(in dir: URL) async throws -> AppShowProject {
    let sources = dir.appendingPathComponent("sources", isDirectory: true)
    try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)
    let screenURL = try await VideoFixtures.screenMovie(duration: 6, container: .mov, in: sources, name: "screen-6s")
    let result = RecordingResult(
      screenVideoURL: screenURL,
      webcamVideoURL: nil,
      systemAudioURL: nil,
      microphoneAudioURL: nil,
      cursorMetadataURL: nil,
      screenSize: VideoFixtures.screenSize,
      webcamSize: nil,
      fps: VideoFixtures.fps,
      captureQuality: .standard,
      isHDR: false
    )
    let projects = dir.appendingPathComponent("projects", isDirectory: true)
    return try AppShowProject.create(from: result, fps: result.fps, captureMode: .entireScreen, in: projects, cleanupTemp: false)
  }

  private func makeState() async throws -> (EditorState, URL, URL) {
    let dir = try TestPaths.makeTemporaryDirectory()
    let project = try await makeProject(in: dir)
    let state = EditorState(project: project)
    await state.setup()
    let png = try ImageFixtures.solidPNG(width: 16, height: 8, in: dir, name: "logo.png")
    return (state, dir, png)
  }

  private func near(_ a: Double, _ b: Double, tolerance: Double = 0.01) -> Bool {
    abs(a - b) <= tolerance
  }

  private func bundleImageFiles(_ state: EditorState) throws -> [String] {
    let bundle = try #require(state.project?.bundleURL)
    return try FileManager.default.contentsOfDirectory(atPath: bundle.path).filter { $0.hasPrefix("image-") }
  }

  @Test func addOverlayFromFileCreatesThreeSecondRegionWithTheFileInTheBundle() async throws {
    let (state, dir, png) = try await makeState()
    defer { TestPaths.remove(dir) }
    #expect(state.imageOverlays.isEmpty)
    #expect(!state.showOverlayTrack)

    let added = try #require(state.addImageOverlay(from: png, atTime: 1.0))

    #expect(state.imageOverlays.count == 1)
    #expect(state.showOverlayTrack)
    #expect(near(added.startSeconds, 1.0))
    #expect(near(added.endSeconds, 4.0))
    #expect(added.filename.hasPrefix("image-"))
    #expect(added.filename.hasSuffix(".png"))
    #expect(added.sourceName == "logo.png")
    #expect(added.aspectRatio == 2)
    #expect(added.width == ImageOverlayData.defaultWidth)
    #expect(added.position == .center)
    #expect(try bundleImageFiles(state) == [added.filename])
    let url = try #require(state.imageOverlayURL(added))
    #expect(url.lastPathComponent == added.filename)
    #expect(FileManager.default.fileExists(atPath: url.path))
    #expect(state.activeImageOverlays(at: 2.0).map(\.id) == [added.id])
    #expect(state.activeImageOverlays(at: 5.0).isEmpty)
  }

  @Test func addOverlayNearEndIsPulledBackAndClamped() async throws {
    let (state, dir, png) = try await makeState()
    defer { TestPaths.remove(dir) }
    let duration = CMTimeGetSeconds(state.duration)

    let added = try #require(state.addImageOverlay(from: png, atTime: duration - 1.0))

    #expect(near(added.startSeconds, duration - 3.0))
    #expect(near(added.endSeconds, duration))

    let late = try #require(state.addImageOverlay(from: png, atTime: duration + 5))
    #expect(near(late.endSeconds, duration))
    #expect(near(late.startSeconds, duration - 3.0))
    #expect(late.filename == added.filename)
    #expect(try bundleImageFiles(state).count == 1)
  }

  @Test func addOverlayFromAnUnreadableFileAddsNothing() async throws {
    let (state, dir, _) = try await makeState()
    defer { TestPaths.remove(dir) }
    let fake = dir.appendingPathComponent("fake.png")
    try Data("not an image".utf8).write(to: fake)

    #expect(state.addImageOverlay(from: fake, atTime: 0) == nil)

    #expect(state.imageOverlays.isEmpty)
    #expect(try bundleImageFiles(state).isEmpty)
  }

  @Test func updateOverlayChangesFields() async throws {
    let (state, dir, png) = try await makeState()
    defer { TestPaths.remove(dir) }
    let added = try #require(state.addImageOverlay(from: png, atTime: 0))

    state.updateImageOverlay(id: added.id) { overlay in
      overlay.width = 0.5
      overlay.position = .topLeft
      overlay.cornerRadius = 0.3
      overlay.opacity = 0.4
      overlay.shadow = 25
      overlay.entryTransition = .slide
      overlay.startSeconds = 99
    }

    let updated = try #require(state.imageOverlays.first)
    #expect(updated.id == added.id)
    #expect(updated.width == 0.5)
    #expect(updated.position == .topLeft)
    #expect(updated.cornerRadius == 0.3)
    #expect(updated.opacity == 0.4)
    #expect(updated.shadow == 25)
    #expect(updated.entryTransition == .slide)
    #expect(near(updated.startSeconds, added.startSeconds))
    #expect(near(updated.endSeconds, added.endSeconds))
  }

  @Test func moveAndResizeClampToDurationAndMinimumLength() async throws {
    let (state, dir, png) = try await makeState()
    defer { TestPaths.remove(dir) }
    let duration = CMTimeGetSeconds(state.duration)
    let added = try #require(state.addImageOverlay(from: png, atTime: 1.0))

    state.moveImageOverlay(id: added.id, newStart: -1)
    #expect(near(state.imageOverlays[0].startSeconds, 0))
    #expect(near(state.imageOverlays[0].endSeconds, 3))

    state.moveImageOverlay(id: added.id, newStart: 100)
    #expect(near(state.imageOverlays[0].endSeconds, duration))
    #expect(near(state.imageOverlays[0].startSeconds, duration - 3))

    state.updateImageOverlayStart(id: added.id, newStart: 100)
    #expect(near(state.imageOverlays[0].startSeconds, duration - ImageOverlayData.minimumLength))

    state.updateImageOverlayEnd(id: added.id, newEnd: -5)
    #expect(near(state.imageOverlays[0].endSeconds, state.imageOverlays[0].startSeconds + ImageOverlayData.minimumLength))

    state.updateImageOverlayEnd(id: added.id, newEnd: 100)
    #expect(near(state.imageOverlays[0].endSeconds, duration))

    state.updateImageOverlayStart(id: added.id, newStart: -3)
    #expect(near(state.imageOverlays[0].startSeconds, 0))
  }

  @Test func overlaysAreKeptSortedByStart() async throws {
    let (state, dir, png) = try await makeState()
    defer { TestPaths.remove(dir) }
    let first = try #require(state.addImageOverlay(from: png, atTime: 2.0))
    let second = try #require(state.addImageOverlay(from: png, atTime: 0.5))

    #expect(state.imageOverlays.map(\.id) == [second.id, first.id])
    state.moveImageOverlay(id: second.id, newStart: 2.5)
    #expect(state.imageOverlays.map(\.id) == [first.id, second.id])
  }

  @Test func removeOverlayKeepsTheFile() async throws {
    let (state, dir, png) = try await makeState()
    defer { TestPaths.remove(dir) }
    let first = try #require(state.addImageOverlay(from: png, atTime: 0))
    let second = try #require(state.addImageOverlay(from: png, atTime: 1))

    state.removeImageOverlay(id: first.id)

    #expect(state.imageOverlays.map(\.id) == [second.id])
    state.removeImageOverlay(id: second.id)
    #expect(state.imageOverlays.isEmpty)
    #expect(!state.showOverlayTrack)
    #expect(try bundleImageFiles(state) == [first.filename])
  }

  @Test func snapshotRoundTripRestoresOverlays() async throws {
    let (state, dir, png) = try await makeState()
    defer { TestPaths.remove(dir) }
    #expect(state.createSnapshot().imageOverlays == nil)

    let added = try #require(state.addImageOverlay(from: png, atTime: 0.5))
    state.updateImageOverlay(id: added.id) { $0.width = 0.2 }
    let snapshot = state.createSnapshot()
    #expect(snapshot.imageOverlays?.count == 1)

    state.removeImageOverlay(id: added.id)
    #expect(state.imageOverlays.isEmpty)

    state.restoreFromSnapshot(snapshot)
    #expect(state.imageOverlays.count == 1)
    #expect(state.imageOverlays[0].id == added.id)
    #expect(state.imageOverlays[0].width == 0.2)

    var empty = snapshot
    empty.imageOverlays = nil
    state.restoreFromSnapshot(empty)
    #expect(state.imageOverlays.isEmpty)
  }

  @Test func reopeningDropsOverlaysWhoseFileIsMissing() async throws {
    let (state, dir, png) = try await makeState()
    defer { TestPaths.remove(dir) }
    let kept = try #require(state.addImageOverlay(from: png, atTime: 0.5))
    var missing = kept
    missing.id = ProjectFixtures.fixedUUID(3)
    missing.filename = "image-ffffffff.png"
    missing.startSeconds = 2
    missing.endSeconds = 4
    state.imageOverlays.append(missing)
    let project = try #require(state.project)
    try project.saveEditorState(state.createSnapshot())

    let reopened = EditorState(project: try AppShowProject.open(at: project.bundleURL))
    await reopened.setup()

    #expect(reopened.imageOverlays.map(\.id) == [kept.id])
    #expect(reopened.showOverlayTrack)
  }

  @Test func overlayTrackShowsForImageOverlaysAlone() async throws {
    let (state, dir, png) = try await makeState()
    defer { TestPaths.remove(dir) }
    #expect(!state.showOverlayTrack)

    let image = try #require(state.addImageOverlay(from: png, atTime: 0))
    #expect(state.showOverlayTrack)
    let text = try #require(state.addTextOverlay(atTime: 0))
    state.removeImageOverlay(id: image.id)
    #expect(state.showOverlayTrack)
    state.removeTextOverlay(id: text.id)
    #expect(!state.showOverlayTrack)
  }
}
