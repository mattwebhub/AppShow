import Foundation
import Testing

@testable import AppShow

struct AgentToolResultTests {
  private static let media = AgentToolMediaInfo(hasWebcam: true, hasSystemAudio: true, hasMicAudio: true, hasCursorMetadata: true)

  private func fullTimeline() -> JSONValue {
    AgentToolSummaries.timeline(
      snapshot: ProjectFixtures.fullEditorState(),
      duration: 2,
      media: Self.media,
      historyIndex: 3,
      historyCount: 5
    )
  }

  @Test func timelineSummaryReflectsEveryTrackOfTheFullSnapshot() throws {
    let timeline = fullTimeline()
    #expect(timeline["duration"] == 2)
    #expect(timeline["trim"] == ["start": 0.25, "end": 1.75])
    #expect(timeline["cuts"]?["hasCuts"] == true)
    #expect(timeline["cuts"]?["keptDuration"] == 0.4)
    let slices = try #require(timeline["cuts"]?["slices"]?.arrayValue)
    #expect(slices.count == 1)
    #expect(slices[0]["id"] == .string(ProjectFixtures.fixedUUID(7).uuidString))
    #expect(slices[0]["start"] == 0.2)
    #expect(slices[0]["end"] == 0.6)
    #expect(slices[0]["entryTransition"] == "scale")
    #expect(slices[0]["exitTransition"] == "fade")
    #expect(timeline["cuts"]?["gaps"] == [["start": 0, "end": 0.2], ["start": 0.6, "end": 2]])
    #expect(timeline["zoom"]?["enabled"] == true)
    #expect(timeline["zoom"]?["autoZoom"] == true)
    #expect(timeline["zoom"]?["level"] == 2.5)
    #expect(timeline["zoom"]?["keyframes"]?.arrayValue?.count == 3)
    #expect(timeline["zoom"]?["keyframes"]?[1] == ["t": 0.5, "level": 2.5, "x": 0.3, "y": 0.7, "auto": true])
    #expect(timeline["spotlight"]?["enabled"] == true)
    #expect(timeline["spotlight"]?["regions"]?[0]?["radius"] == 120)
    #expect(timeline["spotlight"]?["regions"]?[0]?["fadeDuration"] == 0.3)
    #expect(timeline["camera"]?["present"] == true)
    #expect(timeline["camera"]?["enabled"] == true)
    let cameraRegions = try #require(timeline["camera"]?["regions"]?.arrayValue)
    #expect(cameraRegions.map { $0["type"] } == ["fullscreen", "custom", "hidden"])
    #expect(cameraRegions[0]["entryTransition"] == "fade")
    #expect(cameraRegions[2]["entryTransition"] == nil)
    #expect(timeline["captions"]?["enabled"] == true)
    #expect(timeline["captions"]?["count"] == 2)
    #expect(timeline["captions"]?["segments"]?[0]?["text"] == "hello there world")
    #expect(timeline["captions"]?["segments"]?[0]?["words"] == nil)
    #expect(timeline["audio"]?["system"] == ["present": true, "muted": true, "volume": 0.8, "regions": [["start": 0.1, "end": 0.4]]])
    #expect(timeline["audio"]?["mic"]?["muted"] == false)
    #expect(timeline["audio"]?["mic"]?["volume"] == 1.2)
    #expect(timeline["audio"]?["external"] == [])
    #expect(timeline["background"] == ["type": "solid", "color": "#19334c"])
    #expect(timeline["canvas"] == ["aspect": "ratio16x9", "padding": 0.08, "cornerRadius": 12, "shadow": 0.4])
    #expect(timeline["history"] == ["index": 3, "count": 5])
  }

  @Test func timelineSummaryOfAFreshProjectHasOneFullSliceAndNoEffects() throws {
    var snapshot = ProjectFixtures.editorState()
    snapshot.backgroundStyle = .gradient(4)
    snapshot.externalAudioTracks = [
      ExternalAudioTrackData(
        id: ProjectFixtures.fixedUUID(11),
        fileName: "audio-1.mp3",
        displayName: "Bed",
        sourceDurationSeconds: 3,
        timelineStartSeconds: 0.5,
        fileInSeconds: 0.25,
        fileOutSeconds: 1.25,
        volume: 0.6,
        muted: true,
        fadeInSeconds: 0.1,
        fadeOutSeconds: 0.2
      )
    ]
    let media = AgentToolMediaInfo(hasWebcam: false, hasSystemAudio: false, hasMicAudio: false, hasCursorMetadata: false)
    let timeline = AgentToolSummaries.timeline(snapshot: snapshot, duration: 2, media: media, historyIndex: 0, historyCount: 1)
    #expect(timeline["cuts"]?["hasCuts"] == false)
    #expect(timeline["cuts"]?["keptDuration"] == 2)
    #expect(timeline["cuts"]?["slices"]?.arrayValue?.count == 1)
    #expect(timeline["cuts"]?["slices"]?[0]?["start"] == 0)
    #expect(timeline["cuts"]?["slices"]?[0]?["end"] == 2)
    #expect(timeline["cuts"]?["gaps"] == [])
    #expect(timeline["zoom"] == ["enabled": false, "autoZoom": false, "level": 2, "keyframes": []])
    #expect(timeline["spotlight"] == ["enabled": false, "regions": []])
    #expect(timeline["camera"]?["present"] == false)
    #expect(timeline["captions"] == ["enabled": false, "count": 0, "segments": []])
    #expect(timeline["audio"]?["system"]?["present"] == false)
    #expect(timeline["background"] == ["type": "gradient", "gradientId": 4])
    let external = try #require(timeline["audio"]?["external"]?[0])
    #expect(external["name"] == "Bed")
    #expect(external["start"] == 0.5)
    #expect(external["end"] == 1.5)
    #expect(external["fileIn"] == 0.25)
    #expect(external["fileOut"] == 1.25)
    #expect(external["volume"] == 0.6)
    #expect(external["muted"] == true)
    #expect(external["fadeIn"] == 0.1)
    #expect(external["fadeOut"] == 0.2)
  }

  @Test func transcriptFiltersByWindowAndIncludesWordsOnRequest() throws {
    let segments = try #require(ProjectFixtures.fullEditorState().captionSegments)
    let plain = AgentToolSummaries.transcript(
      segments: segments,
      enabled: true,
      source: .system,
      language: .pt,
      withWords: false,
      from: nil,
      to: nil
    )
    #expect(plain["count"] == 2)
    #expect(plain["enabled"] == true)
    #expect(plain["source"] == "system")
    #expect(plain["language"] == "pt")
    #expect(plain["segments"]?[0]?["words"] == nil)
    #expect(plain["hint"] == nil)

    let withWords = AgentToolSummaries.transcript(
      segments: segments,
      enabled: true,
      source: .microphone,
      language: .auto,
      withWords: true,
      from: nil,
      to: nil
    )
    #expect(withWords["segments"]?[0]?["words"]?.arrayValue?.count == 3)
    #expect(withWords["segments"]?[0]?["words"]?[1] == ["word": "there", "start": 0.5, "end": 0.7])
    #expect(withWords["segments"]?[1]?["words"] == nil)

    let windowed = AgentToolSummaries.transcript(
      segments: segments,
      enabled: true,
      source: .microphone,
      language: .auto,
      withWords: false,
      from: 0.95,
      to: 2
    )
    #expect(windowed["count"] == 1)
    #expect(windowed["segments"]?[0]?["text"] == "no words")

    let empty = AgentToolSummaries.transcript(
      segments: [],
      enabled: false,
      source: .microphone,
      language: .en,
      withWords: true,
      from: nil,
      to: nil
    )
    #expect(empty["count"] == 0)
    #expect(empty["segments"] == [])
    #expect(empty["hint"]?.stringValue?.isEmpty == false)
  }

  @Test func clickClustersGroupClicksByDwellAndKeystrokesByBurst() throws {
    let metadata = ProjectFixtures.cursorMetadata()
    let clusters = AgentToolCursorActivity.clickClusters(clicks: metadata.clicks, dwellSeconds: 0.6, from: nil, to: nil)
    #expect(clusters.count == 2)
    #expect(clusters[0].start == 0.25)
    #expect(clusters[0].end == 0.75)
    #expect(clusters[0].clicks == 2)
    #expect(abs(clusters[0].x - (metadata.clicks[0].x + metadata.clicks[1].x) / 2) < 1e-9)
    #expect(clusters[1].clicks == 1)
    #expect(clusters[1].start == 1.5)

    let tight = AgentToolCursorActivity.clickClusters(clicks: metadata.clicks, dwellSeconds: 0.2, from: nil, to: nil)
    #expect(tight.count == 3)

    let windowed = AgentToolCursorActivity.clickClusters(clicks: metadata.clicks, dwellSeconds: 0.6, from: 0.5, to: 2)
    #expect(windowed.map(\.start) == [0.75, 1.5])

    let bursts = AgentToolCursorActivity.keystrokeBursts(keystrokes: metadata.keystrokes, gapSeconds: 1, from: nil, to: nil)
    #expect(bursts.count == 1)
    #expect(bursts[0].count == 6)
    #expect(abs(bursts[0].start - 1.0) < 1e-9)
    #expect(abs(bursts[0].end - 1.25) < 1e-9)

    let summary = AgentToolCursorActivity.summary(metadata: metadata, dwellSeconds: 0.6, from: nil, to: nil)
    #expect(summary["available"] == true)
    #expect(summary["sampleRateHz"] == 120)
    #expect(summary["clickCount"] == 3)
    #expect(summary["clickClusters"]?.arrayValue?.count == 2)
    #expect(summary["clickClusters"]?[0]?["clicks"] == 2)
    #expect(summary["keystrokeBursts"]?[0]?["count"] == 6)

    let missing = AgentToolCursorActivity.summary(metadata: nil, dwellSeconds: 0.5, from: nil, to: nil)
    #expect(missing == ["available": false, "clickCount": 0, "clickClusters": [], "keystrokeBursts": []])
  }

  @Test @MainActor func historySummaryDescribesEachStepAndMarksTheCurrentOne() throws {
    let history = History()
    history.pushSnapshot(ProjectFixtures.editorState(marker: 0))
    history.pushSnapshot(ProjectFixtures.editorState(marker: 0.5))
    var third = ProjectFixtures.editorState(marker: 0.5)
    third.padding = 0.1
    history.pushSnapshot(third)
    _ = history.undo()

    let summary = AgentToolSummaries.history(entries: history.entries, currentIndex: history.currentIndex)
    #expect(summary["count"] == 3)
    #expect(summary["index"] == 1)
    #expect(summary["canUndo"] == true)
    #expect(summary["canRedo"] == true)
    let entries = try #require(summary["entries"]?.arrayValue)
    #expect(entries[0]["label"] == "Initial state")
    #expect(entries[0]["changes"] == ["Initial state"])
    #expect(entries[1]["label"]?.stringValue?.hasPrefix("Trim range") == true)
    #expect(entries[2]["label"] == "Padding set to 10%")
    #expect(entries.map { $0["isCurrent"] } == [false, true, false])
    #expect(entries.map { $0["index"] } == [0, 1, 2])
    #expect(entries[0]["timestamp"]?.stringValue?.contains("T") == true)
  }

  @Test func mcpResultWrapsJSONAsTextAndStructuredContent() throws {
    let success = AgentToolResult.success(["a": 1, "b": ["c"]])
    #expect(success.isError == false)
    let wrapped = success.mcpValue
    #expect(wrapped["isError"] == false)
    #expect(wrapped["structuredContent"] == ["a": 1, "b": ["c"]])
    #expect(wrapped["content"] == [["type": "text", "text": #"{"a":1,"b":["c"]}"#]])

    let failure = AgentToolResult.failure("Render failed")
    #expect(failure.isError)
    #expect(failure.mcpValue["isError"] == true)
    #expect(failure.mcpValue["structuredContent"] == nil)
    #expect(failure.mcpValue["content"]?[0]?["text"] == "Render failed")
  }
}
