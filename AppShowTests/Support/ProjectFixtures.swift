import CoreGraphics
import Foundation

@testable import AppShow

enum ProjectFixtures {
  static func legacyV1ProjectJSON(editorStateExtras: String = "") -> String {
    let extras = editorStateExtras.isEmpty ? "" : ",\n\(editorStateExtras)"
    return """
      {
        "version": 1,
        "name": "Screen-2024-01-15-101010",
        "createdAt": "2024-01-15T10:10:10Z",
        "fps": 60,
        "screenSize": { "width": 1728, "height": 1117 },
        "hasSystemAudio": true,
        "hasMicrophoneAudio": false,
        "editorState": {
          "trimStartSeconds": 0.5,
          "trimEndSeconds": 12.5,
          "backgroundStyle": { "type": "gradient", "gradientId": 2 },
          "padding": 0.05,
          "videoCornerRadius": 8,
          "cameraCornerRadius": 12,
          "cameraBorderWidth": 0,
          "cameraLayout": { "relativeX": 0.02, "relativeY": 0.02, "relativeWidth": 0.25 },
          "cursorSettings": { "showCursor": true, "cursorStyleRaw": 0, "cursorSize": 1.5 },
          "zoomSettings": {
            "autoZoomEnabled": false,
            "zoomLevel": 2,
            "transitionDuration": 0.5,
            "dwellThreshold": 1,
            "keyframes": []
          }\(extras)
        }
      }
      """
  }

  static let legacyCaptionSettingsJSON = """
    "captionSettings": { "enabled": true, "fontSize": 40, "position": "top" }
    """

  static func fixedUUID(_ n: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))!
  }

  static func editorState(marker: Double = 0) -> EditorStateData {
    EditorStateData(
      trimStartSeconds: marker,
      trimEndSeconds: 2,
      backgroundStyle: .none,
      padding: 0,
      videoCornerRadius: 0,
      cameraCornerRadius: 0,
      cameraBorderWidth: 0,
      cameraLayout: CameraLayout()
    )
  }

  static func fullEditorState() -> EditorStateData {
    EditorStateData(
      trimStartSeconds: 0.25,
      trimEndSeconds: 1.75,
      backgroundStyle: .solidColor(CodableColor(r: 0.1, g: 0.2, b: 0.3, a: 1)),
      backgroundImageFillMode: .fit,
      canvasAspect: .ratio16x9,
      padding: 0.08,
      videoCornerRadius: 12,
      cameraAspect: .ratio1x1,
      cameraCornerRadius: 16,
      cameraBorderWidth: 3,
      cameraBorderColor: CodableColor(r: 0.9, g: 0.8, b: 0.7, a: 0.5),
      videoShadow: 0.4,
      cameraShadow: 0.6,
      cameraMirrored: true,
      cameraFullscreenFillMode: .fill,
      cameraFullscreenAspect: .ratio4x3,
      cameraLayout: CameraLayout(relativeX: 0.7, relativeY: 0.65, relativeWidth: 0.2),
      webcamEnabled: true,
      cursorSettings: CursorSettingsData(
        showCursor: true,
        cursorStyleRaw: 2,
        cursorSize: 1.75,
        cursorFillColor: CodableColor(r: 1, g: 0, b: 0, a: 1),
        cursorStrokeColor: CodableColor(r: 0, g: 0, b: 1, a: 1),
        showClickHighlights: false,
        clickHighlightColor: CodableColor(r: 0, g: 1, b: 0, a: 0.8),
        clickHighlightSize: 48,
        spotlightEnabled: true,
        spotlightRadius: 150,
        spotlightDimOpacity: 0.7,
        spotlightEdgeSoftness: 30,
        clickSoundEnabled: true,
        clickSoundVolume: 0.25,
        clickSoundStyleRaw: 1
      ),
      zoomSettings: ZoomSettingsData(
        zoomEnabled: true,
        autoZoomEnabled: true,
        zoomFollowCursor: false,
        zoomLevel: 2.5,
        transitionDuration: 0.4,
        dwellThreshold: 0.8,
        keyframes: [
          ZoomKeyframe(t: 0, zoomLevel: 1, centerX: 0.5, centerY: 0.5, isAuto: false),
          ZoomKeyframe(t: 0.5, zoomLevel: 2.5, centerX: 0.3, centerY: 0.7, isAuto: true),
          ZoomKeyframe(t: 1.5, zoomLevel: 1, centerX: 0.5, centerY: 0.5, isAuto: true),
        ]
      ),
      animationSettings: AnimationSettingsData(
        cursorMovementEnabled: true,
        cursorMovementSpeed: .rapid,
        useSystemCursor: false,
        cursorSway: 0.3,
        cursorMotionBlur: 0.2,
        clickBounce: 0.5
      ),
      audioSettings: AudioSettingsData(
        systemAudioVolume: 0.8,
        micAudioVolume: 1.2,
        systemAudioMuted: true,
        micAudioMuted: false,
        micNoiseReductionEnabled: true,
        micNoiseReductionIntensity: 0.9,
        cachedNoiseReductionIntensity: 0.9
      ),
      systemAudioRegions: [AudioRegionData(id: fixedUUID(1), startSeconds: 0.1, endSeconds: 0.4)],
      micAudioRegions: [AudioRegionData(id: fixedUUID(2), startSeconds: 0.5, endSeconds: 0.9)],
      cameraRegions: [
        CameraRegionData(
          id: fixedUUID(3),
          startSeconds: 0,
          endSeconds: 0.5,
          type: .fullscreen,
          entryTransition: .fade,
          entryTransitionDuration: 0.2,
          exitTransition: .scale,
          exitTransitionDuration: 0.3
        ),
        CameraRegionData(
          id: fixedUUID(4),
          startSeconds: 0.5,
          endSeconds: 1.2,
          type: .custom,
          customLayout: CameraLayout(relativeX: 0.1, relativeY: 0.15, relativeWidth: 0.35),
          customCameraAspect: .ratio9x16,
          customCornerRadius: 24,
          customShadow: 0.3,
          customBorderWidth: 5,
          customBorderColor: CodableColor(r: 0.2, g: 0.4, b: 0.6, a: 1),
          customMirrored: false,
          entryTransition: .slide,
          entryTransitionDuration: 0.25,
          exitTransition: RegionTransitionType.none,
          exitTransitionDuration: 0
        ),
        CameraRegionData(id: fixedUUID(5), startSeconds: 1.2, endSeconds: 1.75, type: .hidden),
      ],
      cameraFullscreenRegions: [AudioRegionData(id: fixedUUID(6), startSeconds: 1.0, endSeconds: 1.1)],
      videoRegions: [
        VideoRegionData(
          id: fixedUUID(7),
          startSeconds: 0.2,
          endSeconds: 0.6,
          entryTransition: .scale,
          entryTransitionDuration: 0.15,
          exitTransition: .fade,
          exitTransitionDuration: 0.35
        )
      ],
      cameraBackgroundStyle: .blur(0.5),
      captionSettings: CaptionSettingsData(
        enabled: true,
        fontSize: 36,
        fontWeight: .semibold,
        textColor: CodableColor(r: 1, g: 1, b: 0, a: 1),
        backgroundColor: CodableColor(r: 0.1, g: 0.1, b: 0.1, a: 1),
        backgroundOpacity: 0.4,
        showBackground: false,
        position: .top,
        maxWordsPerLine: 4,
        model: "openai_whisper-small",
        language: .pt,
        audioSource: .system
      ),
      captionSegments: [
        CaptionSegment(
          id: fixedUUID(8),
          startSeconds: 0.3,
          endSeconds: 0.9,
          text: "hello there world",
          words: [
            CaptionWord(word: "hello", startSeconds: 0.3, endSeconds: 0.5),
            CaptionWord(word: "there", startSeconds: 0.5, endSeconds: 0.7),
            CaptionWord(word: "world", startSeconds: 0.7, endSeconds: 0.9),
          ]
        ),
        CaptionSegment(id: fixedUUID(9), startSeconds: 1.0, endSeconds: 1.4, text: "no words"),
      ],
      spotlightRegions: [
        SpotlightRegionData(
          id: fixedUUID(10),
          startSeconds: 0.4,
          endSeconds: 1.1,
          customRadius: 120,
          customDimOpacity: 0.55,
          customEdgeSoftness: 20,
          fadeDuration: 0.3
        )
      ]
    )
  }

  static func cursorMetadata(
    duration: Double = 2,
    sampleRateHz: Int = 120,
    captureSize: CGSize = VideoFixtures.screenSize,
    displayScale: Double = 2
  ) -> CursorMetadataFile {
    let count = Int(duration * Double(sampleRateHz))
    let samples = (0..<count).map { i -> CursorSample in
      let t = Double(i) / Double(sampleRateHz)
      let progress = t / duration
      return CursorSample(t: t, x: 0.1 + 0.8 * progress, y: 0.2 + 0.6 * progress, p: i % 40 < 3, c: i < count / 2 ? 0 : 1)
    }
    let clicks = [0.25, 0.75, 1.5].map { t in
      let progress = t / duration
      return CursorClickEvent(t: t, x: 0.1 + 0.8 * progress, y: 0.2 + 0.6 * progress, button: 0)
    }
    let keystrokes = (0..<6).flatMap { i -> [KeystrokeEvent] in
      let t = 1.0 + Double(i) * 0.05
      let code = UInt16(0 + i)
      return [
        KeystrokeEvent(t: t, keyCode: code, modifiers: 0, isDown: true),
        KeystrokeEvent(t: t + 0.02, keyCode: code, modifiers: 0, isDown: false),
      ]
    }
    return CursorMetadataFile(
      captureAreaWidth: captureSize.width,
      captureAreaHeight: captureSize.height,
      displayScale: displayScale,
      sampleRateHz: sampleRateHz,
      samples: samples,
      clicks: clicks,
      keystrokes: keystrokes
    )
  }

  @discardableResult
  static func writeCursorMetadata(
    _ file: CursorMetadataFile = cursorMetadata(),
    in directory: URL,
    name: String = "cursor-metadata"
  ) throws -> URL {
    let url = directory.appendingPathComponent("\(name).json")
    try JSONEncoder().encode(file).write(to: url)
    return url
  }

  static func recordingResult(
    in directory: URL,
    screenContainer: VideoFixtures.Container = .mov,
    webcam: Bool = true,
    systemAudio: Bool = true,
    microphone: Bool = true,
    cursor: Bool = true,
    captureQuality: CaptureQuality = .standard,
    isHDR: Bool = false
  ) async throws -> RecordingResult {
    let screenURL = try await VideoFixtures.screenMovie(container: screenContainer, in: directory, name: "video-fixture")
    let webcamURL = webcam ? try await VideoFixtures.webcamMovie(in: directory, name: "webcam-fixture") : nil
    let systemURL =
      systemAudio ? try AudioFixtures.sineWave(frequency: 880, channels: 2, container: .m4a, in: directory, name: "system") : nil
    let micURL = microphone ? try AudioFixtures.sineWave(frequency: 440, container: .m4a, in: directory, name: "mic") : nil
    let cursorURL = cursor ? try writeCursorMetadata(in: directory, name: "cursor-fixture") : nil
    return RecordingResult(
      screenVideoURL: screenURL,
      webcamVideoURL: webcamURL,
      systemAudioURL: systemURL,
      microphoneAudioURL: micURL,
      cursorMetadataURL: cursorURL,
      screenSize: VideoFixtures.screenSize,
      webcamSize: webcam ? VideoFixtures.webcamSize : nil,
      fps: VideoFixtures.fps,
      captureQuality: captureQuality,
      isHDR: isHDR
    )
  }
}
