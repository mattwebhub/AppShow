import Foundation
import Testing

@testable import Reframed

struct AgentWorkspaceTests {
  private func makeBundle(in dir: URL, name: String = "Screen-2026-09-04-101010") throws -> URL {
    let bundle = dir.appendingPathComponent("\(name).frm", isDirectory: true)
    try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
    return bundle
  }

  @Test func directoryLivesNextToTheBundleUnderDotAgent() {
    let bundle = URL(fileURLWithPath: "/Users/me/Movies/Reframed/Screen-2026-09-04-101010.frm", isDirectory: true)
    let directory = AgentWorkspace.directory(forBundle: bundle)
    #expect(directory.path == "/Users/me/Movies/Reframed/.agent/Screen-2026-09-04-101010")
  }

  @Test func socketStaysInsideShortWorkspacesAndFallsBackForLongOnes() {
    let short = URL(fileURLWithPath: "/tmp/r/.agent/Screen", isDirectory: true)
    let fallback = URL(fileURLWithPath: "/tmp/r-fallback", isDirectory: true)
    #expect(AgentWorkspace.socketURL(forWorkspace: short, fallbackRoot: fallback).path == "/tmp/r/.agent/Screen/bridge.sock")

    let long = URL(
      fileURLWithPath: "/Users/someone/Library/Mobile Documents/com~apple~CloudDocs/" + String(repeating: "x", count: 60),
      isDirectory: true
    )
    let socket = AgentWorkspace.socketURL(forWorkspace: long, fallbackRoot: fallback)
    #expect(socket.path.hasPrefix(fallback.path + "/"))
    #expect(socket.pathExtension == "sock")
    #expect(socket.path.utf8.count <= AgentWorkspace.maxSocketPathLength)
    #expect(AgentWorkspace.socketURL(forWorkspace: long, fallbackRoot: fallback) == socket)
    let other = long.appendingPathComponent("y", isDirectory: true)
    #expect(AgentWorkspace.socketURL(forWorkspace: other, fallbackRoot: fallback) != socket)
  }

  @Test func generatedTokensAreLongHexAndDistinct() {
    let first = AgentWorkspace.generateToken()
    let second = AgentWorkspace.generateToken()
    #expect(first.count == 64)
    #expect(first != second)
    #expect(first.allSatisfy { $0.isHexDigit })
  }

  @Test func createMakesTheFoldersAndWritesAPrivateSessionFile() throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let bundle = try makeBundle(in: dir)

    let workspace = try AgentWorkspace.create(forBundle: bundle, token: String(repeating: "a", count: 64))

    #expect(workspace.directory == dir.appendingPathComponent(".agent/Screen-2026-09-04-101010", isDirectory: true))
    #expect(workspace.bundleURL == bundle)
    #expect(workspace.token == String(repeating: "a", count: 64))
    #expect(workspace.framesDirectory == workspace.directory.appendingPathComponent("frames", isDirectory: true))
    var isDirectory: ObjCBool = false
    #expect(FileManager.default.fileExists(atPath: workspace.framesDirectory.path, isDirectory: &isDirectory) && isDirectory.boolValue)
    #expect(workspace.sessionFileURL == workspace.directory.appendingPathComponent("session.json"))
    let attributes = try FileManager.default.attributesOfItem(atPath: workspace.sessionFileURL.path)
    #expect((attributes[.posixPermissions] as? Int) == 0o600)

    let session = try AgentWorkspace.readSession(in: workspace.directory)
    #expect(session.socketPath == workspace.socketURL.path)
    #expect(session.token == workspace.token)
    #expect(session.bundlePath == bundle.path)
    #expect(session.workspacePath == workspace.directory.path)
    #expect(session.protocolVersion == AgentToolCatalog.protocolVersion)
    #expect(abs(session.createdAt.timeIntervalSinceNow) < 60)
    let raw = try JSONValue.parse(try Data(contentsOf: workspace.sessionFileURL))
    #expect(raw["socketPath"] == .string(workspace.socketURL.path))
    #expect(raw["token"] == .string(workspace.token))
  }

  @Test func createAgainReplacesTheSessionToken() throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let bundle = try makeBundle(in: dir)
    let first = try AgentWorkspace.create(forBundle: bundle)
    let second = try AgentWorkspace.create(forBundle: bundle)
    #expect(first.token != second.token)
    #expect(try AgentWorkspace.readSession(in: second.directory).token == second.token)
    #expect(first.directory == second.directory)
  }

  @Test func closeRemovesSessionAndSocketButKeepsFrames() throws {
    let dir = try TestPaths.makeTemporaryDirectory()
    defer { TestPaths.remove(dir) }
    let bundle = try makeBundle(in: dir, name: "Short")
    let workspace = try AgentWorkspace.create(forBundle: bundle)
    let frame = workspace.framesDirectory.appendingPathComponent("frame-1000ms-64w.png")
    try Data([0x89]).write(to: frame)
    if workspace.socketURL.path.hasPrefix(workspace.directory.path) {
      try Data().write(to: workspace.socketURL)
    }

    workspace.close()

    #expect(FileManager.default.fileExists(atPath: workspace.sessionFileURL.path) == false)
    #expect(FileManager.default.fileExists(atPath: workspace.socketURL.path) == false)
    #expect(FileManager.default.fileExists(atPath: frame.path))
    #expect(throws: (any Error).self) {
      try AgentWorkspace.readSession(in: workspace.directory)
    }
  }
}
