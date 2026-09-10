import Foundation
import Testing

@testable import Reframed

struct AgentSecurityTests {
  static let forbiddenArguments = [
    "--dangerously-skip-permissions",
    "--allow-dangerously-skip-permissions",
    "bypassPermissions",
    "--dangerously-bypass-approvals-and-sandbox",
    "--dangerously-bypass-hook-trust",
    "--full-auto",
    "--yolo",
    "--approve-for-me",
    "--ask-for-approval",
    "-a",
    "-c",
    "--config",
    "danger-full-access",
    "workspace-write",
  ]

  static let providers: [any AgentProvider] = [ClaudeCodeProvider(), CodexProvider()]

  static var turns: [AgentTurn] {
    let prompts = ["Trim the first second"] + forbiddenArguments + ["--", "-p", "--resume", "exec resume 1"]
    return prompts.flatMap { [AgentTurn(prompt: $0), AgentTurn(prompt: $0, resumeID: "019f-session")] }
  }

  @Test(arguments: AgentProviderKind.allCases)
  func argumentBuildersNeverEmitBypassFlags(kind: AgentProviderKind) {
    let provider = kind.makeProvider()
    for turn in Self.turns {
      let arguments = provider.arguments(for: turn)
      let separator = arguments.firstIndex(of: "--") ?? arguments.count
      let flags = Array(arguments.prefix(separator))
      for forbidden in Self.forbiddenArguments {
        #expect(!flags.contains(forbidden), "\(kind) emitted \(forbidden) for prompt \(turn.prompt)")
      }
    }
  }

  @Test func promptsThatLookLikeFlagsAreNeverParsedAsFlags() {
    for turn in Self.turns {
      let claude = ClaudeCodeProvider().arguments(for: turn)
      let neutral = ClaudeCodeProvider().arguments(for: AgentTurn(prompt: "neutral", resumeID: turn.resumeID))
      #expect(claude == neutral)
      #expect(ClaudeCodeProvider().standardInput(for: turn) == turn.prompt)
      let codex = CodexProvider().arguments(for: turn)
      let separator = codex.firstIndex(of: "--")
      #expect(separator != nil)
      #expect(codex.last == turn.prompt)
      if let separator {
        #expect(!codex.prefix(separator).contains(turn.prompt))
      }
    }
  }

  @Test func claudePermissionModeIsAlwaysDefault() {
    for turn in Self.turns {
      let arguments = ClaudeCodeProvider().arguments(for: turn)
      let index = arguments.firstIndex(of: "--permission-mode")
      #expect(index != nil)
      if let index {
        #expect(arguments[index + 1] == "default")
      }
      #expect(arguments.filter { $0 == "--permission-mode" }.count == 1)
      #expect(!arguments.contains("--permission-prompts"))
    }
  }

  @Test func claudeAllowedToolsAreReadOnly() {
    let arguments = ClaudeCodeProvider().arguments(for: AgentTurn(prompt: "x"))
    var allowed: [String] = []
    for (index, argument) in arguments.enumerated() where argument == "--allowedTools" {
      allowed.append(arguments[index + 1])
    }
    #expect(allowed == ["Read", "Glob", "Grep"])
    #expect(!arguments.contains("--tools"))
  }

  @Test func codexSandboxIsAlwaysReadOnly() {
    for turn in Self.turns {
      let arguments = CodexProvider().arguments(for: turn)
      let separator = arguments.firstIndex(of: "--") ?? arguments.count
      let flags = Array(arguments.prefix(separator))
      let index = flags.firstIndex(of: "--sandbox")
      #expect(index != nil)
      if let index {
        #expect(flags[index + 1] == "read-only")
      }
      #expect(flags.filter { $0 == "--sandbox" }.count == 1)
      #expect(flags.filter { $0 == "-s" }.isEmpty)
    }
  }

  @Test func agentSourcesNeverMentionBypassFlags() throws {
    let root = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let agentDirectory = root.appendingPathComponent("Reframed/Agent", isDirectory: true)
    let files = try FileManager.default.contentsOfDirectory(atPath: agentDirectory.path).filter { $0.hasSuffix(".swift") }
    #expect(!files.isEmpty)
    let spelledFlags = [
      "dangerously-skip-permissions",
      "dangerously-bypass-approvals-and-sandbox",
      "dangerously-bypass-hook-trust",
      "bypassPermissions",
      "full-auto",
      "yolo",
      "danger-full-access",
      "workspace-write",
      "approve-for-me",
    ]
    for file in files {
      let source = try String(contentsOf: agentDirectory.appendingPathComponent(file), encoding: .utf8)
      for flag in spelledFlags {
        #expect(!source.contains(flag), "\(file) mentions \(flag)")
      }
    }
  }
}
