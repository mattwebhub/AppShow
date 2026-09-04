import Foundation

enum AgentSkillBundleError: LocalizedError {
  case missingResource(String)
  case missingSkill(String)

  var errorDescription: String? {
    switch self {
    case .missingResource(let name): "Missing bundled agent resource: \(name)"
    case .missingSkill(let name): "Missing bundled agent skill: \(name)"
    }
  }
}

enum AgentSkillBundle {
  static let skillNames = [
    "presentation-cut",
    "remove-silences",
    "spotlight-clicks",
    "add-title-cards",
    "music-bed",
  ]

  static func bundledSkillsDirectory(bundle: Bundle = .main) throws -> URL {
    guard let url = bundle.url(forResource: "Skills", withExtension: nil) else {
      throw AgentSkillBundleError.missingResource("Skills")
    }
    return url
  }

  static func materialize(into workspaceDirectory: URL, bundle: Bundle = .main) throws {
    guard let guidanceURL = bundle.url(forResource: "AgentWorkspaceGuidance", withExtension: "md") else {
      throw AgentSkillBundleError.missingResource("AgentWorkspaceGuidance.md")
    }
    let guidance = try String(contentsOf: guidanceURL, encoding: .utf8)
    try materialize(
      into: workspaceDirectory,
      skillsDirectory: bundledSkillsDirectory(bundle: bundle),
      skillNames: skillNames,
      guidance: guidance
    )
  }

  static func materialize(
    into workspaceDirectory: URL,
    skillsDirectory: URL,
    skillNames: [String],
    guidance: String
  ) throws {
    let fileManager = FileManager.default
    try fileManager.createDirectory(at: workspaceDirectory, withIntermediateDirectories: true)
    for root in [".claude/skills", ".agents/skills"] {
      let targetRoot = workspaceDirectory.appendingPathComponent(root, isDirectory: true)
      try fileManager.createDirectory(at: targetRoot, withIntermediateDirectories: true)
      for name in skillNames {
        let source = skillsDirectory.appendingPathComponent(name, isDirectory: true)
        guard fileManager.fileExists(atPath: source.appendingPathComponent("SKILL.md").path) else {
          throw AgentSkillBundleError.missingSkill(name)
        }
        let target = targetRoot.appendingPathComponent(name, isDirectory: true)
        if fileManager.fileExists(atPath: target.path) {
          try fileManager.removeItem(at: target)
        }
        try fileManager.copyItem(at: source, to: target)
      }
    }

    let agentsURL = workspaceDirectory.appendingPathComponent("AGENTS.md")
    try Data(guidance.utf8).write(to: agentsURL, options: .atomic)
    let claudeURL = workspaceDirectory.appendingPathComponent("CLAUDE.md")
    if fileManager.fileExists(atPath: claudeURL.path) {
      try fileManager.removeItem(at: claudeURL)
    }
    try fileManager.createSymbolicLink(atPath: claudeURL.path, withDestinationPath: "AGENTS.md")
  }
}
