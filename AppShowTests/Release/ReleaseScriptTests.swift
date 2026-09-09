import CryptoKit
import Foundation
import Testing

@Suite(.serialized)
struct ReleaseScriptTests {
  @Test func wrongSigningKeyDoesNotReplaceTheFeed() throws {
    let fixture = try ReleaseFixture()
    defer { fixture.remove() }
    try fixture.write("dist/appcast.xml", "previous feed")
    try fixture.write(
      ".build/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update",
      "#!/bin/sh\nprintf '%s\\n' '\(Data(repeating: 1, count: 64).base64EncodedString())'\n",
      executable: true
    )
    let result = try fixture.run("generate-appcast.sh")
    #expect(result.status != 0)
    #expect(try fixture.read("dist/appcast.xml") == "previous feed")
  }

  @Test func appcastUsesBuiltVersionBuildAndMinimumOS() throws {
    let fixture = try ReleaseFixture()
    defer { fixture.remove() }
    let result = try fixture.run("generate-appcast.sh")
    #expect(result.status == 0, "\(result.output)")
    let xml = try XMLDocument(contentsOf: fixture.root.appendingPathComponent("dist/appcast.xml"))
    #expect(try xml.nodes(forXPath: "//item/*[local-name()='version']").first?.stringValue == "42")
    #expect(try xml.nodes(forXPath: "//item/*[local-name()='shortVersionString']").first?.stringValue == "1.2.3")
    #expect(try xml.nodes(forXPath: "//item/*[local-name()='minimumSystemVersion']").first?.stringValue == "15.0")
  }

  @Test func staleBuiltVersionDoesNotReplaceTheFeed() throws {
    let fixture = try ReleaseFixture()
    defer { fixture.remove() }
    try fixture.write("dist/appcast.xml", "previous feed")
    try fixture.writeBundle(version: "1.2.2")
    let result = try fixture.run("generate-appcast.sh")
    #expect(result.status != 0)
    #expect(try fixture.read("dist/appcast.xml") == "previous feed")
  }

  @Test func missingPublicKeyDoesNotCreateAnUnusableFeed() throws {
    let fixture = try ReleaseFixture()
    defer { fixture.remove() }
    try fixture.writeBundle(publicKey: nil)
    let result = try fixture.run("generate-appcast.sh")
    #expect(result.status != 0)
    #expect(!FileManager.default.fileExists(atPath: fixture.root.appendingPathComponent("dist/appcast.xml").path))
  }
}

struct ReleaseFixture {
  let root: URL
  static let signingKey = try! Curve25519.Signing.PrivateKey(rawRepresentation: Data(repeating: 7, count: 32))

  init() throws {
    root = try TestPaths.makeTemporaryDirectory().appendingPathComponent("release with spaces", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    try FileManager.default.copyItem(at: source.appendingPathComponent("scripts"), to: root.appendingPathComponent("scripts"))
    try FileManager.default.copyItem(at: source.appendingPathComponent("Makefile"), to: root.appendingPathComponent("Makefile"))
    try write("Config.xcconfig", "MARKETING_VERSION = 1.2.3\nCURRENT_PROJECT_VERSION = 42\n")
    try write("dist/AppShow-1.2.3.dmg", "fixture archive")
    try writeBundle()
    try write(
      ".build/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update",
      "#!/bin/sh\nprintf '%s\\n' '\(try Self.signingKey.signature(for: Data("fixture archive".utf8)).base64EncodedString())'\n",
      executable: true
    )
  }

  func writeBundle(
    version: String = "1.2.3",
    publicKey: String? = ReleaseFixture.signingKey.publicKey.rawRepresentation.base64EncodedString()
  ) throws {
    var values: [String: Any] = [
      "CFBundleShortVersionString": version, "CFBundleVersion": "42", "LSMinimumSystemVersion": "15.0",
      "CFBundleIdentifier": "com.mattwebhub.appshow",
    ]
    values["SUPublicEDKey"] = publicKey
    let data = try PropertyListSerialization.data(fromPropertyList: values, format: .xml, options: 0)
    try write(".build/Build/Products/Release/AppShow.app/Contents/Info.plist", String(decoding: data, as: UTF8.self))
  }

  func write(_ path: String, _ contents: String, executable: Bool = false) throws {
    let url = root.appendingPathComponent(path)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try contents.write(to: url, atomically: true, encoding: .utf8)
    if executable { try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path) }
  }

  func read(_ path: String) throws -> String {
    try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
  }

  func run(_ script: String, arguments: [String] = []) throws -> (status: Int32, output: String) {
    try command("/bin/bash", [root.appendingPathComponent("scripts/\(script)").path] + arguments)
  }

  func command(_ executable: String, _ arguments: [String], environment: [String: String] = [:]) throws -> (status: Int32, output: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.currentDirectoryURL = root
    process.environment = [
      "PATH": root.appendingPathComponent("bin").path + ":/usr/bin:/bin:/usr/sbin:/sbin",
      "APPSHOW_SPARKLE_KEY": "fixture-key", "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_NOSYSTEM": "1",
    ]
    process.environment?.merge(environment) { _, replacement in replacement }
    let output = Pipe()
    process.standardOutput = output
    process.standardError = output
    try process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return (process.terminationStatus, String(decoding: data, as: UTF8.self))
  }

  func remove() { TestPaths.remove(root.deletingLastPathComponent()) }
}
