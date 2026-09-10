#if !APP_STORE
import Foundation

enum AgentRuntimeArchive {
  static let entries: Set<String> = [
    "bin/", "bin/codex", "bin/codex-code-mode-host", "codex-package.json", "codex-path/", "codex-path/rg",
    "codex-resources/", "codex-resources/zsh/", "codex-resources/zsh/bin/", "codex-resources/zsh/bin/zsh",
  ]

  static func validate(listing: String, types: String) throws {
    let names = listing.split(whereSeparator: \.isNewline).map { line in
      var name = String(line)
      while name.hasPrefix("./") { name.removeFirst(2) }
      return name
    }
    let typeLines = types.split(whereSeparator: \.isNewline)
    guard names.count == entries.count, Set(names) == entries,
      !typeLines.isEmpty, typeLines.allSatisfy({ $0.first == "d" || $0.first == "-" })
    else { throw AgentRuntimeUpdateError("The Codex archive has an unexpected layout or contains links.") }
  }

  static func validatePackage(at root: URL, release: AgentRuntimeRelease) throws {
    for entry in entries {
      let attributes = try FileManager.default.attributesOfItem(atPath: root.appendingPathComponent(entry).path)
      let expected: FileAttributeType = entry.hasSuffix("/") ? .typeDirectory : .typeRegular
      guard attributes[.type] as? FileAttributeType == expected else {
        throw AgentRuntimeUpdateError("The Codex package is incomplete: \(entry).")
      }
    }
    let data = try Data(contentsOf: root.appendingPathComponent("codex-package.json"))
    guard let manifest = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      manifest["layoutVersion"] as? Int == 1, manifest["version"] as? String == release.version,
      manifest["target"] as? String == "\(release.target)-apple-darwin", manifest["variant"] as? String == "codex",
      manifest["entrypoint"] as? String == "bin/codex", manifest["resourcesDir"] as? String == "codex-resources",
      manifest["pathDir"] as? String == "codex-path"
    else { throw AgentRuntimeUpdateError("The Codex package does not match the selected release.") }
  }
}
#endif
