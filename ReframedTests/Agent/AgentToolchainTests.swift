import Foundation
import Testing

@testable import Reframed

@Suite(.serialized)
struct AgentToolchainTests {
  @discardableResult
  private func writeExecutable(
    _ name: String,
    in directory: URL,
    executable: Bool = true,
    body: String = "#!/bin/sh\necho hi\n"
  ) throws -> URL {
    let url = directory.appendingPathComponent(name)
    try body.write(to: url, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: executable ? 0o755 : 0o644], ofItemAtPath: url.path)
    return url
  }

  @Test func toolchainFindsExecutableInFirstMatchingPathDirectory() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let first = dir.appendingPathComponent("first", isDirectory: true)
    let second = dir.appendingPathComponent("second", isDirectory: true)
    try FileManager.default.createDirectory(at: first, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: second, withIntermediateDirectories: true)
    try writeExecutable("claude", in: second)
    let expected = try writeExecutable("claude", in: first)
    let toolchain = AgentToolchain(path: "\(first.path):\(second.path)", loginShell: nil)
    let resolved = await toolchain.resolve(["claude"])
    #expect(resolved == expected)
  }

  @Test func toolchainTriesEachExecutableNameInOrder() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let expected = try writeExecutable("codex", in: dir)
    let toolchain = AgentToolchain(path: dir.path, loginShell: nil)
    #expect(await toolchain.resolve(["claude", "codex"]) == expected)
  }

  @Test func toolchainIgnoresNonExecutableFilesAndDirectories() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    try writeExecutable("claude", in: dir, executable: false)
    try FileManager.default.createDirectory(at: dir.appendingPathComponent("codex"), withIntermediateDirectories: true)
    let toolchain = AgentToolchain(path: dir.path, loginShell: nil)
    #expect(await toolchain.resolve(["claude"]) == nil)
    #expect(await toolchain.resolve(["codex"]) == nil)
  }

  @Test func toolchainReturnsNilWhenNothingMatchesAndNoLoginShell() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let toolchain = AgentToolchain(path: "\(dir.path):/nonexistent/dir", loginShell: nil)
    #expect(await toolchain.resolve(["claude"]) == nil)
  }

  @Test func toolchainCachesResolvedExecutables() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let expected = try writeExecutable("claude", in: dir)
    let toolchain = AgentToolchain(path: dir.path, loginShell: nil)
    #expect(await toolchain.resolve(["claude"]) == expected)
    try FileManager.default.removeItem(at: expected)
    #expect(await toolchain.resolve(["claude"]) == expected)
    await toolchain.invalidate()
    #expect(await toolchain.resolve(["claude"]) == nil)
  }

  @Test func toolchainFallsBackToTheLoginShell() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let hidden = dir.appendingPathComponent("hidden", isDirectory: true)
    try FileManager.default.createDirectory(at: hidden, withIntermediateDirectories: true)
    let expected = try writeExecutable("claude", in: hidden)
    let shell = try writeExecutable(
      "fake-shell",
      in: dir,
      body: """
        #!/bin/sh
        echo "$1 $2" > "\(dir.path)/shell-args.txt"
        echo "profile noise"
        echo "\(expected.path)"
        """
    )
    let toolchain = AgentToolchain(path: dir.path, loginShell: shell)
    #expect(await toolchain.resolve(["claude"]) == expected)
    let args = try String(contentsOf: dir.appendingPathComponent("shell-args.txt"), encoding: .utf8)
    #expect(args == "-lc command -v claude\n")
  }

  @Test func toolchainRejectsLoginShellAnswersThatAreNotExecutableFiles() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let shell = try writeExecutable(
      "fake-shell",
      in: dir,
      body: """
        #!/bin/sh
        echo "claude: aliased to /nowhere/claude"
        echo "\(dir.path)/missing-claude"
        """
    )
    let toolchain = AgentToolchain(path: dir.path, loginShell: shell)
    #expect(await toolchain.resolve(["claude"]) == nil)
  }

  @Test func toolchainSurvivesALoginShellThatHangs() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let shell = try writeExecutable("fake-shell", in: dir, body: "#!/bin/sh\nsleep 30\n")
    let toolchain = AgentToolchain(path: dir.path, loginShell: shell, loginShellTimeout: .milliseconds(200))
    let started = Date()
    #expect(await toolchain.resolve(["claude"]) == nil)
    #expect(Date().timeIntervalSince(started) < 5)
  }

  @Test func searchPathJoinsPathAndResolvedDirectories() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let hidden = dir.appendingPathComponent("hidden", isDirectory: true)
    try FileManager.default.createDirectory(at: hidden, withIntermediateDirectories: true)
    let expected = try writeExecutable("claude", in: hidden)
    let shell = try writeExecutable("fake-shell", in: dir, body: "#!/bin/sh\necho \"\(expected.path)\"\n")
    let toolchain = AgentToolchain(path: dir.path, loginShell: shell)
    #expect(await toolchain.searchPath() == dir.path)
    _ = await toolchain.resolve(["claude"])
    #expect(await toolchain.searchPath() == "\(dir.path):\(hidden.path)")
  }

  @Test func defaultSearchDirectoriesIncludeCommonInstallLocations() {
    let directories = AgentToolchain.defaultSearchDirectories(home: URL(fileURLWithPath: "/Users/example"))
    let paths = directories.map(\.path)
    #expect(paths.contains("/Users/example/.local/bin"))
    #expect(paths.contains("/opt/homebrew/bin"))
    #expect(paths.contains("/usr/local/bin"))
    #expect(paths.contains("/usr/bin"))
    #expect(paths.contains("/bin"))
    #expect(Set(paths).count == paths.count)
  }
}
