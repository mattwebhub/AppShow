import Foundation
import Testing

@testable import Reframed

struct ProjectMetadataTests {
  private func projectDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }

  private func projectEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return encoder
  }

  private func decodeLegacy(_ json: String) throws -> ProjectMetadata {
    try projectDecoder().decode(ProjectMetadata.self, from: Data(json.utf8))
  }

  @Test func legacyProjectDecodesWithDeclaredDefaults() throws {
    let metadata = try decodeLegacy(ProjectFixtures.legacyV1ProjectJSON())
    #expect(metadata.version == 1)
    #expect(metadata.name == "Screen-2024-01-15-101010")
    #expect(metadata.createdAt == Date(timeIntervalSince1970: 1_705_313_410))
    #expect(metadata.fps == 60)
    #expect(metadata.screenSize.cgSize == CGSize(width: 1728, height: 1117))
    #expect(metadata.webcamSize == nil)
    #expect(metadata.hasSystemAudio == true)
    #expect(metadata.hasMicrophoneAudio == false)
    #expect(metadata.hasCursorMetadata == false)
    #expect(metadata.hasWebcam == false)
    #expect(metadata.captureMode == nil)
    #expect(metadata.captureQuality == nil)
    #expect(metadata.isHDR == false)
  }

  @Test func legacyEditorStateDecodesWithNestedDefaults() throws {
    let metadata = try decodeLegacy(ProjectFixtures.legacyV1ProjectJSON())
    let state = try #require(metadata.editorState)
    #expect(state.trimStartSeconds == 0.5)
    #expect(state.trimEndSeconds == 12.5)
    #expect(state.backgroundStyle == .gradient(2))
    #expect(state.backgroundImageFillMode == nil)
    #expect(state.canvasAspect == nil)
    #expect(state.cameraAspect == nil)
    #expect(state.cameraBorderColor == nil)
    #expect(state.webcamEnabled == nil)
    #expect(state.animationSettings == nil)
    #expect(state.audioSettings == nil)
    #expect(state.cameraRegions == nil)
    #expect(state.videoRegions == nil)
    #expect(state.captionSettings == nil)
    #expect(state.captionSegments == nil)
    #expect(state.spotlightRegions == nil)
    #expect(state.cameraBackgroundStyle == nil)
    let cursor = try #require(state.cursorSettings)
    #expect(cursor.showCursor == true)
    #expect(cursor.cursorStyleRaw == 0)
    #expect(cursor.cursorSize == 1.5)
    #expect(cursor.cursorFillColor == nil)
    #expect(cursor.showClickHighlights == true)
    #expect(cursor.clickHighlightColor == nil)
    #expect(cursor.clickHighlightSize == 36)
    #expect(cursor.spotlightEnabled == false)
    #expect(cursor.spotlightRadius == 200)
    #expect(cursor.spotlightDimOpacity == 0.6)
    #expect(cursor.spotlightEdgeSoftness == 50)
    #expect(cursor.clickSoundEnabled == false)
    #expect(cursor.clickSoundVolume == 0.5)
    #expect(cursor.clickSoundStyleRaw == 0)
    let zoom = try #require(state.zoomSettings)
    #expect(zoom.zoomEnabled == false)
    #expect(zoom.autoZoomEnabled == false)
    #expect(zoom.zoomFollowCursor == true)
    #expect(zoom.zoomLevel == 2)
    #expect(zoom.keyframes.isEmpty)
  }

  @Test func legacyCaptionPositionStringDecodesToPreset() throws {
    let json = ProjectFixtures.legacyV1ProjectJSON(editorStateExtras: ProjectFixtures.legacyCaptionSettingsJSON)
    let metadata = try decodeLegacy(json)
    let captions = try #require(metadata.editorState?.captionSettings)
    #expect(captions.position == .top)
    #expect(captions.fontSize == 40)
    #expect(captions.fontWeight == .bold)
    #expect(captions.maxWordsPerLine == 6)
    #expect(captions.model == "openai_whisper-base")
    #expect(captions.language == .auto)
    #expect(captions.audioSource == .microphone)
  }

  @Test(arguments: [("top", CaptionPosition.top), ("center", .center), ("bottom", .bottom), ("sideways", .bottom)])
  func captionPositionStringFormMapsToPreset(raw: String, expected: CaptionPosition) throws {
    let decoded = try JSONDecoder().decode(CaptionPosition.self, from: Data("\"\(raw)\"".utf8))
    #expect(decoded == expected)
  }

  @Test func captionPositionObjectFormIsClamped() throws {
    let decoded = try JSONDecoder().decode(CaptionPosition.self, from: Data(#"{"relativeX": 1.5, "relativeY": -0.2}"#.utf8))
    #expect(decoded == CaptionPosition(relativeX: 1, relativeY: 0))
  }

  @Test func unknownBackgroundStyleTypeDecodesToNone() throws {
    let styleJSON = Data(#"{"type": "plasma", "gradientId": 7}"#.utf8)
    #expect(try JSONDecoder().decode(BackgroundStyle.self, from: styleJSON) == BackgroundStyle.none)
    let projectJSON = ProjectFixtures.legacyV1ProjectJSON().replacingOccurrences(of: "\"type\": \"gradient\"", with: "\"type\": \"plasma\"")
    let metadata = try decodeLegacy(projectJSON)
    #expect(metadata.editorState?.backgroundStyle == BackgroundStyle.none)
  }

  @Test func unknownCameraBackgroundStyleTypeDecodesToNone() throws {
    let json = Data(#"{"type": "hologram", "intensity": 0.5}"#.utf8)
    #expect(try JSONDecoder().decode(CameraBackgroundStyle.self, from: json) == CameraBackgroundStyle.none)
  }

  @Test func editorStateRoundTripPreservesEveryField() throws {
    let original = ProjectFixtures.fullEditorState()
    let metadata = ProjectMetadata(
      name: "Round Trip",
      createdAt: Date(timeIntervalSince1970: 1_700_000_000),
      fps: 30,
      screenSize: CodableSize(VideoFixtures.screenSize),
      webcamSize: CodableSize(VideoFixtures.webcamSize),
      hasSystemAudio: true,
      hasMicrophoneAudio: true,
      hasCursorMetadata: true,
      hasWebcam: true,
      captureMode: .selectedArea,
      captureQuality: "high",
      isHDR: true,
      editorState: original
    )
    let data = try projectEncoder().encode(metadata)
    let decoded = try projectDecoder().decode(ProjectMetadata.self, from: data)
    #expect(decoded.version == 1)
    #expect(decoded.name == "Round Trip")
    #expect(decoded.createdAt == metadata.createdAt)
    #expect(decoded.fps == 30)
    #expect(decoded.screenSize.cgSize == VideoFixtures.screenSize)
    #expect(decoded.webcamSize?.cgSize == VideoFixtures.webcamSize)
    #expect(decoded.hasSystemAudio == true)
    #expect(decoded.hasMicrophoneAudio == true)
    #expect(decoded.hasCursorMetadata == true)
    #expect(decoded.hasWebcam == true)
    #expect(decoded.captureMode == .selectedArea)
    #expect(decoded.captureQuality == "high")
    #expect(decoded.isHDR == true)
    let state = try #require(decoded.editorState)
    #expect(state.trimStartSeconds == original.trimStartSeconds)
    #expect(state.trimEndSeconds == original.trimEndSeconds)
    #expect(state.backgroundStyle == original.backgroundStyle)
    #expect(state.backgroundImageFillMode == original.backgroundImageFillMode)
    #expect(state.canvasAspect == original.canvasAspect)
    #expect(state.padding == original.padding)
    #expect(state.videoCornerRadius == original.videoCornerRadius)
    #expect(state.cameraAspect == original.cameraAspect)
    #expect(state.cameraCornerRadius == original.cameraCornerRadius)
    #expect(state.cameraBorderWidth == original.cameraBorderWidth)
    #expect(state.cameraBorderColor == original.cameraBorderColor)
    #expect(state.videoShadow == original.videoShadow)
    #expect(state.cameraShadow == original.cameraShadow)
    #expect(state.cameraMirrored == original.cameraMirrored)
    #expect(state.cameraFullscreenFillMode == original.cameraFullscreenFillMode)
    #expect(state.cameraFullscreenAspect == original.cameraFullscreenAspect)
    #expect(state.cameraLayout == original.cameraLayout)
    #expect(state.webcamEnabled == original.webcamEnabled)
    #expect(state.cursorSettings == original.cursorSettings)
    #expect(state.zoomSettings == original.zoomSettings)
    #expect(state.zoomSettings?.keyframes.count == 3)
    #expect(state.animationSettings == original.animationSettings)
    #expect(state.audioSettings == original.audioSettings)
    #expect(state.systemAudioRegions == original.systemAudioRegions)
    #expect(state.micAudioRegions == original.micAudioRegions)
    #expect(state.cameraRegions == original.cameraRegions)
    #expect(state.cameraRegions?[1].customLayout == CameraLayout(relativeX: 0.1, relativeY: 0.15, relativeWidth: 0.35))
    #expect(state.cameraFullscreenRegions == original.cameraFullscreenRegions)
    #expect(state.videoRegions == original.videoRegions)
    #expect(state.cameraBackgroundStyle == original.cameraBackgroundStyle)
    #expect(state.captionSettings == original.captionSettings)
    #expect(state.captionSegments == original.captionSegments)
    #expect(state.captionSegments?[0].words?.count == 3)
    #expect(state.captionSegments?[1].words == nil)
    #expect(state.spotlightRegions == original.spotlightRegions)
    #expect(state.spotlightRegions?[0].fadeDuration == 0.3)
  }

  @Test func roundTripIsByteStableOnReencode() throws {
    let metadata = ProjectMetadata(
      name: "Stable",
      createdAt: Date(timeIntervalSince1970: 1_700_000_000),
      fps: 30,
      screenSize: CodableSize(VideoFixtures.screenSize),
      hasSystemAudio: false,
      hasMicrophoneAudio: false,
      editorState: ProjectFixtures.fullEditorState()
    )
    let first = try projectEncoder().encode(metadata)
    let decoded = try projectDecoder().decode(ProjectMetadata.self, from: first)
    let second = try projectEncoder().encode(decoded)
    #expect(first == second)
  }
}
