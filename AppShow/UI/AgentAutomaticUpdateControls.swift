#if !APP_STORE
import SwiftUI

struct AgentAutomaticUpdateControls: View {
  @Bindable var updater: AgentAutoUpdateService

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Keep Claude Code and Codex up to date")
          .font(.system(size: FontSize.xs, weight: .medium))
        Spacer()
        CustomToggle(isOn: $updater.isEnabled)
      }
      HStack(spacing: 10) {
        Button(updater.isRunning ? "Updating…" : "Check for Updates") {
          Task { await updater.runNow() }
        }
        .buttonStyle(OutlineButtonStyle(size: .small))
        .disabled(updater.isRunning)
        if updater.isRunning { ProgressView().controlSize(.small) }
      }
      if let checked = updater.lastCheckedAt {
        Text("Last checked \(checked.formatted(date: .abbreviated, time: .shortened))")
          .font(.system(size: FontSize.xxs))
          .foregroundStyle(AppShowColors.secondaryText)
      }
      if let error = updater.persistenceError {
        Text(error).font(.system(size: FontSize.xxs)).foregroundStyle(.red)
      }
    }
  }
}
#endif
