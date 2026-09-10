import AVFoundation
import Foundation
import Security
import Testing

@testable import AppShowStore

@MainActor
@Suite(.serialized)
struct StoreSmokeTests {
  @Test func hostIsSandboxedAndUsesOnlyIsolatedTestStorage() throws {
    #expect(AppDistribution.isStore)
    #expect(LaunchEnvironment.isTestHost)
    var code: SecCode?
    #expect(SecCodeCopySelf([], &code) == errSecSuccess)
    var staticCode: SecStaticCode?
    #expect(SecCodeCopyStaticCode(try #require(code), [], &staticCode) == errSecSuccess)
    var information: CFDictionary?
    #expect(
      SecCodeCopySigningInformation(try #require(staticCode), SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess
    )
    let dictionary = try #require(information as? [String: Any])
    let entitlements = try #require(dictionary[kSecCodeInfoEntitlementsDict as String] as? [String: Any])
    #expect(entitlements["com.apple.security.app-sandbox"] as? Bool == true)
    #expect(!PermissionStore.live().requiresAccessibility)
    let temporary = FileManager.default.temporaryDirectory.standardizedFileURL.path
    #expect(AppShowPaths.home.standardizedFileURL.path.hasPrefix(temporary + "/"))
    #expect(AppShowPaths.temp.standardizedFileURL.path.hasPrefix(temporary + "/"))
    #expect(Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") == nil)
    let helper = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/appshow-mcp")
    #expect(FileManager.default.isExecutableFile(atPath: helper.path))
    var helperCode: SecStaticCode?
    #expect(SecStaticCodeCreateWithPath(helper as CFURL, [], &helperCode) == errSecSuccess)
    var helperInformation: CFDictionary?
    #expect(
      SecCodeCopySigningInformation(try #require(helperCode), SecCSFlags(rawValue: kSecCSSigningInformation), &helperInformation)
        == errSecSuccess
    )
    let helperDictionary = try #require(helperInformation as? [String: Any])
    let helperEntitlements = try #require(helperDictionary[kSecCodeInfoEntitlementsDict as String] as? [String: Any])
    #expect(helperEntitlements["com.apple.security.app-sandbox"] as? Bool == true)
    #expect(helperEntitlements["com.apple.security.inherit"] as? Bool == true)
    #expect(helperEntitlements.count == 2)
    let runtime = AgentRuntimePolicy()
    for name in ["codex", "claude"] {
      let executable = runtime.runtimeDirectory.appendingPathComponent(name)
      #expect(runtime.permits(executable))
      #expect(FileManager.default.isExecutableFile(atPath: executable.path))
    }
    #expect(!runtime.permits(URL(fileURLWithPath: "/usr/local/bin/codex")))
  }

  @Test func nativeBookmarkPersistsAndRestoresContainerAccess() throws {
    let directory = AppShowPaths.temp.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let selection = directory.appendingPathComponent("selected", isDirectory: true)
    try FileManager.default.createDirectory(at: selection, withIntermediateDirectories: false)
    let database = directory.appendingPathComponent("bookmarks.json")
    var store: BookmarkAccessStore? = try BookmarkAccessStore(fileURL: database)
    try store?.remember(selection, key: "folder")
    store = nil
    store = try BookmarkAccessStore(fileURL: database)
    let resolved = try store?.resolve(key: "folder", fallback: directory)
    let restored = try #require(resolved)
    #expect(restored.standardizedFileURL == selection.standardizedFileURL)
    let marker = restored.appendingPathComponent("marker.txt")
    try Data("sandbox bookmark".utf8).write(to: marker)
    #expect(try String(contentsOf: marker, encoding: .utf8) == "sandbox bookmark")
    store = nil
  }

  @Test(arguments: [ExportMode.normal, ExportMode.parallel])
  func syntheticProjectReopensAndExportsATrimmedSpeedEdit(mode: ExportMode) async throws {
    let scratch = AppShowPaths.temp.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: scratch) }
    let source = try await VideoFixtures.screenMovie(in: scratch)
    let result = RecordingResult(
      screenVideoURL: source,
      webcamVideoURL: nil,
      systemAudioURL: nil,
      microphoneAudioURL: nil,
      cursorMetadataURL: nil,
      screenSize: VideoFixtures.screenSize,
      webcamSize: nil,
      fps: 30,
      captureQuality: .standard,
      isHDR: false
    )
    let project = try AppShowProject.create(
      from: result,
      fps: 30,
      captureMode: .entireScreen,
      sourceName: "Synthetic store fixture",
      in: FileManager.default.projectSaveDirectory()
    )
    defer { try? project.delete() }
    let reopened = try AppShowProject.open(at: project.bundleURL)
    var configuration = ExportConfiguration(
      cameraLayout: CameraLayout(),
      trimRange: CMTimeRange(start: CMTime(seconds: 0.5, preferredTimescale: 600), duration: CMTime(seconds: 1, preferredTimescale: 600))
    )
    configuration.speedRegions = [SpeedRegionData(startSeconds: 0, endSeconds: 2, rate: 2)]
    configuration.exportSettings.mode = mode
    let output = try await VideoCompositor.export(result: reopened.recordingResult, config: configuration)
    defer { try? FileManager.default.removeItem(at: output) }
    #expect(try output.deletingLastPathComponent() == FileManager.default.defaultSaveDirectory())
    let duration = try await AVURLAsset(url: output).load(.duration).seconds
    #expect(abs(duration - 0.5) < 0.08)
    #expect(try await !VideoFixtures.centerPixels(of: output).isEmpty)
  }
}
