import CryptoKit
import Foundation
import Testing

@Suite(.serialized)
struct ReleaseWorkflowTests {
  @Test(arguments: [false, true])
  func preparationRecordsOnlyAValidatedCandidate(distributionFails: Bool) throws {
    let fixture = try ReleaseFixture()
    defer { fixture.remove() }
    try fixture.writeBundle(publicKey: nil)
    try fixture.write("scripts/create-dmg.sh", "#!/bin/sh\nprintf 'package\\n' >> dist/stages.txt\n", executable: true)
    try fixture.initializeRepository()
    try fixture.write("bin/make", "#!/bin/sh\nprintf 'build\\n' >> dist/stages.txt\n", executable: true)
    try fixture.write(
      "bin/codesign",
      "#!/bin/sh\nif [ \"$1\" = -dv ]; then printf 'Authority=Developer ID Application: Fixture\\n' >&2; fi\n",
      executable: true
    )
    try fixture.write("bin/spctl", "#!/bin/sh\nexit 0\n", executable: true)
    try fixture.write("bin/xcrun", "#!/bin/sh\nexit \(distributionFails ? 1 : 0)\n", executable: true)
    let result = try fixture.command(
      "/usr/bin/python3",
      ["-B", fixture.root.appendingPathComponent("scripts/release_workflow.py").path, "prepare"],
      environment: [
        "APPSHOW_SIGNING_IDENTITY": "Developer ID Application: Fixture", "APPSHOW_APPLE_ID": "fixture@example.invalid",
        "APPSHOW_TEAM_ID": "FIXTURE", "APPSHOW_APP_PASSWORD": "fixture-password",
      ]
    )
    #expect((result.status == 0) == !distributionFails, "\(result.output)")
    #expect(try fixture.read("dist/stages.txt") == "build\npackage\n")
    #expect(!fixture.hasExternalCalls)
    #expect(try fixture.command("/usr/bin/git", ["tag", "--list"]).output.isEmpty)
    let receipt = fixture.root.appendingPathComponent("dist/release.json")
    #expect(FileManager.default.fileExists(atPath: receipt.path) == !distributionFails)
    if !distributionFails {
      let document = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: receipt)) as? [String: Any])
      #expect(document["updates"] as? String == "manual")
      #expect(document["build"] as? String == "42")
      #expect(!FileManager.default.fileExists(atPath: fixture.root.appendingPathComponent("dist/appcast.xml").path))
    }
  }

  @Test func manualDownloadPreviewNeedsNoFeedAndPerformsNoExternalWrites() throws {
    let fixture = try ReleaseFixture()
    defer { fixture.remove() }
    try fixture.prepareCandidate()
    let result = try fixture.run("publish-release.sh", arguments: ["--dry-run"])
    #expect(result.status == 0, "\(result.output)")
    #expect(result.output.contains("manual"))
    #expect(!fixture.hasExternalCalls)
    #expect(!FileManager.default.fileExists(atPath: fixture.root.appendingPathComponent("dist/appcast.xml").path))
  }

  @Test(arguments: ["dirty", "archive", "notes", "tag", "commit"])
  func invalidCandidatesFailBeforeExternalCalls(change: String) throws {
    let fixture = try ReleaseFixture()
    defer { fixture.remove() }
    try fixture.prepareCandidate()
    switch change {
    case "dirty": try fixture.write("uncommitted.txt", "pending change")
    case "archive": try fixture.write("dist/AppShow-1.2.3.dmg", "replaced archive")
    case "notes": try fixture.write("dist/release-notes.md", "changed notes")
    case "tag":
      let other = try fixture.command("/usr/bin/git", ["commit-tree", "HEAD^{tree}", "-m", "other"]).output.trimmingCharacters(
        in: .whitespacesAndNewlines
      )
      #expect(try fixture.command("/usr/bin/git", ["tag", "-f", "v1.2.3", other]).status == 0)
    default:
      try fixture.write("new.txt", "another commit")
      try fixture.commit()
    }
    let result = try fixture.run("publish-release.sh", arguments: ["--publish"])
    #expect(result.status != 0)
    #expect(!fixture.hasExternalCalls)
  }

  @Test func tagRequiresCleanSourceAndDoesNotRewriteChangelog() throws {
    let fixture = try ReleaseFixture()
    defer { fixture.remove() }
    try fixture.initializeRepository()
    try fixture.write("CHANGELOG.md", "uncommitted notes")
    let rejected = try fixture.command("/usr/bin/make", ["tag"])
    #expect(rejected.status != 0)
    #expect(try fixture.command("/usr/bin/git", ["tag", "--list"]).output.isEmpty)
    try fixture.commit()
    let result = try fixture.command("/usr/bin/make", ["tag"])
    #expect(result.status == 0, "\(result.output)")
    #expect(try fixture.read("CHANGELOG.md") == "uncommitted notes")
    #expect(try fixture.command("/usr/bin/git", ["status", "--porcelain"]).output.isEmpty)
  }
}

extension ReleaseFixture {
  var hasExternalCalls: Bool {
    FileManager.default.fileExists(atPath: root.appendingPathComponent("dist/external-calls.txt").path)
  }

  func initializeRepository() throws {
    try write(".gitignore", ".build/\ndist/\nbin/\n")
    #expect(try command("/usr/bin/git", ["init", "-q"]).status == 0)
    #expect(try command("/usr/bin/git", ["config", "user.name", "Release Tests"]).status == 0)
    #expect(try command("/usr/bin/git", ["config", "user.email", "release@example.invalid"]).status == 0)
    try commit()
    try write(
      "bin/git",
      "#!/bin/sh\nif [ \"$1\" = push ]; then printf 'git push\\n' >> dist/external-calls.txt; exit 0; fi\nexec /usr/bin/git \"$@\"\n",
      executable: true
    )
    try write("bin/gh", "#!/bin/sh\nprintf 'gh called\\n' >> dist/external-calls.txt\nexit 0\n", executable: true)
  }

  func commit() throws {
    #expect(try command("/usr/bin/git", ["add", "."]).status == 0)
    #expect(
      try command(
        "/usr/bin/git",
        [
          "-c", "user.name=Release Tests", "-c", "user.email=release@example.invalid", "-c", "commit.gpgsign=false", "commit", "-qm",
          "fixture",
        ]
      ).status == 0
    )
  }

  func prepareCandidate() throws {
    try writeBundle(publicKey: nil)
    try initializeRepository()
    #expect(try command("/usr/bin/git", ["tag", "v1.2.3"]).status == 0)
    try write("dist/release-notes.md", "Release fixture")
    let commit = try command("/usr/bin/git", ["rev-parse", "HEAD"]).output.trimmingCharacters(in: .whitespacesAndNewlines)
    let artifacts = try ["AppShow-1.2.3.dmg", "release-notes.md"].map { name in
      let data = try Data(contentsOf: root.appendingPathComponent("dist/\(name)"))
      return ["name": name, "sha256": SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()]
    }
    let manifest: [String: Any] = [
      "schema": 1, "commit": commit, "version": "1.2.3", "build": "42", "updates": "manual", "artifacts": artifacts,
    ]
    try write("dist/release.json", String(decoding: JSONSerialization.data(withJSONObject: manifest), as: UTF8.self))
  }
}
