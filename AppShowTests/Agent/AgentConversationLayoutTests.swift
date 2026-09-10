import AppKit
import SwiftUI
import Testing

@testable import AppShow

@MainActor
@Suite(.serialized)
struct AgentConversationLayoutTests {
  @Test func completedToolHistoryCanAppendAndStreamAnotherReply() async throws {
    let root = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(root) }
    let transcript = AgentTranscript(store: nil)
    for turn in 0..<4 {
      transcript.appendUserMessage(String(repeating: "Inspect the project and keep its existing timing. ", count: 4))
      transcript.beginAssistantMessage()
      transcript.apply(.textDelta("I will inspect the project, apply the requested change and verify the result."))
      for tool in 0..<7 {
        let id = "\(turn)-\(tool)"
        transcript.apply(.toolCallStarted(id: id, name: "get_project_summary", input: "{}"))
        transcript.apply(.toolCallFinished(id: id, output: "{\"duration\":62.05}", isError: false))
      }
      transcript.apply(.textDelta("\n\nThe change is complete. Timing and styling are unchanged."))
      transcript.apply(.turnCompleted(AgentTurnResult()))
      transcript.finishTurn(error: nil)
    }
    let view = AgentConversationView(
      transcript: transcript,
      confirmations: AgentConfirmations(),
      sessionConfiguration: nil,
      project: nil,
      isExporting: false,
      toolchain: AgentToolchain(path: "", loginShell: nil, home: root)
    )
    let host = NSHostingView(rootView: view)
    host.sizingOptions = []
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 320, height: 460),
      styleMask: [.titled, .closable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.isReleasedWhenClosed = false
    window.contentView = host
    window.orderFront(nil)
    defer { window.close() }
    try await Task.sleep(for: .milliseconds(200))
    host.layoutSubtreeIfNeeded()
    transcript.appendUserMessage("Report the title and duration without changing the project.")
    transcript.beginAssistantMessage()
    for word in ["The ", "project ", "duration ", "is ", "62.05 seconds."] {
      transcript.apply(.textDelta(word))
      try await Task.sleep(for: .milliseconds(50))
      host.layoutSubtreeIfNeeded()
      #expect(host.frame.height == 460)
      #expect(host.frame.width == 320)
      #expect(host.fittingSize.height.isFinite)
      _ = host.accessibilityChildren()
    }
    #expect(transcript.messages.last?.text == "The project duration is 62.05 seconds.")
    transcript.markCancelled()
  }
}
