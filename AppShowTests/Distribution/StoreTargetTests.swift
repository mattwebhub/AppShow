import Foundation
import Testing

struct StoreTargetTests {
  @Test func storeTargetHasIndependentSandboxAndDependencyBoundaries() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let data = try Data(contentsOf: root.appendingPathComponent("AppShow.xcodeproj/project.pbxproj"))
    let project = try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    let objects = try #require(project["objects"] as? [String: [String: Any]])
    let store = try #require(objects.values.first { $0["isa"] as? String == "PBXNativeTarget" && $0["name"] as? String == "AppShowStore" })
    let products = (store["packageProductDependencies"] as? [String] ?? []).compactMap { objects[$0]?["productName"] as? String }
    #expect(!products.contains("Sparkle"))
    #expect(products.contains("WhisperKit"))
    let dependencies = (store["dependencies"] as? [String] ?? []).compactMap { objects[$0]?["target"] as? String }
    #expect(dependencies.compactMap { objects[$0]?["name"] as? String } == ["appshow-mcp"])
    let phases = (store["buildPhases"] as? [String] ?? []).compactMap { objects[$0] }
    #expect(!phases.contains { $0["isa"] as? String == "PBXCopyFilesBuildPhase" })
    #expect(phases.contains { $0["name"] as? String == "Embed Store Agents" })
    let list = try #require(store["buildConfigurationList"] as? String)
    for id in try #require(objects[list]?["buildConfigurations"] as? [String]) {
      let settings = try #require(objects[id]?["buildSettings"] as? [String: Any])
      let path = try #require(settings["CODE_SIGN_ENTITLEMENTS"] as? String)
      let entitlements = try #require(
        PropertyListSerialization.propertyList(from: Data(contentsOf: root.appendingPathComponent(path)), format: nil) as? [String: Any]
      )
      #expect(entitlements["com.apple.security.app-sandbox"] as? Bool == true)
      #expect(entitlements["com.apple.security.files.user-selected.read-write"] as? Bool == true)
      #expect(entitlements["com.apple.security.files.bookmarks.app-scope"] as? Bool == true)
      #expect(settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] as? String == "$(inherited) APP_STORE")
      #expect(settings["RUNTIME_EXCEPTION_ALLOW_JIT"] as? String == "NO")
    }
  }
}
