import Foundation
import Testing

@testable import AppShow

@MainActor
struct HistoryTests {
  private func markers(_ history: History) -> [Double] {
    history.entries.map(\.snapshot.trimStartSeconds)
  }

  private func push(_ history: History, _ markers: ClosedRange<Int>) {
    for i in markers {
      history.pushSnapshot(ProjectFixtures.editorState(marker: Double(i)))
    }
  }

  @Test func freshHistoryCannotUndoOrRedo() {
    let history = History()
    #expect(history.currentIndex == -1)
    #expect(history.canUndo == false)
    #expect(history.canRedo == false)
    #expect(history.undo() == nil)
    #expect(history.redo() == nil)
  }

  @Test func undoAndRedoWalkTheStack() {
    let history = History()
    push(history, 0...2)
    #expect(history.currentIndex == 2)
    #expect(history.undo()?.trimStartSeconds == 1)
    #expect(history.undo()?.trimStartSeconds == 0)
    #expect(history.canUndo == false)
    #expect(history.undo() == nil)
    #expect(history.redo()?.trimStartSeconds == 1)
    #expect(history.redo()?.trimStartSeconds == 2)
    #expect(history.canRedo == false)
    #expect(history.redo() == nil)
  }

  @Test func pushAfterUndoTruncatesRedoStack() {
    let history = History()
    push(history, 0...2)
    _ = history.undo()
    #expect(history.canRedo)
    history.pushSnapshot(ProjectFixtures.editorState(marker: 3))
    #expect(markers(history) == [0, 1, 3])
    #expect(history.currentIndex == 2)
    #expect(history.canRedo == false)
    #expect(history.redo() == nil)
  }

  @Test func pushBeyondCapKeepsNewestAndShiftsIndex() {
    let history = History()
    push(history, 0...54)
    #expect(history.entries.count == 50)
    #expect(markers(history).first == 5)
    #expect(markers(history).last == 54)
    #expect(history.currentIndex == 49)
    #expect(history.canRedo == false)
    #expect(history.undo()?.trimStartSeconds == 53)
  }

  @Test func jumpToOutOfRangeReturnsNilAndKeepsIndex() {
    let history = History()
    push(history, 0...2)
    #expect(history.jumpTo(index: 3) == nil)
    #expect(history.jumpTo(index: -1) == nil)
    #expect(history.currentIndex == 2)
    #expect(history.jumpTo(index: 0)?.trimStartSeconds == 0)
    #expect(history.currentIndex == 0)
  }

  @Test func loadClampsIndexAboveRange() {
    let history = History()
    let entries = (0..<3).map { HistoryEntry(snapshot: ProjectFixtures.editorState(marker: Double($0)), timestamp: Date()) }
    history.load(from: HistoryData(entries: entries, currentIndex: 10))
    #expect(history.currentIndex == 2)
    #expect(history.canRedo == false)
    #expect(history.undo()?.trimStartSeconds == 1)
  }

  @Test func loadClampsNegativeIndexToZero() {
    let history = History()
    let entries = (0..<3).map { HistoryEntry(snapshot: ProjectFixtures.editorState(marker: Double($0)), timestamp: Date()) }
    history.load(from: HistoryData(entries: entries, currentIndex: -5))
    #expect(history.currentIndex == 0)
    #expect(history.canUndo == false)
    #expect(history.redo()?.trimStartSeconds == 1)
  }

  @Test func loadEmptyDataLeavesHistoryEmpty() {
    let history = History()
    push(history, 0...1)
    history.load(from: HistoryData(entries: [], currentIndex: 4))
    #expect(history.entries.isEmpty)
    #expect(history.currentIndex == -1)
    #expect(history.canUndo == false)
    #expect(history.canRedo == false)
  }

  @Test func loadBeyondCapDropsOldestAndShiftsIndex() {
    let history = History()
    let entries = (0..<60).map { HistoryEntry(snapshot: ProjectFixtures.editorState(marker: Double($0)), timestamp: Date()) }
    history.load(from: HistoryData(entries: entries, currentIndex: 59))
    #expect(history.entries.count == 50)
    #expect(markers(history).first == 10)
    #expect(history.currentIndex == 49)
    history.load(from: HistoryData(entries: entries, currentIndex: 3))
    #expect(history.entries.count == 50)
    #expect(history.currentIndex == 0)
  }

  @Test func historyDataRoundTripsThroughJSON() throws {
    let history = History()
    push(history, 0...4)
    _ = history.undo()
    _ = history.undo()
    let data = history.toData()
    #expect(data.currentIndex == 2)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let json = try encoder.encode(data)
    let decoded = try JSONDecoder().decode(HistoryData.self, from: json)
    #expect(decoded.currentIndex == 2)
    #expect(decoded.entries.count == 5)
    #expect(decoded.entries.map(\.snapshot.trimStartSeconds) == [0, 1, 2, 3, 4])
    for (original, restored) in zip(data.entries, decoded.entries) {
      #expect(abs(original.timestamp.timeIntervalSince(restored.timestamp)) < 0.001)
    }
    let reloaded = History()
    reloaded.load(from: decoded)
    #expect(reloaded.currentIndex == 2)
    #expect(reloaded.canUndo)
    #expect(reloaded.canRedo)
    #expect(reloaded.redo()?.trimStartSeconds == 3)
  }

  @Test func fullEditorStateSurvivesHistoryJSON() throws {
    let history = History()
    history.pushSnapshot(ProjectFixtures.fullEditorState())
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let json = try encoder.encode(history.toData())
    let decoded = try JSONDecoder().decode(HistoryData.self, from: json)
    let snapshot = try #require(decoded.entries.first?.snapshot)
    let original = ProjectFixtures.fullEditorState()
    #expect(snapshot.cameraRegions == original.cameraRegions)
    #expect(snapshot.zoomSettings == original.zoomSettings)
    #expect(snapshot.captionSegments == original.captionSegments)
    #expect(snapshot.spotlightRegions == original.spotlightRegions)
    #expect(snapshot.backgroundStyle == original.backgroundStyle)
  }

  @Test func historyEntryLabelSurvivesRoundTripAndIsOptional() throws {
    let snapshot = ProjectFixtures.editorState(marker: 1)
    let labeled = HistoryData(
      entries: [HistoryEntry(snapshot: snapshot, timestamp: Date(timeIntervalSince1970: 1), label: "Agent: tighten")],
      currentIndex: 0
    )

    let encoded = try JSONEncoder().encode(labeled)
    let decoded = try JSONDecoder().decode(HistoryData.self, from: encoded)
    #expect(decoded.entries.first?.label == "Agent: tighten")

    let legacy = try JSONEncoder().encode(
      ["snapshot": try JSONValue(encoding: snapshot), "timestamp": JSONValue(1.0)] as [String: JSONValue]
    )
    let legacyEntry = try JSONDecoder().decode(HistoryEntry.self, from: legacy)
    #expect(legacyEntry.label == nil)
  }

  @Test func pushSnapshotSkipsWhenEqualToCurrentEntry() {
    let history = History()
    let snapshot = ProjectFixtures.editorState(marker: 1)

    history.pushSnapshot(snapshot)
    history.pushSnapshot(snapshot, label: "Agent: no change")

    #expect(history.entries.count == 1)
    #expect(history.entries.first?.label == nil)
  }
}
