import Foundation
import Testing

@testable import Reframed

@Suite(.serialized)
struct AgentReadinessTests {
  @Test func readinessLabelsAreDistinctPerState() {
    #expect(AgentReadiness.missing(searchedPaths: []).statusLabel == "Not found")
    #expect(AgentReadiness.notLoggedIn(executable: "/bin/claude", version: "2.1.259").statusLabel == "Sign in required")
    #expect(AgentReadiness.ready(executable: "/bin/codex", version: "0.149.1").statusLabel == "Ready")
    #expect(AgentReadiness.unhealthy(executable: "/bin/codex", reason: "timed out").statusLabel == "Needs repair")
  }

  @Test func semanticVersionIsParsedFromProviderOutput() {
    #expect(AgentVersionParser.semanticVersion(from: "2.1.259 (Claude Code)") == "2.1.259")
    #expect(AgentVersionParser.semanticVersion(from: "codex-cli 0.149.1") == "0.149.1")
    #expect(AgentVersionParser.semanticVersion(from: "unknown") == nil)
  }

  @Test func claudeProbeReportsNotLoggedInFromAuthJSON() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let executable = try writeProvider(
      in: directory,
      body: """
        if [ "$1" = "--version" ]; then
          echo "2.1.259 (Claude Code)"
          exit 0
        fi
        echo '{"loggedIn":false}'
        """
    )
    let readiness = await AgentProbe(timeout: .seconds(10)).check(
      provider: .claudeCode,
      executable: executable,
      environment: environment(for: directory)
    )
    #expect(readiness == .notLoggedIn(executable: executable.path, version: "2.1.259"))
  }

  @Test func claudeProbeReportsReadyFromAuthJSON() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let executable = try writeProvider(
      in: directory,
      body: """
        if [ "$1" = "--version" ]; then
          echo "2.1.259 (Claude Code)"
          exit 0
        fi
        echo '{"loggedIn":true}'
        """
    )
    let readiness = await AgentProbe(timeout: .seconds(10)).check(
      provider: .claudeCode,
      executable: executable,
      environment: environment(for: directory)
    )
    #expect(readiness == .ready(executable: executable.path, version: "2.1.259"))
  }

  @Test func codexProbeReportsReadyFromLoginStatus() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let executable = try writeProvider(
      in: directory,
      body: """
        if [ "$1" = "--version" ]; then
          echo "codex-cli 0.149.1"
          exit 0
        fi
        echo "Logged in using ChatGPT"
        """
    )
    let readiness = await AgentProbe(timeout: .seconds(10)).check(
      provider: .codex,
      executable: executable,
      environment: environment(for: directory)
    )
    #expect(readiness == .ready(executable: executable.path, version: "0.149.1"))
  }

  @Test func codexProbeReportsNotLoggedInFromFailedStatus() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let executable = try writeProvider(
      in: directory,
      body: """
        if [ "$1" = "--version" ]; then
          echo "codex-cli 0.149.1"
          exit 0
        fi
        echo "Not logged in"
        exit 1
        """
    )
    let readiness = await AgentProbe(timeout: .seconds(10)).check(
      provider: .codex,
      executable: executable,
      environment: environment(for: directory)
    )
    #expect(readiness == .notLoggedIn(executable: executable.path, version: "0.149.1"))
  }

  @Test func probeReportsUnhealthyWhenVersionCommandTimesOut() async throws {
    let directory = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(directory) }
    let executable = try writeProvider(in: directory, body: "sleep 30")
    let readiness = await AgentProbe(timeout: .milliseconds(200)).check(
      provider: .codex,
      executable: executable,
      environment: environment(for: directory)
    )
    #expect(readiness == .unhealthy(executable: executable.path, reason: "Version check timed out"))
  }

  @Test func aSingleReadyProviderIsSelectedOverTheRememberedProvider() {
    let snapshot = AgentReadinessSnapshot(
      statuses: [
        .claudeCode: .missing(searchedPaths: []),
        .codex: .ready(executable: "/bin/codex", version: "0.149.1"),
      ]
    )
    #expect(snapshot.selection(remembered: .claudeCode) == .codex)
  }

  private func writeProvider(in directory: URL, body: String) throws -> URL {
    let url = directory.appendingPathComponent("provider")
    try "#!/bin/sh\n\(body)\n".write(to: url, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    return url
  }

  private func environment(for directory: URL) -> [String: String] {
    AgentEnvironment.scrubbed(path: "/usr/bin:/bin", home: directory.path, forwarding: [], source: [:])
  }
}
