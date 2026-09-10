import Foundation
import SwiftUI

@MainActor
struct AgentConversationView: View {
  @Bindable var transcript: AgentTranscript
  @Bindable var confirmations: AgentConfirmations
  let sessionConfiguration: AgentSessionConfig?
  let project: AppShowProject?
  let isExporting: Bool

  @State var prompt = ""
  @State var isPreparing = false
  @State var readiness: [AgentProviderKind: AgentReadiness] = [:]
  @State var isResolving = false
  @State var toolchain = AgentToolchain.standard()
  @State var signIn = AgentSignIn()
  @State var consentedProviders: Set<AgentProviderKind> = []
  @State var showAIConsent = false
  @State var pendingRecovery = false
  @State var pendingFresh = false
  @State var preparationError: String?
  @FocusState private var composerFocused: Bool

  var body: some View {
    VStack(spacing: 0) {
      transcriptView
      Divider()
        .overlay(AppShowColors.divider)
      composer
    }
    .task {
      await refreshReadiness()
    }
    .onDisappear { signIn.cancel() }
    .confirmationDialog(
      "Share this project with \(transcript.provider.displayName)?",
      isPresented: $showAIConsent,
      titleVisibility: .visible
    ) {
      Button("Allow and Send") {
        consentedProviders.insert(transcript.provider)
        send(recovering: pendingRecovery, fresh: pendingFresh)
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(
        "Your messages, project details, and preview images requested by the assistant will be sent to \(transcript.provider == .codex ? "OpenAI" : "Anthropic"). The assistant can edit this project using AppShow tools. You can undo edits and must confirm full exports separately."
      )
    }
    .onChange(of: transcript.isRunning) { wasRunning, isRunning in
      if wasRunning && !isRunning {
        confirmations.clear()
      }
    }
  }

  private var transcriptView: some View {
    ScrollViewReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          if transcript.messages.isEmpty {
            emptyState
          } else {
            ForEach(transcript.messages) { message in
              AgentMessageView(message: message)
                .id(message.id)
            }
          }
          ForEach(confirmations.pending) { request in
            AgentConfirmationView(
              request: request,
              onAllow: { confirmations.approve(request.id) },
              onDeny: { confirmations.deny(request.id) }
            )
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
        .foregroundStyle(AppShowColors.tertiaryText)
      Text("Describe the presentation you want to create.")
        .font(.system(size: FontSize.xs))
        .foregroundStyle(AppShowColors.secondaryText)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 40)
  }

  private var composer: some View {
    VStack(alignment: .leading, spacing: Layout.compactSpacing) {
      readinessView
      if let preparationError {
        AgentNoticeView(text: preparationError, tone: .warning)
      }
      if transcript.recoveryPrompt != nil {
        HStack {
          Button("Retry interrupted reply") { send(recovering: true) }
            .buttonStyle(OutlineButtonStyle(size: .small))
          Button("Start fresh") { send(recovering: true, fresh: true) }
            .buttonStyle(OutlineButtonStyle(size: .small))
            .help("Keep this conversation and retry with a new provider session.")
        }
        .disabled(!canStart)
      }
      if project == nil {
        AgentNoticeView(text: "Open a project to start a conversation.")
      }
      if isExporting {
        AgentNoticeView(text: "Wait for the export to finish before sending a message.")
      }
      composerField
    }
    .padding(12)
  }

  private var composerField: some View {
    HStack(alignment: .bottom, spacing: Layout.compactSpacing) {
      TextField("Message the assistant", text: $prompt, axis: .vertical)
        .textFieldStyle(.plain)
        .font(.system(size: FontSize.xs))
        .foregroundStyle(AppShowColors.primaryText)
        .lineLimit(2...8)
        .padding(.vertical, 6)
        .padding(.leading, 4)
        .focused($composerFocused)
        .onSubmit { send() }
        .disabled(transcript.isRunning)
      composerAction
    }
    .padding(6)
    .background(AppShowColors.fieldBackground)
    .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
    .overlay(
      RoundedRectangle(cornerRadius: Radius.lg)
        .strokeBorder(composerFocused ? AppShowColors.ring : AppShowColors.border, lineWidth: 1)
    )
    .contentShape(Rectangle())
    .onTapGesture { composerFocused = true }
  }

  @ViewBuilder
  private var composerAction: some View {
    if transcript.isRunning {
      Button {
        transcript.cancel()
      } label: {
        Image(systemName: "stop.fill")
      }
      .buttonStyle(CircularPrimaryButtonStyle())
      .help("Stop the assistant")
    } else {
      Button {
        send()
      } label: {
        Image(systemName: "arrow.up")
      }
      .buttonStyle(CircularPrimaryButtonStyle())
      .disabled(!canSend)
      .help("Send message")
    }
  }

  var canStart: Bool {
    selectedReadiness?.isReady == true
      && project != nil
      && !isExporting
      && !transcript.isRunning
      && !isPreparing
  }

  private var canSend: Bool {
    canStart && !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

}
