import Foundation
import SwiftUI

extension AgentConversationView {
  func send(recovering: Bool = false, fresh: Bool = false) {
    let text = recovering ? transcript.recoveryPrompt ?? "" : prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    guard
      canStart,
      !text.isEmpty,
      selectedReadiness?.executableURL != nil,
      let project
    else { return }
    if AppDistribution.isStore && !consentedProviders.contains(transcript.provider) {
      pendingRecovery = recovering
      pendingFresh = fresh
      showAIConsent = true
      return
    }
    let provider = transcript.provider.makeProvider()
    let workspace: URL
    preparationError = nil
    do {
      workspace = try AgentSendPreparation.workspace(project: project.bundleURL, configuration: sessionConfiguration)
    } catch {
      preparationError = error.localizedDescription
      return
    }
    isPreparing = true
    Task {
      defer { isPreparing = false }
      guard let executable = await toolchain.resolveProvider(provider.id) else {
        preparationError = "No working \(provider.displayName) runtime is available. Check Agents in Settings."
        return
      }
      let searchPath = await toolchain.searchPath()
      guard !transcript.isRunning, transcript.provider == provider.id else { return }
      let home = FileManager.default.homeDirectoryForCurrentUser.path
      var environment = AgentRuntimePolicy().environment(
        path: searchPath,
        home: home,
        forwarding: provider.environmentKeys
      )
      environment.merge(sessionConfiguration?.processEnvironment ?? [:]) { _, configured in configured }
      let session = AgentSession(
        provider: provider,
        executable: executable,
        workingDirectory: workspace,
        environment: environment,
        configuration: sessionConfiguration,
        resumeIDs: fresh ? [:] : transcript.resumeIDs
      )
      if recovering {
        transcript.retry(using: session)
      } else {
        prompt = ""
        transcript.send(text, using: session)
      }
    }
  }
}
