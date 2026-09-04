import Foundation
import Testing

@testable import AppShow

@Suite(.serialized)
struct AgentProcessRunnerTests {
  private static let fakeExecutable = """
    #!/bin/sh
    trap 'echo terminated; exit 143' TERM
    printf 'first\\n'
    printf 'sec'
    sleep 0.1
    printf 'ond\\n'
    printf 'third\\n'
    if [ "$1" = "hang" ]; then
      while true; do sleep 0.05; done
    fi
    if [ "$1" = "fail" ]; then
      echo 'something broke' >&2
      exit 3
    fi
    exit 0
    """

  private func writeFakeExecutable(in directory: URL, name: String = "fake-agent", body: String = fakeExecutable) throws -> URL {
    let url = directory.appendingPathComponent(name)
    try body.write(to: url, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    return url
  }

  private func environment(for directory: URL) -> [String: String] {
    AgentEnvironment.scrubbed(path: "/usr/bin:/bin", home: directory.path, forwarding: [])
  }

  private func collect(_ stream: AsyncThrowingStream<String, Error>) async throws -> [String] {
    var lines: [String] = []
    for try await line in stream {
      lines.append(line)
    }
    return lines
  }

  @Test func runnerStreamsEachStdoutLineInOrderAndJoinsSplitLines() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let executable = try writeFakeExecutable(in: dir)
    let runner = AgentProcessRunner()
    let launch = AgentProcessLaunch(executable: executable, arguments: ["ok"], workingDirectory: dir, environment: environment(for: dir))
    let lines = try await collect(await runner.run(launch))
    #expect(lines == ["first", "second", "third"])
    #expect(await runner.exitStatus == 0)
    #expect(await runner.isRunning == false)
  }

  @Test func runnerThrowsProcessFailedWithStderrTailOnNonZeroExit() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let executable = try writeFakeExecutable(in: dir)
    let runner = AgentProcessRunner()
    let launch = AgentProcessLaunch(executable: executable, arguments: ["fail"], workingDirectory: dir, environment: environment(for: dir))
    var lines: [String] = []
    var failure: AgentError?
    do {
      for try await line in await runner.run(launch) {
        lines.append(line)
      }
    } catch let error as AgentError {
      failure = error
    }
    #expect(lines == ["first", "second", "third"])
    #expect(failure == .processFailed(status: 3, stderrTail: "something broke"))
    #expect(await runner.exitStatus == 3)
  }

  @Test func runnerWritesStandardInputThenClosesIt() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let runner = AgentProcessRunner()
    let launch = AgentProcessLaunch(
      executable: URL(fileURLWithPath: "/bin/cat"),
      arguments: [],
      workingDirectory: dir,
      environment: environment(for: dir),
      standardInput: "hello from stdin\nsecond line\n"
    )
    let lines = try await collect(await runner.run(launch))
    #expect(lines == ["hello from stdin", "second line"])
  }

  @Test func runnerUsesOnlyTheGivenEnvironment() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let runner = AgentProcessRunner()
    let launch = AgentProcessLaunch(
      executable: URL(fileURLWithPath: "/usr/bin/env"),
      arguments: [],
      workingDirectory: dir,
      environment: environment(for: dir)
    )
    let lines = try await collect(await runner.run(launch))
    let keys = Set(lines.compactMap { $0.split(separator: "=", maxSplits: 1).first.map(String.init) })
    #expect(keys == ["PATH", "HOME", "LANG", "TERM", "USER", "LOGNAME"])
    #expect(lines.contains("HOME=\(dir.path)"))
    #expect(!keys.contains("APPSHOW_HOME"))
    #expect(!keys.contains("APPSHOW_TMP"))
    #expect(!keys.contains("REFRAMED_HOME"))
    #expect(!keys.contains("REFRAMED_TMP"))
  }

  @Test func runnerRunsInTheGivenWorkingDirectory() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let runner = AgentProcessRunner()
    let launch = AgentProcessLaunch(
      executable: URL(fileURLWithPath: "/bin/pwd"),
      arguments: [],
      workingDirectory: dir,
      environment: environment(for: dir)
    )
    let lines = try await collect(await runner.run(launch))
    #expect(lines.count == 1)
    #expect(
      lines.first.map { URL(fileURLWithPath: $0).standardizedFileURL.resolvingSymlinksInPath() }
        == dir.standardizedFileURL.resolvingSymlinksInPath()
    )
  }

  @Test func runnerCancelTerminatesTheProcessAndFinishesTheStreamWithCancelled() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let executable = try writeFakeExecutable(in: dir)
    let runner = AgentProcessRunner()
    let launch = AgentProcessLaunch(executable: executable, arguments: ["hang"], workingDirectory: dir, environment: environment(for: dir))
    var lines: [String] = []
    var failure: AgentError?
    do {
      for try await line in await runner.run(launch) {
        lines.append(line)
        if line == "third" {
          await runner.cancel()
        }
      }
    } catch let error as AgentError {
      failure = error
    }
    #expect(lines.prefix(3) == ["first", "second", "third"])
    #expect(failure == .cancelled)
    #expect(await runner.isRunning == false)
    #expect(await runner.exitStatus != 0)
  }

  @Test func runnerTerminatesTheProcessWhenTheConsumingTaskIsCancelled() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let executable = try writeFakeExecutable(in: dir)
    let runner = AgentProcessRunner()
    let launch = AgentProcessLaunch(executable: executable, arguments: ["hang"], workingDirectory: dir, environment: environment(for: dir))
    let stream = await runner.run(launch)
    let consumer = Task {
      var seen: [String] = []
      do {
        for try await line in stream {
          seen.append(line)
        }
      } catch {}
      return seen
    }
    while await runner.linesDelivered < 3 {
      try await Task.sleep(for: .milliseconds(10))
    }
    consumer.cancel()
    let seen = await consumer.value
    #expect(seen.prefix(3) == ["first", "second", "third"])
    let deadline = Date().addingTimeInterval(2)
    while await runner.isRunning, Date() < deadline {
      try await Task.sleep(for: .milliseconds(10))
    }
    #expect(await runner.isRunning == false)
  }

  @Test func runnerFailsToLaunchAMissingExecutable() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let runner = AgentProcessRunner()
    let launch = AgentProcessLaunch(
      executable: dir.appendingPathComponent("missing"),
      arguments: [],
      workingDirectory: dir,
      environment: environment(for: dir)
    )
    var failure: AgentError?
    do {
      for try await _ in await runner.run(launch) {}
    } catch let error as AgentError {
      failure = error
    }
    guard case .launchFailed? = failure else {
      Issue.record("expected launchFailed, got \(String(describing: failure))")
      return
    }
  }

  @Test func runnerRejectsLinesOverTheCap() async throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let body = """
      #!/bin/sh
      head -c 3000 /dev/zero | tr '\\0' x
      echo
      echo after
      """
    let executable = try writeFakeExecutable(in: dir, name: "long-line", body: body)
    let runner = AgentProcessRunner(maximumLineLength: 2048)
    let launch = AgentProcessLaunch(executable: executable, arguments: [], workingDirectory: dir, environment: environment(for: dir))
    var failure: AgentError?
    do {
      for try await _ in await runner.run(launch) {}
    } catch let error as AgentError {
      failure = error
    }
    #expect(failure == .lineTooLong)
    #expect(await runner.isRunning == false)
  }

  @Test func scrubbedEnvironmentForwardsOnlyRequestedKeysThatExist() {
    let environment = AgentEnvironment.scrubbed(
      path: "/opt/homebrew/bin:/usr/bin",
      home: "/Users/example",
      forwarding: ["PATH", "SHELL"],
      source: ["SHELL": "/bin/zsh", "APPSHOW_HOME": "/tmp/x", "LANG": "pt_BR.UTF-8", "USER": "runner"]
    )
    #expect(
      environment == [
        "PATH": "/opt/homebrew/bin:/usr/bin", "HOME": "/Users/example", "LANG": "pt_BR.UTF-8", "TERM": "xterm-256color",
        "USER": "runner", "LOGNAME": "runner", "SHELL": "/bin/zsh",
      ]
    )
  }
}
