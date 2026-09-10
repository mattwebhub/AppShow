#if !APP_STORE
import SwiftUI

struct AgentRuntimeUpdateInstructions: View {
  var provider: AgentProviderKind
  @State private var installation = AgentCLIInstallation.unknown
  @State private var copied = false

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Picker("Installed with", selection: $installation) {
        ForEach(AgentCLIInstallation.allCases.filter { $0 != .homebrewLatest || provider == .claudeCode }) { method in
          Text(method.rawValue).tag(method)
        }
      }
      .pickerStyle(.menu)
      .onChange(of: installation) { copied = false }
      if let command = installation.command(for: provider) {
        Text(command)
          .font(.system(size: FontSize.xxs, design: .monospaced))
          .textSelection(.enabled)
        Button(copied ? "Copied" : "Copy Update Command") {
          NSPasteboard.general.clearContents()
          copied = NSPasteboard.general.setString(command, forType: .string)
        }
        .buttonStyle(SecondaryButtonStyle(size: .small))
      }
      Link(
        "Installation and update help",
        destination: provider == .codex
          ? URL(string: "https://developers.openai.com/codex/cli/")!
          : URL(string: "https://code.claude.com/docs/en/setup")!
      )
      .font(.system(size: FontSize.xxs))
    }
  }
}

private enum AgentCLIInstallation: String, CaseIterable, Identifiable {
  case unknown = "Choose installer…"
  case native = "Native installer"
  case homebrew = "Homebrew"
  case homebrewLatest = "Homebrew (@latest)"
  case npm = "npm"

  var id: Self { self }

  func command(for provider: AgentProviderKind) -> String? {
    switch (self, provider) {
    case (.unknown, _): nil
    case (.native, .claudeCode): "claude update"
    case (.native, .codex): "curl -fsSL https://chatgpt.com/codex/install.sh | sh"
    case (.homebrew, .claudeCode): "brew upgrade claude-code"
    case (.homebrew, .codex): "brew upgrade --cask codex"
    case (.homebrewLatest, .claudeCode): "brew upgrade claude-code@latest"
    case (.homebrewLatest, .codex): nil
    case (.npm, .claudeCode): "npm install -g @anthropic-ai/claude-code"
    case (.npm, .codex): "npm install -g @openai/codex"
    }
  }
}
#endif
