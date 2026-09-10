import Foundation
import SwiftUI

extension AgentConversationView {
  @ViewBuilder
  var readinessView: some View {
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

  var selectedReadiness: AgentReadiness? {
    readiness[transcript.provider]
  }

  private var loginCommand: String {
    switch transcript.provider {
    case .claudeCode: "claude auth login"
    case .codex: "codex login"
    }
  }

  private func statusRow(icon: String, text: String, color: Color = AppShowColors.secondaryText) -> some View {
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
        .foregroundStyle(AppShowColors.secondaryText)
      Button("Check Again") {
        Task { await refreshReadiness() }
      }
      .buttonStyle(SecondaryButtonStyle(size: .small))
      .disabled(isResolving)
    }
    .padding(8)
    .background(AppShowColors.muted)
    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
  }

  func refreshReadiness() async {
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

}
