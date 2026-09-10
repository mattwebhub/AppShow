import SwiftUI

struct AgentRuntimeSettingsView: View {
  @State private var versions: [AgentProviderKind: AgentVersionStatus] = [:]
  @State private var executables: [AgentProviderKind: String] = [:]
  @State private var refreshID = UUID()
  @State private var isChecking = false
  @State private var storeUnavailable = false
  #if !APP_STORE
  @State private var updater = AgentAutoUpdateService.shared
  #endif

  var body: some View {
    VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
      Text("Agent updates")
        .font(.system(size: FontSize.sm, weight: .semibold))
      #if APP_STORE
      Text("Claude Code and Codex are included with AppShow. New versions arrive through AppShow updates in the Mac App Store.")
        .font(.system(size: FontSize.xs))
        .foregroundStyle(AppShowColors.secondaryText)
      Button("Open App Store") {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.AppStore") else {
          storeUnavailable = true
          return
        }
        storeUnavailable = !NSWorkspace.shared.open(url)
      }
      .buttonStyle(OutlineButtonStyle(size: .small))
      .alert("Could not open the App Store", isPresented: $storeUnavailable) {
        Button("OK", role: .cancel) {}
      } message: {
        Text("Open the App Store from Applications and check Updates for AppShow.")
      }
      #else
      Text(
        "AppShow checks daily and installs verified updates in its own runtime folder. Your existing installations are preserved. New replies use the newest working version."
      )
      .font(.system(size: FontSize.xs))
      .foregroundStyle(AppShowColors.secondaryText)
      AgentAutomaticUpdateControls(updater: updater)
      #endif
      ForEach(AgentProviderKind.allCases) { provider in
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text(provider.displayName)
              .fontWeight(.medium)
            Spacer()
            Text(versions[provider]?.label ?? "Checking…")
              .foregroundStyle(AppShowColors.secondaryText)
          }
          .font(.system(size: FontSize.xs))
          #if !APP_STORE
          if let outcome = updater.outcomes[provider] {
            Text(outcome.label)
              .font(.system(size: FontSize.xxs))
              .foregroundStyle(AppShowColors.secondaryText)
          }
          if let executable = executables[provider] {
            Text(executable)
              .font(.system(size: FontSize.xxs, design: .monospaced))
              .foregroundStyle(AppShowColors.secondaryText)
              .textSelection(.enabled)
          }
          if case .unavailable = versions[provider] {
            Button("Install AppShow's \(provider.displayName)") {
              Task { await updater.runNow(providers: [provider], installMissing: true) }
            }
            .buttonStyle(PrimaryButtonStyle(size: .small))
            .disabled(updater.isRunning)
          }
          DisclosureGroup("Other installation methods") {
            AgentRuntimeUpdateInstructions(provider: provider)
          }
          .font(.system(size: FontSize.xxs))
          #endif
        }
        .padding(12)
        .background(AppShowColors.muted)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
      }
      #if !APP_STORE
      Button(isChecking ? "Checking…" : "Recheck Installed Versions") { refreshID = UUID() }
        .buttonStyle(OutlineButtonStyle(size: .small))
        .disabled(isChecking)
      #endif
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .task(id: refreshID) { await refresh() }
    #if !APP_STORE
    .onChange(of: updater.revision) { refreshID = UUID() }
    #endif
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
      if !isChecking { refreshID = UUID() }
    }
  }

  private func refresh() async {
    #if APP_STORE
    let receipt = Bundle.main.url(forResource: "AgentRuntimes", withExtension: "json")
      .flatMap { try? Data(contentsOf: $0) }
      .flatMap { try? JSONDecoder().decode(RuntimeReceipt.self, from: $0) }
    versions = Dictionary(
      uniqueKeysWithValues: AgentProviderKind.allCases.map { provider in
        (provider, receipt?.versions[provider.rawValue].map(AgentVersionStatus.available) ?? .unavailable("Version unavailable"))
      }
    )
    #else
    isChecking = true
    defer { isChecking = false }
    let toolchain = AgentToolchain.standard()
    for provider in AgentProviderKind.allCases {
      guard !Task.isCancelled else { return }
      guard let executable = await toolchain.resolveProvider(provider) else {
        versions[provider] = .unavailable("Not installed")
        executables[provider] = nil
        continue
      }
      executables[provider] = executable.path
      versions[provider] = await AgentProbe().version(
        executable: executable,
        environment: AgentRuntimePolicy().environment(
          path: await toolchain.searchPath(),
          home: FileManager.default.homeDirectoryForCurrentUser.path,
          forwarding: []
        )
      )
    }
    #endif
  }
}

private struct RuntimeReceipt: Decodable {
  var versions: [String: String]
}
