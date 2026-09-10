import SwiftUI

extension SettingsView {
  var shortcutsContent: some View {
    Group {
      if AppDistribution.isStore {
        Text("Shortcuts work while AppShow is active. Use the recording toolbar or menu bar controls while working in another app.")
          .font(.system(size: FontSize.xs))
          .foregroundStyle(AppShowColors.secondaryText)
      }
      settingsRow(label: "Mode Selection") {
        VStack(spacing: 4) {
          ShortcutRow(action: .switchToDisplay)
          ShortcutRow(action: .switchToWindow)
          ShortcutRow(action: .switchToArea)
        }
      }

      settingsRow(label: "Recording Controls") {
        VStack(spacing: 4) {
          ShortcutRow(action: .stopRecording)
          ShortcutRow(action: .pauseResumeRecording)
          ShortcutRow(action: .restartRecording)
        }
      }

      settingsRow(label: "Editor") {
        VStack(spacing: 4) {
          ShortcutRow(action: .editorUndo)
          ShortcutRow(action: .editorRedo)
        }
      }

      HStack {
        Spacer()
        Button("Reset All to Defaults") {
          ConfigService.shared.resetAllShortcuts()
          NotificationCenter.default.post(name: .shortcutsDidChange, object: nil)
        }
        .buttonStyle(OutlineButtonStyle(size: .small))
      }
    }
  }
}
