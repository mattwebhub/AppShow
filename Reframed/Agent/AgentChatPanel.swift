import SwiftUI

@MainActor
struct AgentChatPanel: View {
  @Bindable var transcript: AgentTranscript
  @Bindable var confirmations: AgentConfirmations
  let sessionConfiguration: AgentSessionConfig?
  let project: ReframedProject?
  let isExporting: Bool
  @State private var collapsed: Bool
  @State private var expandedWidth: CGFloat
  @State private var dragStartWidth: CGFloat?
  @State private var showClearConfirmation = false
  @Environment(\.colorScheme) private var colorScheme

  init(
    transcript: AgentTranscript,
    confirmations: AgentConfirmations,
    sessionConfiguration: AgentSessionConfig?,
    project: ReframedProject?,
    isExporting: Bool
  ) {
    self.transcript = transcript
    self.confirmations = confirmations
    self.sessionConfiguration = sessionConfiguration
    self.project = project
    self.isExporting = isExporting
    let state = StateService.shared
    _collapsed = State(initialValue: state.agentPanelCollapsed)
    _expandedWidth = State(initialValue: state.agentPanelWidth)
  }

  var body: some View {
    let _ = colorScheme
    Group {
      if collapsed {
        collapsedRail
      } else {
        expandedPanel
      }
    }
    .frame(width: AgentPanelLayout.visibleWidth(collapsed: collapsed, expandedWidth: expandedWidth))
    .frame(maxHeight: .infinity)
    .background(ReframedColors.backgroundCard)
    .clipShape(RoundedRectangle(cornerRadius: Radius.xxl))
    .overlay(RoundedRectangle(cornerRadius: Radius.xxl).strokeBorder(ReframedColors.border, lineWidth: 1))
    .overlay(alignment: .trailing) {
      if !collapsed {
        resizeHandle
      }
    }
    .animation(.easeInOut(duration: 0.2), value: collapsed)
    .confirmationDialog(
      "Clear this project's conversation?",
      isPresented: $showClearConfirmation,
      titleVisibility: .visible
    ) {
      Button("Clear Conversation", role: .destructive) {
        transcript.clear()
        confirmations.clear()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Messages and saved agent sessions for this project will be removed.")
    }
  }

  private var collapsedRail: some View {
    VStack(spacing: Layout.compactSpacing) {
      IconButton(systemName: "sparkles") {
        setCollapsed(false)
      }
      if transcript.isRunning || !confirmations.pending.isEmpty {
        Circle()
          .fill(confirmations.pending.isEmpty ? Color.green : Color.orange)
          .frame(width: 6, height: 6)
      }
      Spacer()
    }
    .padding(.vertical, 10)
  }

  private var expandedPanel: some View {
    VStack(spacing: 0) {
      header
      Divider()
        .overlay(ReframedColors.divider)
      content
    }
  }

  private var header: some View {
    VStack(spacing: Layout.compactSpacing) {
      HStack(spacing: Layout.compactSpacing) {
        Image(systemName: "sparkles")
          .font(.system(size: FontSize.sm, weight: .semibold))
        Text("Assistant")
          .font(.system(size: FontSize.sm, weight: .semibold))
        Spacer()
        IconButton(systemName: "trash", color: ReframedColors.secondaryText) {
          showClearConfirmation = true
        }
        .disabled(transcript.messages.isEmpty || transcript.isRunning)
        IconButton(systemName: "sidebar.left") {
          setCollapsed(true)
        }
      }
      SegmentPicker(
        items: AgentProviderKind.allCases,
        label: \.displayName,
        selection: Binding(
          get: { transcript.provider },
          set: { provider in
            transcript.setProvider(provider)
            ConfigService.shared.agentProvider = provider
          }
        )
      )
      .disabled(transcript.isRunning)
    }
    .foregroundStyle(ReframedColors.primaryText)
    .padding(12)
  }

  private var content: some View {
    AgentConversationView(
      transcript: transcript,
      confirmations: confirmations,
      sessionConfiguration: sessionConfiguration,
      project: project,
      isExporting: isExporting
    )
  }

  private var resizeHandle: some View {
    Rectangle()
      .fill(Color.clear)
      .frame(width: 8)
      .contentShape(Rectangle())
      .onHover { hovering in
        if hovering {
          NSCursor.resizeLeftRight.push()
        } else {
          NSCursor.pop()
        }
      }
      .gesture(
        DragGesture()
          .onChanged { value in
            let start = dragStartWidth ?? expandedWidth
            dragStartWidth = start
            expandedWidth = AgentPanelLayout.clamp(start + value.translation.width)
          }
          .onEnded { _ in
            dragStartWidth = nil
            StateService.shared.agentPanelWidth = expandedWidth
          }
      )
  }

  private func setCollapsed(_ value: Bool) {
    collapsed = value
    StateService.shared.agentPanelCollapsed = value
  }
}
