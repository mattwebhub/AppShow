import Foundation
import SwiftUI

@MainActor
struct AgentConversationView: View {
  @Bindable var transcript: AgentTranscript
  let project: ReframedProject?
  let isExporting: Bool

  @State private var prompt = ""
  @State private var executable: URL?
  @State private var isResolving = false
  @State private var toolchain = AgentToolchain.standard()
  @FocusState private var composerFocused: Bool

  var body: some View {
    VStack(spacing: 0) {
      transcriptView
      Divider()
        .overlay(ReframedColors.divider)
      composer
    }
    .task(id: transcript.provider) {
      await resolveExecutable()
    }
  }

  private var transcriptView: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 12) {
          if transcript.messages.isEmpty {
            emptyState
          } else {
            ForEach(transcript.messages) { message in
              AgentMessageView(message: message)
                .id(message.id)
            }
          }
        }
        .padding(12)
      }
      .onChange(of: transcript.messages) { _, messages in
        guard let id = messages.last?.id else { return }
        withAnimation(.easeOut(duration: 0.15)) {
          proxy.scrollTo(id, anchor: .bottom)
        }
      }
    }
  }

  private var emptyState: some View {
    VStack(spacing: Layout.compactSpacing) {
      Image(systemName: "wand.and.stars")
        .font(.system(size: FontSize.xxl))
        .foregroundStyle(ReframedColors.tertiaryText)
      Text("Describe the presentation you want to create.")
        .font(.system(size: FontSize.xs))
        .foregroundStyle(ReframedColors.secondaryText)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 40)
  }

  private var composer: some View {
    VStack(alignment: .leading, spacing: Layout.compactSpacing) {
      if executable == nil {
        HStack(spacing: 6) {
          Image(systemName: isResolving ? "ellipsis" : "exclamationmark.triangle")
          Text(
            isResolving
              ? "Finding \(transcript.provider.displayName)…" : "Install and sign in to \(transcript.provider.displayName) to continue."
          )
        }
        .font(.system(size: FontSize.xxs))
        .foregroundStyle(ReframedColors.secondaryText)
      }
      if isExporting {
        Text("Wait for the export to finish before sending a message.")
          .font(.system(size: FontSize.xxs))
          .foregroundStyle(ReframedColors.secondaryText)
      }
      HStack(alignment: .bottom, spacing: Layout.compactSpacing) {
        TextField("Message the assistant", text: $prompt, axis: .vertical)
          .textFieldStyle(.plain)
          .font(.system(size: FontSize.xs))
          .foregroundStyle(ReframedColors.primaryText)
          .lineLimit(2...8)
          .padding(8)
          .background(ReframedColors.fieldBackground)
          .clipShape(RoundedRectangle(cornerRadius: Radius.md))
          .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(ReframedColors.border, lineWidth: 1))
          .focused($composerFocused)
          .onSubmit(send)
          .disabled(transcript.isRunning)
        if transcript.isRunning {
          IconButton(systemName: "stop.fill") {
            transcript.cancel()
          }
        } else {
          Button(action: send) {
            Image(systemName: "arrow.up")
          }
          .buttonStyle(PrimaryButtonStyle(size: .small))
          .disabled(!canSend)
        }
      }
    }
    .padding(12)
  }

  private var canSend: Bool {
    executable != nil
      && project != nil
      && !isExporting
      && !transcript.isRunning
      && !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private func resolveExecutable() async {
    isResolving = true
    executable = await toolchain.resolve(transcript.provider.makeProvider().executableNames)
    isResolving = false
  }

  private func send() {
    let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    guard canSend, !text.isEmpty, let executable, let project else { return }
    let provider = transcript.provider.makeProvider()
    let workspace = AgentProjectWorkspace.directory(for: project.bundleURL)
    do {
      try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
    } catch {
      return
    }
    prompt = ""
    Task {
      let searchPath = await toolchain.searchPath()
      let home = FileManager.default.homeDirectoryForCurrentUser.path
      let environment = AgentEnvironment.scrubbed(
        path: searchPath,
        home: home,
        forwarding: provider.environmentKeys
      )
      let session = AgentSession(
        provider: provider,
        executable: executable,
        workingDirectory: workspace,
        environment: environment,
        resumeIDs: transcript.resumeIDs
      )
      transcript.send(text, using: session)
    }
  }
}

@MainActor
private struct AgentMessageView: View {
  let message: AgentMessageData

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(Array(message.content.enumerated()), id: \.offset) { _, content in
        switch content {
        case .text(let text):
          Text(attributed(text))
            .textSelection(.enabled)
        case .toolCall(let call):
          AgentToolCallView(call: call)
        }
      }
      if let reason = message.failureReason {
        Text(reason)
          .font(.system(size: FontSize.xxs))
          .foregroundStyle(Color.red)
      }
    }
    .font(.system(size: FontSize.xs))
    .foregroundStyle(ReframedColors.primaryText)
    .padding(message.role == .user ? 10 : 0)
    .background(message.role == .user ? ReframedColors.muted : Color.clear)
    .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
    .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
  }

  private func attributed(_ text: String) -> AttributedString {
    (try? AttributedString(markdown: text)) ?? AttributedString(text)
  }
}

@MainActor
private struct AgentToolCallView: View {
  let call: AgentToolCallData

  var body: some View {
    HStack(spacing: Layout.compactSpacing) {
      Image(systemName: icon)
      VStack(alignment: .leading, spacing: 2) {
        Text(call.name)
          .font(.system(size: FontSize.xs, weight: .medium))
        if !call.input.isEmpty {
          Text(call.input)
            .font(.system(size: FontSize.xxs, design: .monospaced))
            .lineLimit(2)
            .foregroundStyle(ReframedColors.secondaryText)
        }
      }
      Spacer()
    }
    .padding(8)
    .background(ReframedColors.muted)
    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
  }

  private var icon: String {
    switch call.status {
    case .executing: "hourglass"
    case .completed: "checkmark.circle"
    case .failed: "exclamationmark.circle"
    }
  }
}
