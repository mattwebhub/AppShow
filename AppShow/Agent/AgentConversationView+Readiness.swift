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
        HStack {
          statusRow(icon: "checkmark.circle.fill", text: "Ready · \(version)", color: Color.green)
          Spacer()
          Button("Recheck") { Task { await refreshReadiness() } }
            .buttonStyle(SecondaryButtonStyle(size: .small))
            .disabled(isResolving || transcript.isRunning || signIn.isRunning)
            .help("Refresh the provider path, version and sign-in status after updating.")
        }
      case .missing:
        setupCard(
          message: AppDistribution.isStore
            ? "The installed application is missing \(transcript.provider.displayName). Reinstall AppShow to restore it."
            : "\(transcript.provider.displayName) was not found in PATH or common install locations."
        )
      case .notLoggedIn:
        setupCard(
          message: AppDistribution.isStore
            ? "Connect your own account to start editing with \(transcript.provider.displayName)."
            : "Sign in from Terminal with `\(loginCommand)`."
        )
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
      if AppDistribution.isStore, case .notLoggedIn = selectedReadiness {
        if signIn.isRunning {
          Text(signIn.message ?? "Complete sign-in in your browser.")
            .font(.system(size: FontSize.xxs))
          if let url = signIn.authorizationURL {
            Link("Open Sign-In Page", destination: url)
              .font(.system(size: FontSize.xxs))
          }
          Button("Cancel Sign-In") { signIn.cancel() }
            .buttonStyle(SecondaryButtonStyle(size: .small))
        } else {
          Button("Sign In with \(transcript.provider == .codex ? "ChatGPT" : "Claude")") { beginSignIn() }
            .buttonStyle(PrimaryButtonStyle(size: .small))
          if transcript.provider == .claudeCode {
            Button("Use Claude Console") { beginSignIn(console: true) }
              .buttonStyle(SecondaryButtonStyle(size: .small))
          }
          if let message = signIn.message {
            Text(message).font(.system(size: FontSize.xxs))
          }
        }
      }
      Button("Check Again") {
        Task { await refreshReadiness() }
      }
      .buttonStyle(SecondaryButtonStyle(size: .small))
      .disabled(isResolving || signIn.isRunning)
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
    do { try AgentRuntimePolicy().prepare() } catch {
      readiness = Dictionary(
        uniqueKeysWithValues: AgentProviderKind.allCases.map {
          ($0, .unhealthy(executable: nil, reason: "Could not prepare agent storage."))
        }
      )
      isResolving = false
      return
    }
    for kind in AgentProviderKind.allCases {
      let provider = kind.makeProvider()
      guard let executable = await toolchain.resolveProvider(kind) else {
        statuses[kind] = .missing(searchedPaths: searchedPaths)
        continue
      }
      let environment = AgentRuntimePolicy().environment(
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

  private func beginSignIn(console: Bool = false) {
    guard let executable = selectedReadiness?.executableURL else { return }
    let provider = transcript.provider
    let environment = AgentRuntimePolicy().environment(path: "", home: FileManager.default.homeDirectoryForCurrentUser.path, forwarding: [])
    Task {
      _ = await signIn.start(provider: provider, executable: executable, environment: environment, console: console)
      await refreshReadiness()
    }
  }

}
