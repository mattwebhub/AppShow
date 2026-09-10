import Foundation
import Testing

@testable import AppShow

struct AgentStoreRuntimeTests {
  @Test func storeCreatesPrivateTemporaryStorageBeforeLaunchingProviders() throws {
    let root = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(root) }
    let temporaryRoot = root.appendingPathComponent("tmp/agents")
    let policy = AgentRuntimePolicy(
      sandboxed: true,
      bundleURL: root.appendingPathComponent("Test.app"),
      stateRoot: root.appendingPathComponent("state"),
      temporaryRoot: temporaryRoot
    )
    try policy.prepare()
    let attributes = try FileManager.default.attributesOfItem(atPath: temporaryRoot.path)
    #expect(attributes[.posixPermissions] as? Int == 0o700)
    let environment = policy.environment(path: "", home: root.path, forwarding: [], source: [:])
    #expect(environment["TMPDIR"] == temporaryRoot.path)
    #expect(environment["CLAUDE_CODE_TMPDIR"] == temporaryRoot.path)
  }

  @Test func storeOverridesClaudesGlobalTemporaryDirectory() throws {
    let policy = AgentRuntimePolicy(
      sandboxed: true,
      bundleURL: URL(fileURLWithPath: "/Test.app"),
      stateRoot: URL(fileURLWithPath: "/container/agents")
    )
    let environment = policy.environment(
      path: "/outside/bin",
      home: "/container",
      forwarding: ["TMPDIR", "CLAUDE_CODE_TMPDIR"],
      source: ["TMPDIR": "/outside/tmp", "CLAUDE_CODE_TMPDIR": "/tmp"]
    )
    let temporaryDirectory = try #require(environment["CLAUDE_CODE_TMPDIR"])
    #expect(temporaryDirectory.hasPrefix(AppShowPaths.temp.path + "/"))
    #expect(environment["TMPDIR"] == temporaryDirectory)
  }

  @Test func directProviderRunsDoNotSelfUpdateTheUsersInstallation() {
    let policy = AgentRuntimePolicy(
      sandboxed: false,
      bundleURL: URL(fileURLWithPath: "/Test.app"),
      stateRoot: URL(fileURLWithPath: "/fixture/state")
    )
    let environment = policy.environment(path: "/fixture/bin", home: "/fixture", forwarding: [], source: [:])
    #expect(environment["DISABLE_AUTOUPDATER"] == "1")
    #expect(environment["DISABLE_UPDATES"] == "1")
    #expect(environment["CODEX_HOME"] == nil)
    #expect(environment["CLAUDE_CONFIG_DIR"] == nil)
    #expect(environment["CLAUDE_CODE_TMPDIR"] == nil)
  }

  @Test func storeResolutionRejectsOutsideExecutablesAndSymlinkEscapes() throws {
    let root = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(root) }
    let policy = AgentRuntimePolicy(
      sandboxed: true,
      bundleURL: root.appendingPathComponent("Test.app"),
      stateRoot: root.appendingPathComponent("state")
    )
    try FileManager.default.createDirectory(at: policy.runtimeDirectory, withIntermediateDirectories: true)
    let bundled = policy.runtimeDirectory.appendingPathComponent("codex")
    try Data().write(to: bundled)
    #expect(policy.permits(bundled))
    #expect(!policy.permits(root.appendingPathComponent("codex")))
    #expect(!policy.permits(policy.runtimeDirectory.appendingPathComponent("other")))
    let outside = root.appendingPathComponent("outside")
    try Data().write(to: outside)
    let escape = policy.runtimeDirectory.appendingPathComponent("claude")
    try FileManager.default.createSymbolicLink(at: escape, withDestinationURL: outside)
    #expect(!policy.permits(escape))
  }

  @Test func storeEnvironmentIgnoresExternalProviderHomesAndDisablesRuntimeUpdates() {
    let policy = AgentRuntimePolicy(
      sandboxed: true,
      bundleURL: URL(fileURLWithPath: "/Test.app"),
      stateRoot: URL(fileURLWithPath: "/container/agents")
    )
    let environment = policy.environment(
      path: "/untrusted/bin",
      home: "/container",
      forwarding: ["CODEX_HOME", "CLAUDE_CONFIG_DIR", "SECRET"],
      source: ["CODEX_HOME": "/outside/codex", "CLAUDE_CONFIG_DIR": "/outside/claude", "SECRET": "private", "USER": "tester"]
    )
    #expect(environment["CODEX_HOME"] == "/container/agents/codex")
    #expect(environment["CLAUDE_CONFIG_DIR"] == "/container/agents/claude")
    #expect(environment["SECRET"] == nil)
    #expect(environment["DISABLE_AUTOUPDATER"] == "1")
    #expect(environment["DISABLE_UPDATES"] == "1")
    #expect(environment["PATH"]?.hasPrefix(policy.runtimeDirectory.path + ":") == true)
    #expect(environment["PATH"]?.contains("untrusted") == false)
  }

  @Test func storeWorkspacesStayInTheContainerAndSeparateSameNamedProjects() {
    let root = URL(fileURLWithPath: "/container/workspaces")
    let first = URL(fileURLWithPath: "/selected/first/Demo.appshow")
    let second = URL(fileURLWithPath: "/selected/second/Demo.appshow")
    let workspace = AgentWorkspace.directory(forBundle: first, containerRoot: root)
    #expect(workspace.deletingLastPathComponent().path == root.path)
    #expect(workspace != AgentWorkspace.directory(forBundle: second, containerRoot: root))
    #expect(workspace == AgentWorkspace.directory(forBundle: first, containerRoot: root))
  }

  @Test func signInOnlyOpensHTTPSProviderAuthorizationPages() {
    #expect(
      AgentSignInURL.parse("Sign in: https://auth.openai.com/oauth/authorize?state=sample", provider: .codex)?.host == "auth.openai.com"
    )
    #expect(AgentSignInURL.parse("https://claude.ai/oauth/authorize?state=sample", provider: .claudeCode)?.host == "claude.ai")
    #expect(AgentSignInURL.parse("https://attacker.invalid/oauth/authorize", provider: .codex) == nil)
    #expect(AgentSignInURL.parse("https://auth.openai.com.attacker.invalid/oauth/authorize", provider: .codex) == nil)
    #expect(AgentSignInURL.parse("http://auth.openai.com/oauth/authorize", provider: .codex) == nil)
    #expect(AgentSignInURL.parse("https://auth.openai.com/logout", provider: .codex) == nil)
  }

  @Test func storeSendWithoutABridgeReportsFailureWithoutCreatingALegacyWorkspace() throws {
    let root = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(root) }
    let project = root.appendingPathComponent("Demo.appshow")
    #expect(throws: AgentError.self) {
      try AgentSendPreparation.workspace(project: project, configuration: nil, sandboxed: true)
    }
    #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent(".agent").path))
  }
}
