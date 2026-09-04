import Foundation
import SwiftUI

@MainActor
struct AgentConversationView: View {
  @Bindable var transcript: AgentTranscript
  let project: ReframedProject?
  let isExporting: Bool

  @State private var prompt = ""
  @State private var readiness: [AgentProviderKind: AgentReadiness] = [:]
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
    .task {
      await refreshReadiness()
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
      readinessView
      if project == nil {
        Text("Open a project to start a conversation.")
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
    selectedReadiness?.isReady == true
      && project != nil
      && !isExporting
      && !transcript.isRunning
      && !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  @ViewBuilder
  private var readinessView: some View {
    if isResolving, selectedReadiness == nil {
      statusRow(icon: "ellipsis", text: "Checking \(transcript.provider.displayName)…")
    } else {
      switch selectedReadiness {
      case .ready(_, let version):
        statusRow(icon: "checkmark.circle.fill", text: "Ready · \(version)", color: Color.green)
      case .missing:
        setupCard(
          message: "\(transcript.provider.displayName) was not found in PATH or common install locations."
        )
      case .notLoggedIn:
        setupCard(message: "Sign in from Terminal with `\(loginCommand)`.")
      case .unhealthy(_, let reason):
        setupCard(message: reason)
      case nil:
        setupCard(message: "\(transcript.provider.displayName) has not been checked yet.")
      }
    }
  }

  private var selectedReadiness: AgentReadiness? {
    readiness[transcript.provider]
  }

  private var loginCommand: String {
    switch transcript.provider {
    case .claudeCode: "claude auth login"
    case .codex: "codex login"
    }
  }

  private func statusRow(icon: String, text: String, color: Color = ReframedColors.secondaryText) -> some View {
    HStack(spacing: 6) {
      Image(systemName: icon)
      Text(text)
    }
    .font(.system(size: FontSize.xxs))
    .foregroundStyle(color)
  }

  private func setupCard(message: String) -> some View {
    VStack(alignment: .leading, spacing: Layout.compactSpacing) {
      statusRow(icon: "exclamationmark.triangle", text: selectedReadiness?.statusLabel ?? "Not checked")
      Text(message)
        .font(.system(size: FontSize.xxs))
        .foregroundStyle(ReframedColors.secondaryText)
      Button("Check Again") {
        Task { await refreshReadiness() }
      }
      .buttonStyle(SecondaryButtonStyle(size: .small))
      .disabled(isResolving)
    }
    .padding(8)
    .background(ReframedColors.muted)
    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
  }

  private func refreshReadiness() async {
    isResolving = true
    await toolchain.invalidate()
    let searchPath = await toolchain.searchPath()
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let searchedPaths = searchPath.split(separator: ":").map(String.init)
    var statuses: [AgentProviderKind: AgentReadiness] = [:]
    for kind in AgentProviderKind.allCases {
      let provider = kind.makeProvider()
      guard let executable = await toolchain.resolve(provider.executableNames) else {
        statuses[kind] = .missing(searchedPaths: searchedPaths)
        continue
      }
      let environment = AgentEnvironment.scrubbed(
        path: await toolchain.searchPath(),
        home: home,
        forwarding: provider.environmentKeys
      )
      statuses[kind] = await AgentProbe().check(
        provider: kind,
        executable: executable,
        environment: environment
      )
    }
    readiness = statuses
    let selected = AgentReadinessSnapshot(statuses: statuses).selection(remembered: transcript.provider)
    if selected != transcript.provider {
      transcript.setProvider(selected)
      ConfigService.shared.agentProvider = selected
    }
    isResolving = false
  }

  private func send() {
    let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    guard
      canSend,
      !text.isEmpty,
      let executable = selectedReadiness?.executableURL,
      let project
    else { return }
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
          AgentMarkdownView(text: text)
        case .toolCall(let call):
          AgentToolCallView(call: call)
        }
      }
      if message.status == .streaming {
        Text("▋")
          .foregroundStyle(ReframedColors.secondaryText)
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

}

@MainActor
private struct AgentToolCallView: View {
  let call: AgentToolCallData
  @State private var expanded = false

  var body: some View {
    VStack(alignment: .leading, spacing: Layout.compactSpacing) {
      Button {
        if hasDetails { expanded.toggle() }
      } label: {
        HStack(spacing: Layout.compactSpacing) {
          Image(systemName: icon)
          Text(call.name)
            .font(.system(size: FontSize.xs, weight: .medium))
          Spacer()
          if hasDetails {
            Image(systemName: expanded ? "chevron.up" : "chevron.down")
              .foregroundStyle(ReframedColors.secondaryText)
          }
        }
      }
      .buttonStyle(PlainCustomButtonStyle())
      if expanded {
        if !call.input.isEmpty {
          detail(call.input)
        }
        if let output = call.output, !output.isEmpty {
          detail(output)
        }
      }
    }
    .padding(8)
    .background(ReframedColors.muted)
    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
  }

  private var hasDetails: Bool {
    !call.input.isEmpty || call.output?.isEmpty == false
  }

  private func detail(_ text: String) -> some View {
    Text(text)
      .font(.system(size: FontSize.xxs, design: .monospaced))
      .foregroundStyle(ReframedColors.secondaryText)
      .textSelection(.enabled)
  }

  private var icon: String {
    switch call.status {
    case .executing: "hourglass"
    case .completed: "checkmark.circle"
    case .failed: "exclamationmark.circle"
    }
  }
}
